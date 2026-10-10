import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/library/domain/song.dart';

@immutable
class RehearseState {
  const RehearseState({
    this.ready = false,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.guide = 0,
    this.semitones = 0,
    this.lyricsOffset = Duration.zero,
    this.error,
  });

  final bool ready;
  final bool playing;
  final Duration position;
  final Duration duration;

  /// 0 = instrumental only, 1 = original vocals at full level.
  final double guide;
  final int semitones;
  final Duration lyricsOffset;
  final AppFailure? error;

  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  RehearseState copyWith({
    bool? ready,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? guide,
    int? semitones,
    Duration? lyricsOffset,
    AppFailure? error,
  }) {
    return RehearseState(
      ready: ready ?? this.ready,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      guide: guide ?? this.guide,
      semitones: semitones ?? this.semitones,
      lyricsOffset: lyricsOffset ?? this.lyricsOffset,
      error: error ?? this.error,
    );
  }
}

/// Plays an instrumental with an optional "vocal guide": the original song
/// running in sync underneath at a user-set level.
class Rehearsal {
  Rehearsal({
    required this.song,
    required this.track,
    required this.onChange,
    AudioPlayer? music,
    AudioPlayer? guide,
  })  : music = music ?? AudioPlayer(),
        guide = guide ?? AudioPlayer();

  final Song song;
  final KaraokeTrack track;
  final void Function(RehearseState Function(RehearseState)) onChange;

  /// The instrumental, and the original song as the vocal guide.
  final AudioPlayer music;
  final AudioPlayer guide;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _sync;

  static const maxSemitones = 6;
  static const _driftTolerance = Duration(milliseconds: 80);
  static const _syncEvery = Duration(seconds: 2);

  /// Interpolated playback clock for lyrics.
  Duration position() => music.position;

  Future<void> open({int semitones = 0}) async {
    try {
      final d = await music.setFilePath(track.path);
      await guide.setAudioSource(AudioSource.uri(Uri.parse(song.uri)));
      await guide.setVolume(0);
      if (semitones != 0) await setKey(semitones);
      _subs
        ..add(
          music.playerStateStream.listen((s) {
            final ended = s.processingState == ProcessingState.completed;
            if (ended) unawaited(_rewind());
            onChange((r) => r.copyWith(playing: s.playing && !ended));
          }),
        )
        ..add(
          music.positionStream.listen(
            (p) => onChange((r) => r.copyWith(position: p)),
          ),
        );
      onChange(
        (r) => r.copyWith(ready: true, duration: d ?? track.duration),
      );
      _sync = Timer.periodic(_syncEvery, (_) => unawaited(_keepInSync()));
    } on Object catch (e) {
      onChange((r) => r.copyWith(error: toFailure(e)));
    }
  }

  Future<void> _rewind() async {
    await pause();
    await seek(Duration.zero);
  }

  /// Re-aligns the vocal guide when it drifts from the music. Exposed for
  /// tests; runs on a timer while playing.
  @visibleForTesting
  Future<void> keepInSync() => _keepInSync();

  Future<void> _keepInSync() async {
    if (!music.playing || guide.volume == 0) return;
    final drift = (music.position - guide.position).abs();
    if (drift > _driftTolerance) await guide.seek(music.position);
  }

  Future<void> play() async {
    await guide.seek(music.position);
    unawaited(guide.play());
    unawaited(music.play());
  }

  Future<void> pause() async {
    await Future.wait([music.pause(), guide.pause()]);
  }

  Future<void> seek(Duration to) async {
    await Future.wait([music.seek(to), guide.seek(to)]);
  }

  Future<void> setGuide(double level) async {
    final wasSilent = guide.volume == 0;
    onChange((r) => r.copyWith(guide: level));
    await guide.setVolume(level);
    if (level > 0 && wasSilent) await guide.seek(music.position);
  }

  /// Key change in semitones, tempo preserved.
  Future<void> setKey(int semitones) async {
    final s = semitones.clamp(-maxSemitones, maxSemitones);
    final ratio = math.pow(2, s / 12).toDouble();
    await Future.wait([music.setPitch(ratio), guide.setPitch(ratio)]);
    onChange((r) => r.copyWith(semitones: s));
  }

  Future<void> dispose() async {
    _sync?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await Future.wait([music.dispose(), guide.dispose()]);
  }
}

/// Per-song lyric timing nudge, remembered.
class LyricsOffsets {
  LyricsOffsets(this._ref);

  final Ref _ref;

  Duration get(String songId) => Duration(
        milliseconds: _ref
                .read(prefsProvider)
                .getInt('${PrefKeys.lyricsOffsetPrefix}$songId') ??
            0,
      );

  Future<void> set(String songId, Duration offset) => _ref
      .read(prefsProvider)
      .setInt('${PrefKeys.lyricsOffsetPrefix}$songId', offset.inMilliseconds);
}

final lyricsOffsetsProvider = Provider<LyricsOffsets>(LyricsOffsets.new);
