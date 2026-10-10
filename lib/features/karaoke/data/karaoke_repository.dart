import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:unsung/core/env.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/storage/app_files.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/library/domain/song.dart';

/// Makes and stores instrumentals. Index lives in karaoke/index.json.
class KaraokeRepository {
  KaraokeRepository(this._files, this._audio, {http.Client? client})
      : _client = client ?? http.Client();

  final AppFiles _files;
  final NativeAudio _audio;
  final http.Client _client;
  static const _folder = 'karaoke';
  static const _index = 'index.json';

  Future<Map<String, KaraokeTrack>> load() async {
    final raw = await _files.readJson(_folder, _index);
    final tracks = <String, KaraokeTrack>{};
    for (final entry in raw.entries) {
      try {
        final t = KaraokeTrack.fromJson(entry.value! as Map<String, Object?>);
        if (File(t.path).existsSync()) tracks[entry.key] = t;
      } on Object {
        // Skip corrupt entries rather than losing the whole index.
      }
    }
    return tracks;
  }

  Future<void> _save(Map<String, KaraokeTrack> tracks) => _files.writeJson(
        _folder,
        _index,
        {for (final e in tracks.entries) e.key: e.value.toJson()},
      );

  Future<void> put(Map<String, KaraokeTrack> all, KaraokeTrack track) =>
      _save({...all, track.songId: track});

  Future<void> remove(Map<String, KaraokeTrack> all, String songId) async {
    final t = all[songId];
    if (t != null) {
      final f = File(t.path);
      if (f.existsSync()) await f.delete();
    }
    await _save({...all}..remove(songId));
  }

  String taskIdFor(Song song) => 'unsing-${song.id}';

  Future<KaraokeTrack> unsing(
    Song song,
    SeparationMode mode, {
    required void Function(TaskProgress) onProgress,
  }) async {
    return switch (mode) {
      SeparationMode.quick => _quick(song, onProgress),
      SeparationMode.studio => _studio(song, onProgress),
    };
  }

  Future<KaraokeTrack> _quick(
    Song song,
    void Function(TaskProgress) onProgress,
  ) async {
    final taskId = taskIdFor(song);
    final sub = _audio.progress
        .where((p) => p.taskId == taskId)
        .listen(onProgress);
    try {
      final r = await _audio.unsing(
        taskId: taskId,
        source: song.uri,
        outPath: _files.path(_folder, '${song.id}.m4a'),
      );
      return KaraokeTrack(
        songId: song.id,
        path: r.path,
        duration: r.duration,
        instrumentalPeaks: r.instrumentalPeaks,
        vocalPeaks: r.vocalPeaks,
        stereoRatio: r.stereoRatio,
        mode: SeparationMode.quick,
        createdAt: DateTime.now(),
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Uploads the song to the separation server (see server/README.md) and
  /// downloads the instrumental. Progress: upload 0–40%, separation 40–90%
  /// (indeterminate on the server), download/peaks 90–100%.
  Future<KaraokeTrack> _studio(
    Song song,
    void Function(TaskProgress) onProgress,
  ) async {
    if (!Env.hasStudioSeparation) {
      throw const NotConfiguredFailure(
        'Studio separation needs a server. Use Quick for now.',
      );
    }
    final taskId = taskIdFor(song);
    void report(double p) =>
        onProgress(TaskProgress(taskId: taskId, progress: p));
    final upload = await _audio.copyToFile(
      song.uri,
      _files.path('tmp', 'upload-${song.id}'),
    );
    report(0.1);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Env.separationApiUrl}/separate'),
      )
        ..headers['User-Agent'] = Env.userAgent
        ..files.add(await http.MultipartFile.fromPath('file', upload));
      report(0.4);
      final response = await _client
          .send(request)
          .timeout(const Duration(minutes: 10));
      if (response.statusCode != 200) {
        throw AudioFailure(
          'The studio server said no (${response.statusCode}). Try Quick.',
        );
      }
      report(0.9);
      final out = File(_files.path(_folder, '${song.id}.m4a'));
      await response.stream.pipe(out.openWrite());
      final peaks = await _audio.peaks(out.path);
      final original = await _audio.peaks(song.uri);
      report(1);
      return KaraokeTrack(
        songId: song.id,
        path: out.path,
        duration: song.duration,
        instrumentalPeaks: peaks,
        vocalPeaks: original,
        stereoRatio: 1,
        mode: SeparationMode.studio,
        createdAt: DateTime.now(),
      );
    } on AppFailure {
      rethrow;
    } on Object catch (e) {
      throw toFailure(e);
    } finally {
      final f = File(upload);
      if (f.existsSync()) await f.delete();
    }
  }

  Future<void> cancel(Song song) => _audio.cancel(taskIdFor(song));
}

final karaokeRepositoryProvider = Provider<KaraokeRepository>(
  (ref) => KaraokeRepository(
    ref.watch(appFilesProvider),
    ref.watch(nativeAudioProvider),
  ),
);
