import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/library/data/library_repository.dart';
import 'package:unsung/features/library/domain/song.dart';

sealed class LibraryState {
  const LibraryState();
}

final class LibraryNeedsAccess extends LibraryState {
  const LibraryNeedsAccess({required this.blocked});

  /// The user must enable access in system settings.
  final bool blocked;
}

final class LibraryLoaded extends LibraryState {
  const LibraryLoaded(this.songs);

  final List<Song> songs;
}

class LibraryController extends AsyncNotifier<LibraryState> {
  Permissions get _perms => ref.read(permissionsProvider);
  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);

  @override
  Future<LibraryState> build() async {
    final access = await _perms.music();
    if (access != Access.granted) {
      return LibraryNeedsAccess(blocked: access == Access.blocked);
    }
    return _load();
  }

  Future<LibraryState> _load() async {
    try {
      return LibraryLoaded(await _repo.songs());
    } on Object catch (e) {
      throw toFailure(e);
    }
  }

  Future<void> requestAccess() async {
    final current = state.valueOrNull;
    if (current is LibraryNeedsAccess && current.blocked) {
      await _perms.openSettings();
      return;
    }
    final access = await _perms.requestMusic();
    if (access != Access.granted) {
      state = AsyncData(LibraryNeedsAccess(blocked: access == Access.blocked));
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Re-checks access (e.g. after returning from settings) and reloads.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryController, LibraryState>(
    LibraryController.new);

/// All songs once loaded, else empty. Handy for lookups by id.
final songsProvider = Provider<List<Song>>((ref) {
  final s = ref.watch(libraryProvider).valueOrNull;
  return s is LibraryLoaded ? s.songs : const [];
});

final songByIdProvider = Provider.family<Song?, String>((ref, id) {
  for (final s in ref.watch(songsProvider)) {
    if (s.id == id) return s;
  }
  return null;
});

enum LibraryFilter { all, ready }

class LibraryQuery {
  const LibraryQuery({this.text = '', this.filter = LibraryFilter.all});

  final String text;
  final LibraryFilter filter;

  LibraryQuery copyWith({String? text, LibraryFilter? filter}) =>
      LibraryQuery(text: text ?? this.text, filter: filter ?? this.filter);
}

class LibraryQueryNotifier extends Notifier<LibraryQuery> {
  @override
  LibraryQuery build() => const LibraryQuery();

  void setText(String text) => state = state.copyWith(text: text);

  void setFilter(LibraryFilter filter) =>
      state = state.copyWith(filter: filter);
}

final libraryQueryProvider =
    NotifierProvider<LibraryQueryNotifier, LibraryQuery>(
        LibraryQueryNotifier.new);

final artworkProvider =
    FutureProvider.autoDispose.family<Uint8List?, Song>((ref, song) {
  return ref.watch(libraryRepositoryProvider).artwork(song);
});
