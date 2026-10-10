import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';

/// One progress tick from a native task.
@immutable
class TaskProgress {
  const TaskProgress({
    required this.taskId,
    required this.progress,
    this.instrumentalPeaks,
    this.vocalPeaks,
  });

  final String taskId;
  final double progress;

  /// Live (un-normalised) envelopes while unsinging.
  final List<double>? instrumentalPeaks;
  final List<double>? vocalPeaks;
}

@immutable
class UnsingResult {
  const UnsingResult({
    required this.path,
    required this.duration,
    required this.instrumentalPeaks,
    required this.vocalPeaks,
    required this.stereoRatio,
  });

  final String path;
  final Duration duration;
  final List<double> instrumentalPeaks;
  final List<double> vocalPeaks;

  /// Side/centre energy. Below ~0.15 the mix is near-mono and removal is weak.
  final double stereoRatio;
}

@immutable
class MixResult {
  const MixResult({
    required this.path,
    required this.duration,
    required this.peaks,
  });

  final String path;
  final Duration duration;
  final List<double> peaks;
}

/// Mix parameters for a take. Everything is re-renderable from the raw vocal.
@immutable
class MixSettings {
  const MixSettings({
    this.vocalGain = 1,
    this.musicGain = 0.85,
    this.reverb = 0.25,
    this.echo = 0,
    this.offsetMs = 0,
    this.semitones = 0,
  });

  factory MixSettings.fromJson(Map<String, Object?> json) => MixSettings(
        vocalGain: (json['vocalGain'] as num?)?.toDouble() ?? 1,
        musicGain: (json['musicGain'] as num?)?.toDouble() ?? 0.85,
        reverb: (json['reverb'] as num?)?.toDouble() ?? 0.25,
        echo: (json['echo'] as num?)?.toDouble() ?? 0,
        offsetMs: (json['offsetMs'] as num?)?.toInt() ?? 0,
        semitones: (json['semitones'] as num?)?.toInt() ?? 0,
      );

  final double vocalGain;
  final double musicGain;
  final double reverb;
  final double echo;

  /// Positive skips the start of the vocal to undo recording latency.
  final int offsetMs;
  final int semitones;

  MixSettings copyWith({
    double? vocalGain,
    double? musicGain,
    double? reverb,
    double? echo,
    int? offsetMs,
    int? semitones,
  }) {
    return MixSettings(
      vocalGain: vocalGain ?? this.vocalGain,
      musicGain: musicGain ?? this.musicGain,
      reverb: reverb ?? this.reverb,
      echo: echo ?? this.echo,
      offsetMs: offsetMs ?? this.offsetMs,
      semitones: semitones ?? this.semitones,
    );
  }

  Map<String, Object?> toJson() => {
        'vocalGain': vocalGain,
        'musicGain': musicGain,
        'reverb': reverb,
        'echo': echo,
        'offsetMs': offsetMs,
        'semitones': semitones,
      };

  @override
  bool operator ==(Object other) =>
      other is MixSettings &&
      other.vocalGain == vocalGain &&
      other.musicGain == musicGain &&
      other.reverb == reverb &&
      other.echo == echo &&
      other.offsetMs == offsetMs &&
      other.semitones == semitones;

  @override
  int get hashCode =>
      Object.hash(vocalGain, musicGain, reverb, echo, offsetMs, semitones);
}

/// The Dart side of the native audio engine (MediaStore, MediaCodec, DSP).
class NativeAudio {
  NativeAudio();

  static const _methods = MethodChannel('unsung/audio');
  static const _events = EventChannel('unsung/audio/progress');

  late final Stream<TaskProgress> progress = _events
      .receiveBroadcastStream()
      .map((e) => _toProgress(e as Map<Object?, Object?>))
      .asBroadcastStream();

  static TaskProgress _toProgress(Map<Object?, Object?> m) => TaskProgress(
        taskId: m['taskId']! as String,
        progress: (m['progress']! as num).toDouble(),
        instrumentalPeaks: _doubles(m['instrumentalPeaks']),
        vocalPeaks: _doubles(m['vocalPeaks']),
      );

  static List<double>? _doubles(Object? v) =>
      v is List ? [for (final x in v) (x as num).toDouble()] : null;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'audio' => AudioFailure(e.message ?? "Couldn't process this audio."),
        'permission' => PermissionFailure(
            e.message ?? 'Unsung needs access to your music.',
          ),
        'cancelled' => const CancelledFailure(),
        _ => UnknownFailure(e.message ?? 'Something went wrong. Try again.'),
      };
    } on MissingPluginException {
      throw const AudioFailure('Audio engine unavailable on this platform.');
    }
  }

  Future<List<Map<Object?, Object?>>> querySongs() async {
    final list = await _call<List<Object?>>('querySongs');
    return [
      for (final e in list ?? const <Object?>[]) e! as Map<Object?, Object?>
    ];
  }

  Future<Uint8List?> artwork(String uri, {int size = 512}) =>
      _call<Uint8List>('artwork', {'uri': uri, 'size': size});

  Future<UnsingResult> unsing({
    required String taskId,
    required String source,
    required String outPath,
  }) async {
    final m = (await _call<Map<Object?, Object?>>('unsing', {
      'taskId': taskId,
      'source': source,
      'outPath': outPath,
    }))!;
    return UnsingResult(
      path: m['path']! as String,
      duration: Duration(milliseconds: (m['durationMs']! as num).toInt()),
      instrumentalPeaks: _doubles(m['instrumentalPeaks']) ?? const [],
      vocalPeaks: _doubles(m['vocalPeaks']) ?? const [],
      stereoRatio: (m['stereoRatio']! as num).toDouble(),
    );
  }

  Future<MixResult> mix({
    required String taskId,
    required String instrumental,
    required String vocal,
    required String outPath,
    required MixSettings settings,
    bool preview = false,
  }) async {
    final m = (await _call<Map<Object?, Object?>>('mix', {
      'taskId': taskId,
      'instrumental': instrumental,
      'vocal': vocal,
      'outPath': outPath,
      'format': preview ? 'wav' : 'm4a',
      ...settings.toJson(),
    }))!;
    return MixResult(
      path: m['path']! as String,
      duration: Duration(milliseconds: (m['durationMs']! as num).toInt()),
      peaks: _doubles(m['peaks']) ?? const [],
    );
  }

  Future<List<double>> peaks(String source, {int count = 160}) async {
    final v = await _call<Object?>('peaks', {
      'source': source,
      'count': count,
      'taskId': 'peaks-$source',
    });
    return _doubles(v) ?? const [];
  }

  /// Copies a content:// song into an app file (for uploading).
  Future<String> copyToFile(String source, String outPath) async =>
      (await _call<String>(
          'copyToFile', {'source': source, 'outPath': outPath}))!;

  Future<void> cancel(String taskId) =>
      _call<void>('cancel', {'taskId': taskId});
}

final nativeAudioProvider = Provider<NativeAudio>((_) => NativeAudio());
