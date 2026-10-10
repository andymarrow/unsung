import 'package:flutter/foundation.dart';

/// A song on the device.
@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.uri,
    required this.duration,
    this.artist,
    this.album,
    this.addedAt,
    this.artPath,
    this.sourceUrl,
  });

  /// A song brought in from a link, stored in the app (see LinkRepository).
  factory Song.fromJson(Map<String, Object?> json) => Song(
        id: json['id']! as String,
        title: json['title']! as String,
        artist: json['artist'] as String?,
        uri: json['uri']! as String,
        duration: Duration(milliseconds: (json['durationMs']! as num).toInt()),
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
        artPath: json['artPath'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
      );

  factory Song.fromMap(Map<Object?, Object?> m) => Song(
        id: m['id']! as String,
        title: (m['title'] as String?) ?? 'Untitled',
        artist: m['artist'] as String?,
        album: m['album'] as String?,
        uri: m['uri']! as String,
        duration:
            Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
        addedAt: (m['addedAt'] as num?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (m['addedAt']! as num).toInt()),
      );

  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String uri;
  final Duration duration;
  final DateTime? addedAt;

  /// Cover image on disk, for songs that have no embedded art.
  final String? artPath;

  /// Where an imported song came from (a YouTube link). Null for songs that
  /// are on the device.
  final String? sourceUrl;

  bool get isImported => sourceUrl != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'uri': uri,
        'durationMs': duration.inMilliseconds,
        'addedAt': addedAt?.toIso8601String(),
        'artPath': artPath,
        'sourceUrl': sourceUrl,
      };

  String get artistOrUnknown => artist ?? 'Unknown artist';

  /// Lower-cased haystack for search.
  String get searchText =>
      '$title ${artist ?? ''} ${album ?? ''}'.toLowerCase();

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 3:07, 1:02:45.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Alphabetical by title, ignoring case: the order the alphabet scrub expects.
List<Song> sortSongs(List<Song> songs) => songs
  ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
