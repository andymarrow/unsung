import 'package:flutter/foundation.dart';

/// Finds a YouTube video id in pasted or shared text. Handles watch,
/// youtu.be, shorts, embed, live and music.youtube.com links, with or without
/// a scheme, and text around the link ("Listen to this https://youtu.be/…").
/// Returns null when there is no single-video link.
String? youTubeIdFrom(String text) {
  final match = _link.firstMatch(text);
  if (match == null) return null;
  final raw = match.group(0)!;
  final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (!_hosts.contains(host)) return null;
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (uri.pathSegments.isNotEmpty &&
      const {'shorts', 'embed', 'live', 'v'}.contains(uri.pathSegments.first) &&
      uri.pathSegments.length > 1) {
    id = uri.pathSegments[1];
  } else {
    id = uri.queryParameters['v'];
  }
  return id != null && _id.hasMatch(id) ? id : null;
}

final _link = RegExp(
  r'(https?://)?[\w.-]*(youtube\.com|youtu\.be)/[^\s]+',
  caseSensitive: false,
);
final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');
const _hosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtu.be',
};

/// The canonical watch URL for [id].
String youTubeUrl(String id) => 'https://www.youtube.com/watch?v=$id';

/// What a link points at, shown before anything is downloaded.
@immutable
class LinkPreview {
  const LinkPreview({
    required this.videoId,
    required this.title,
    required this.duration,
    this.artist,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String? artist;
  final Duration duration;
  final String? thumbnailUrl;

  /// Library id for the imported song.
  String get songId => 'yt-$videoId';

  String get url => youTubeUrl(videoId);
}

/// Video titles carry noise that doesn't belong in a song title:
/// "Artist - Song (Official Music Video) [4K]" → ("Artist", "Song").
({String title, String? artist}) cleanTitle(String raw, {String? channel}) {
  var t = raw.replaceAll(_noise, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  String? artist;
  final dash = RegExp(r'\s[-–—]\s').firstMatch(t);
  if (dash != null) {
    artist = t.substring(0, dash.start).trim();
    t = t.substring(dash.end).trim();
  }
  artist ??= channel
      ?.replaceAll(RegExp(r'\s*-\s*Topic$|VEVO$', caseSensitive: false), '')
      .trim();
  if (t.isEmpty) t = raw.trim();
  return (title: t, artist: (artist?.isEmpty ?? true) ? null : artist);
}

final _noise = RegExp(
  r'[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|hd|4k|remaster|mv)[^\)\]]*[\)\]]',
  caseSensitive: false,
);
