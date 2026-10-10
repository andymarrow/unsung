import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:unsung/core/env.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/storage/app_files.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/links/data/link_sources.dart';
import 'package:unsung/features/links/domain/link.dart';

/// Songs brought in from links. Audio and covers live in imports/, listed in
/// imports/index.json, and join the device library as ordinary [Song]s.
class LinkRepository {
  LinkRepository(
    this._files, {
    required List<LinkSource> sources,
    http.Client? client,
  })  : assert(sources.isNotEmpty, 'needs at least one source'),
        _sources = sources,
        _client = client ?? http.Client();

  final AppFiles _files;

  /// Tried in order; a later source is used only when an earlier one fails
  /// for a reason other than the link itself (offline server, blocked).
  final List<LinkSource> _sources;
  final http.Client _client;

  static const _folder = 'imports';
  static const _index = 'index.json';

  Future<List<Song>> songs() async {
    final raw = await _files.readJson(_folder, _index);
    return [
      for (final v in raw.values)
        if (_parse(v) case final song?)
          if (File.fromUri(Uri.parse(song.uri)).existsSync()) song,
    ];
  }

  Song? _parse(Object? json) {
    try {
      return Song.fromJson(json! as Map<String, Object?>);
    } on Object {
      return null; // A corrupt entry never takes the whole index down.
    }
  }

  Future<LinkPreview> resolve(String videoId) =>
      _firstThat((s) => s.resolve(videoId));

  /// Downloads the audio and cover, then records the song.
  Future<Song> import(
    LinkPreview preview, {
    required void Function(double? progress) onProgress,
    required bool Function() cancelled,
  }) async {
    final audio = File(_files.path(_folder, '${preview.songId}.m4a'));
    final part = File('${audio.path}.part');
    try {
      await _firstThat(
        (s) => s.download(preview, part,
            onProgress: onProgress, cancelled: cancelled),
      );
      await part.rename(audio.path);
    } finally {
      if (part.existsSync()) await part.delete();
    }
    final song = Song(
      id: preview.songId,
      title: preview.title,
      artist: preview.artist,
      uri: Uri.file(audio.path).toString(),
      duration: preview.duration,
      addedAt: DateTime.now(),
      artPath: await _cover(preview),
      sourceUrl: preview.url,
    );
    final index = await _files.readJson(_folder, _index);
    await _files.writeJson(_folder, _index, {...index, song.id: song.toJson()});
    return song;
  }

  Future<void> remove(Song song) async {
    for (final path in [Uri.parse(song.uri).toFilePath(), song.artPath]) {
      if (path != null && File(path).existsSync()) await File(path).delete();
    }
    final index = await _files.readJson(_folder, _index);
    await _files.writeJson(_folder, _index, {...index}..remove(song.id));
  }

  /// Best effort: a missing cover only means a lettered placeholder.
  Future<String?> _cover(LinkPreview preview) async {
    final url = preview.thumbnailUrl;
    if (url == null) return null;
    try {
      final r = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
      final f = File(_files.path(_folder, '${preview.songId}.jpg'));
      await f.writeAsBytes(r.bodyBytes, flush: true);
      return f.path;
    } on Object {
      return null;
    }
  }

  Future<T> _firstThat<T>(Future<T> Function(LinkSource) run) async {
    Object? last;
    for (final source in _sources) {
      try {
        return await run(source);
      } on LinkFailure {
        rethrow; // About the link itself: another source won't help.
      } on CancelledFailure {
        rethrow;
      } on Object catch (e) {
        last = e;
      }
    }
    throw toFailure(last!);
  }
}

final linkRepositoryProvider = Provider<LinkRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return LinkRepository(
    ref.watch(appFilesProvider),
    client: client,
    sources: [
      if (Env.hasStudioSeparation) ServerLinkSource(client),
      DeviceLinkSource(),
    ],
  );
});
