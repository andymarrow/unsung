import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:unsung/core/env.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/storage/app_files.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/lyrics/domain/lyrics.dart';

/// Finds synced lyrics on LRCLIB (free, open) and caches them on the device.
/// Users can also paste their own LRC or plain lyrics.
class LyricsRepository {
  LyricsRepository(this._files, {http.Client? client})
      : _client = client ?? http.Client();

  final AppFiles _files;
  final http.Client _client;
  static const _folder = 'lyrics';
  static const _sourceLrclib = 'LRCLIB';
  static const _sourceYou = 'You';

  File _cache(Song song) => File(_files.path(_folder, '${song.id}.lrc'));
  File _meta(Song song) => File(_files.path(_folder, '${song.id}.source'));

  Future<Lyrics> forSong(Song song) async {
    final cached = _cache(song);
    if (cached.existsSync()) {
      final source = _meta(song).existsSync()
          ? await _meta(song).readAsString()
          : null;
      return Lyrics.parse(
        await cached.readAsString(),
        songDuration: song.duration,
        source: source,
      );
    }
    final found = await _fetch(song);
    if (found == null) return Lyrics.empty;
    await _write(song, found, _sourceLrclib);
    return Lyrics.parse(found, songDuration: song.duration, source: _sourceLrclib);
  }

  /// Saves user-provided lyrics (LRC or plain text).
  Future<Lyrics> saveOwn(Song song, String text) async {
    await _write(song, text, _sourceYou);
    return Lyrics.parse(text, songDuration: song.duration, source: _sourceYou);
  }

  Future<void> forget(Song song) async {
    for (final f in [_cache(song), _meta(song)]) {
      if (f.existsSync()) await f.delete();
    }
  }

  Future<void> _write(Song song, String text, String source) async {
    await _cache(song).writeAsString(text, flush: true);
    await _meta(song).writeAsString(source, flush: true);
  }

  /// "Artist - Title" file names are common when tags are missing.
  static (String? artist, String title) guessNames(Song song) {
    if (song.artist != null) return (song.artist, song.title);
    final parts = song.title.split(RegExp(r'\s+[-–—]\s+'));
    if (parts.length == 2) return (parts[0].trim(), parts[1].trim());
    return (null, song.title);
  }

  Future<String?> _fetch(Song song) async {
    final (artist, title) = guessNames(song);
    final headers = {'User-Agent': Env.userAgent};
    try {
      if (artist != null) {
        final exact = await _client
            .get(
              Uri.parse('${Env.lyricsApi}/get').replace(
                queryParameters: {
                  'track_name': title,
                  'artist_name': artist,
                  if (song.album != null) 'album_name': song.album!,
                  'duration': song.duration.inSeconds.toString(),
                },
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12));
        if (exact.statusCode == 200) {
          final text = _pick(jsonDecode(exact.body));
          if (text != null) return text;
        }
      }
      final search = await _client
          .get(
            Uri.parse('${Env.lyricsApi}/search').replace(
              queryParameters: {
                'track_name': title,
                if (artist != null) 'artist_name': artist,
              },
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));
      if (search.statusCode != 200) return null;
      final results = jsonDecode(search.body);
      if (results is! List || results.isEmpty) return null;
      final candidates = results.whereType<Map<String, Object?>>().toList()
        ..sort((a, b) {
          int score(Map<String, Object?> r) {
            final synced = (r['syncedLyrics'] as String?)?.isNotEmpty ?? false;
            final d = ((r['duration'] as num?)?.toDouble() ?? 0) -
                song.duration.inSeconds;
            return (synced ? 0 : 1000) + d.abs().round();
          }

          return score(a).compareTo(score(b));
        });
      return _pick(candidates.first);
    } on SocketException {
      throw const OfflineFailure("Lyrics need a connection the first time. They're saved after that.");
    } on http.ClientException {
      throw const OfflineFailure("Lyrics need a connection the first time. They're saved after that.");
    } on FormatException {
      return null;
    }
  }

  static String? _pick(Object? json) {
    if (json is! Map<String, Object?>) return null;
    if (json['instrumental'] == true) return null;
    final synced = json['syncedLyrics'] as String?;
    if (synced != null && synced.trim().isNotEmpty) return synced;
    final plain = json['plainLyrics'] as String?;
    return plain != null && plain.trim().isNotEmpty ? plain : null;
  }
}

final lyricsRepositoryProvider = Provider<LyricsRepository>(
  (ref) => LyricsRepository(ref.watch(appFilesProvider)),
);

final lyricsProvider = FutureProvider.family<Lyrics, Song>(
  (ref, song) => ref.watch(lyricsRepositoryProvider).forSong(song),
);
