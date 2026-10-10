import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/storage/app_files.dart';
import 'package:unsung/features/studio/domain/take.dart';

/// Takes on this device. Index in takes/index.json, files in takes/<id>/.
class TakesRepository {
  TakesRepository(this._files, this._audio);

  final AppFiles _files;
  final NativeAudio _audio;
  static const _folder = 'takes';
  static const _index = 'index.json';

  String folderFor(String takeId) => _files.dir('$_folder/$takeId').path;

  String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<List<Take>> load() async {
    final raw = await _files.readJson(_folder, _index);
    final takes = <Take>[];
    for (final v in raw.values) {
      try {
        final t = Take.fromJson(v! as Map<String, Object?>);
        if (File(t.vocalPath).existsSync()) takes.add(t);
      } on Object {
        // Skip a corrupt entry; keep the rest.
      }
    }
    return takes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveAll(List<Take> takes) => _files.writeJson(
        _folder,
        _index,
        {for (final t in takes) t.id: t.toJson()},
      );

  Future<void> deleteFiles(Take take) async {
    final dir = Directory(folderFor(take.id));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Renders the mix. [preview] writes a fast WAV for listening while
  /// editing; otherwise an AAC file for keeping and sharing.
  Future<MixResult> render(
    Take take,
    String instrumentalPath, {
    required bool preview,
    MixSettings? settings,
    void Function(double)? onProgress,
  }) async {
    final taskId = 'mix-${take.id}-${preview ? 'p' : 'f'}';
    final sub = onProgress == null
        ? null
        : _audio.progress
            .where((p) => p.taskId == taskId)
            .listen((p) => onProgress(p.progress));
    try {
      return await _audio.mix(
        taskId: taskId,
        instrumental: instrumentalPath,
        vocal: take.vocalPath,
        outPath: '${folderFor(take.id)}/${preview ? 'preview.wav' : 'mix.m4a'}',
        settings: settings ?? take.settings,
        preview: preview,
      );
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> cancelRender(Take take, {required bool preview}) =>
      _audio.cancel('mix-${take.id}-${preview ? 'p' : 'f'}');
}

final takesRepositoryProvider = Provider<TakesRepository>(
  (ref) => TakesRepository(
    ref.watch(appFilesProvider),
    ref.watch(nativeAudioProvider),
  ),
);
