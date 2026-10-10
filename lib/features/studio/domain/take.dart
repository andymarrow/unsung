import 'package:flutter/foundation.dart';
import 'package:unsung/core/platform/native_audio.dart';

enum TakeVisibility { private, public }

/// One recorded performance. The raw vocal is always kept so the mix can be
/// changed at any time.
@immutable
class Take {
  const Take({
    required this.id,
    required this.songId,
    required this.songTitle,
    required this.createdAt,
    required this.duration,
    required this.vocalPath,
    required this.settings,
    this.artist,
    this.mixPath,
    this.peaks = const [],
    this.inTune = 0,
    this.presence = 0,
    this.visibility = TakeVisibility.private,
    this.postId,
    this.caption = '',
  });

  factory Take.fromJson(Map<String, Object?> j) => Take(
        id: j['id']! as String,
        songId: j['songId']! as String,
        songTitle: j['songTitle']! as String,
        artist: j['artist'] as String?,
        createdAt: DateTime.parse(j['createdAt']! as String),
        duration: Duration(milliseconds: (j['durationMs']! as num).toInt()),
        vocalPath: j['vocalPath']! as String,
        mixPath: j['mixPath'] as String?,
        settings: MixSettings.fromJson(
          (j['settings'] as Map<String, Object?>?) ?? const {},
        ),
        peaks: [
          for (final p in (j['peaks'] as List<Object?>?) ?? const <Object?>[])
            (p! as num).toDouble(),
        ],
        inTune: (j['inTune'] as num?)?.toDouble() ?? 0,
        presence: (j['presence'] as num?)?.toDouble() ?? 0,
        visibility: TakeVisibility.values.byName(
          j['visibility'] as String? ?? TakeVisibility.private.name,
        ),
        postId: j['postId'] as String?,
        caption: j['caption'] as String? ?? '',
      );

  final String id;
  final String songId;
  final String songTitle;
  final String? artist;
  final DateTime createdAt;
  final Duration duration;

  /// Raw mono vocal (WAV). Never modified.
  final String vocalPath;

  /// Rendered mix (M4A), null until first saved.
  final String? mixPath;
  final MixSettings settings;
  final List<double> peaks;

  /// Share of sung frames centred on a note (0..1).
  final double inTune;

  /// Share of the take with singing in it (0..1).
  final double presence;
  final TakeVisibility visibility;

  /// Remote post id once shared.
  final String? postId;
  final String caption;

  bool get isPublic => visibility == TakeVisibility.public;

  Take copyWith({
    String? mixPath,
    MixSettings? settings,
    List<double>? peaks,
    Duration? duration,
    TakeVisibility? visibility,
    String? postId,
    String? caption,
  }) {
    return Take(
      id: id,
      songId: songId,
      songTitle: songTitle,
      artist: artist,
      createdAt: createdAt,
      duration: duration ?? this.duration,
      vocalPath: vocalPath,
      mixPath: mixPath ?? this.mixPath,
      settings: settings ?? this.settings,
      peaks: peaks ?? this.peaks,
      inTune: inTune,
      presence: presence,
      visibility: visibility ?? this.visibility,
      postId: postId ?? this.postId,
      caption: caption ?? this.caption,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'songId': songId,
        'songTitle': songTitle,
        'artist': artist,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'vocalPath': vocalPath,
        'mixPath': mixPath,
        'settings': settings.toJson(),
        'peaks': peaks,
        'inTune': inTune,
        'presence': presence,
        'visibility': visibility.name,
        'postId': postId,
        'caption': caption,
      };
}
