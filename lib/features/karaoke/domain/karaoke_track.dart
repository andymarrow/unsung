import 'package:flutter/foundation.dart';

enum SeparationMode {
  /// On-device centre-channel removal. Instant, offline, decent.
  quick,

  /// ML separation on the configured server. Slower, much cleaner.
  studio,
}

/// An "unsung" song: the instrumental file made from a library song.
@immutable
class KaraokeTrack {
  const KaraokeTrack({
    required this.songId,
    required this.path,
    required this.duration,
    required this.instrumentalPeaks,
    required this.vocalPeaks,
    required this.stereoRatio,
    required this.mode,
    required this.createdAt,
  });

  factory KaraokeTrack.fromJson(Map<String, Object?> j) => KaraokeTrack(
        songId: j['songId']! as String,
        path: j['path']! as String,
        duration: Duration(milliseconds: (j['durationMs']! as num).toInt()),
        instrumentalPeaks: _doubles(j['instrumentalPeaks']),
        vocalPeaks: _doubles(j['vocalPeaks']),
        stereoRatio: (j['stereoRatio'] as num?)?.toDouble() ?? 1,
        mode: SeparationMode.values.byName(j['mode'] as String? ?? 'quick'),
        createdAt: DateTime.parse(j['createdAt']! as String),
      );

  static List<double> _doubles(Object? v) =>
      v is List ? [for (final x in v) (x as num).toDouble()] : const [];

  final String songId;
  final String path;
  final Duration duration;
  final List<double> instrumentalPeaks;
  final List<double> vocalPeaks;
  final double stereoRatio;
  final SeparationMode mode;
  final DateTime createdAt;

  /// Near-mono mixes keep more of the voice with quick separation.
  bool get mayLeakVocals =>
      mode == SeparationMode.quick && stereoRatio < weakStereoThreshold;

  static const weakStereoThreshold = 0.15;

  Map<String, Object?> toJson() => {
        'songId': songId,
        'path': path,
        'durationMs': duration.inMilliseconds,
        'instrumentalPeaks': instrumentalPeaks,
        'vocalPeaks': vocalPeaks,
        'stereoRatio': stereoRatio,
        'mode': mode.name,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A conversion in progress or failed.
@immutable
sealed class KaraokeJob {
  const KaraokeJob(this.mode);

  final SeparationMode mode;
}

final class KaraokeRunning extends KaraokeJob {
  const KaraokeRunning(
    super.mode, {
    this.progress = 0,
    this.instrumentalPeaks = const [],
    this.vocalPeaks = const [],
  });

  final double progress;
  final List<double> instrumentalPeaks;
  final List<double> vocalPeaks;
}

final class KaraokeFailed extends KaraokeJob {
  const KaraokeFailed(super.mode, this.message);

  final String message;
}
