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
  });

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
