import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/studio/data/takes_repository.dart';
import 'package:unsung/features/studio/data/wav_writer.dart';
import 'package:unsung/features/studio/domain/pitch.dart';
import 'package:unsung/features/studio/domain/take.dart';

enum StudioPhase {
  preparing,
  needsMic,
  ready,
  countdown,
  recording,
  saving,
  failed
}

/// Scrolling pitch history for the ribbon (MIDI note numbers, NaN = silent).
class PitchHistory extends ChangeNotifier {
  PitchHistory({this.length = 180})
      : values = Float64List(length)..fillRange(0, length, double.nan);

  final int length;
  final Float64List values;
  int head = 0;

  void push(double? midi) {
    values[head] = midi ?? double.nan;
    head = (head + 1) % length;
    notifyListeners();
  }

  /// i = 0 is the oldest sample.
  double at(int i) => values[(head + i) % length];

  /// Latest voiced note, or null.
  double? get latest {
    for (var i = length - 1; i >= length - 8; i--) {
      final v = at(i);
      if (!v.isNaN) return v;
    }
    return null;
  }
}

/// Records the singer over the instrumental: mic → WAV + live pitch, music
/// in the headphones, and an automatic sync estimate.
class StudioSession extends ChangeNotifier {
  StudioSession({
    required this.song,
    required this.track,
    required this.takes,
    required this.permissions,
    this.semitones = 0,
  });

  final Song song;
  final KaraokeTrack track;
  final TakesRepository takes;
  final Permissions permissions;
  int semitones;

  final music = AudioPlayer();
  final history = PitchHistory();
  final _recorder = AudioRecorder();
  final _tracker = PitchTracker();
  final _stats = SingingStats();

  StudioPhase phase = StudioPhase.preparing;
  AppFailure? failure;
  bool micBlocked = false;
  int countdown = 0;
  Duration elapsed = Duration.zero;

  static const sampleRate = 44100;

  /// Typical Android output latency; the user can fine-tune sync later.
  static const _outputLatencyMs = 90;

  WavWriter? _wav;
  String? _takeId;
  StreamSubscription<Uint8List>? _mic;
  final _subs = <StreamSubscription<Object?>>[];
  int? _syncOffsetMs;
  bool _musicStarted = false;

  void _set(StudioPhase p) {
    phase = p;
    notifyListeners();
  }

  Duration position() => music.position;

  Future<void> prepare() async {
    _set(StudioPhase.preparing);
    try {
      await music.setFilePath(track.path);
      await setKey(semitones);
      var access = await permissions.microphone();
      if (access != Access.granted)
        access = await permissions.requestMicrophone();
      if (access != Access.granted) {
        micBlocked = access == Access.blocked;
        _set(StudioPhase.needsMic);
        return;
      }
      _subs.add(
        music.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed &&
              phase == StudioPhase.recording) {
            unawaited(stop());
          }
        }),
      );
      _set(StudioPhase.ready);
    } on Object catch (e) {
      failure = toFailure(e);
      _set(StudioPhase.failed);
    }
  }

  Future<void> retryMic() async {
    if (micBlocked) {
      await permissions.openSettings();
      return;
    }
    await prepare();
  }

  Future<void> setKey(int s) async {
    semitones = s;
    await music.setPitch(math.pow(2, s / 12).toDouble());
    notifyListeners();
  }

  /// 3-2-1 then record. [beat] is called on each count for haptics.
  Future<void> countIn(Duration step, void Function(int) beat) async {
    if (phase != StudioPhase.ready) return;
    _set(StudioPhase.countdown);
    for (var n = 3; n >= 1; n--) {
      countdown = n;
      beat(n);
      notifyListeners();
      await Future<void>.delayed(step);
      if (phase != StudioPhase.countdown) return;
    }
    countdown = 0;
    await _record();
  }

  Future<void> _record() async {
    try {
      _takeId = takes.newId();
      final path = '${takes.folderFor(_takeId!)}/vocal.wav';
      _wav = await WavWriter.create(path, sampleRate: sampleRate);
      await music.seek(Duration.zero);
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          echoCancel: false,
          noiseSuppress: false,
          autoGain: false,
        ),
      );
      _musicStarted = false;
      _syncOffsetMs = null;
      _subs.add(
        music.positionStream.listen((p) {
          // First audible position: how much vocal was recorded before the
          // music actually started tells us the sync offset.
          if (_syncOffsetMs == null && p > Duration.zero && _wav != null) {
            _syncOffsetMs = _wav!.duration.inMilliseconds -
                p.inMilliseconds +
                _outputLatencyMs;
          }
          elapsed = p;
        }),
      );
      _mic = stream.listen(_onPcm);
      _set(StudioPhase.recording);
    } on Object catch (e) {
      failure = toFailure(e);
      _set(StudioPhase.failed);
    }
  }

  void _onPcm(Uint8List chunk) {
    _wav?.add(chunk);
    if (!_musicStarted) {
      _musicStarted = true;
      unawaited(music.play());
    }
    for (final hz in _tracker.add(chunk)) {
      _stats.add(hz);
      history.push(hz == null ? null : hzToMidi(hz));
    }
  }

  /// Stops and returns the new take (not yet saved to the index).
  Future<Take?> stop() async {
    if (phase != StudioPhase.recording) return null;
    _set(StudioPhase.saving);
    await _mic?.cancel();
    await _recorder.stop();
    await music.pause();
    final wav = _wav;
    final id = _takeId;
    if (wav == null || id == null) return null;
    await wav.close();
    _wav = null;
    return Take(
      id: id,
      songId: song.id,
      songTitle: song.title,
      artist: song.artist,
      createdAt: DateTime.now(),
      duration: wav.duration,
      vocalPath: '${takes.folderFor(id)}/vocal.wav',
      settings: MixSettings(
        offsetMs: math.max(0, _syncOffsetMs ?? _outputLatencyMs),
        semitones: semitones,
      ),
      inTune: _stats.inTune,
      presence: _stats.presence,
    );
  }

  /// Abandons the current recording and deletes its files.
  Future<void> discard() async {
    final id = _takeId;
    if (phase == StudioPhase.recording) {
      await _mic?.cancel();
      await _recorder.stop();
      await music.pause();
      await _wav?.close();
    }
    _wav = null;
    if (id != null) {
      final dir = Directory(takes.folderFor(id));
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
    if (phase == StudioPhase.countdown || phase == StudioPhase.recording) {
      await music.seek(Duration.zero);
      _set(StudioPhase.ready);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_mic?.cancel());
    unawaited(_recorder.dispose());
    unawaited(music.dispose());
    history.dispose();
    super.dispose();
  }
}
