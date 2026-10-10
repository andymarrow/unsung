import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/features/library/domain/song.dart';

/// Reads songs and cover art from the device through the native engine.
class LibraryRepository {
  LibraryRepository(this._audio);

  final NativeAudio _audio;
  final _art = LinkedHashMap<String, Uint8List?>();
  static const _artCacheSize = 160;

  Future<List<Song>> songs() async {
    final raw = await _audio.querySongs();
    return [for (final m in raw) Song.fromMap(m)];
  }

  /// Cover art, cached in memory (LRU). Null when the file has none.
  Future<Uint8List?> artwork(Song song) async {
    if (_art.containsKey(song.id)) {
      final hit = _art.remove(song.id);
      _art[song.id] = hit;
      return hit;
    }
    final bytes = await _audio.artwork(song.uri, size: 384);
    _art[song.id] = bytes;
    if (_art.length > _artCacheSize) _art.remove(_art.keys.first);
    return bytes;
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(nativeAudioProvider)),
);
