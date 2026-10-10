import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/library/data/library_repository.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/links/data/link_repository.dart';

sealed class LibraryState {
  const LibraryState();
}

final class LibraryNeedsAccess extends LibraryState {
  const LibraryNeedsAccess({required this.blocked, this.imported = const []});

  /// The user must enable access in system settings.
  final bool blocked;

  /// Songs brought in from links, usable without music access.
  final List<Song> imported;
}

final class LibraryLoaded extends LibraryState {
  const LibraryLoaded(this.songs);

  final List<Song> songs;
}

class LibraryController extends AsyncNotifier<LibraryState> {
  Permissions get _perms => ref.read(permissionsProvider);
  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);
  LinkRepository get _links => ref.read(linkRepositoryProvider);

  @override
  Future<LibraryState> build() async {
    final access = await _perms.music();
    if (access != Access.granted) {
      return LibraryNeedsAccess(
        blocked: access == Access.blocked,
        imported: await _imported(),
      );
    }
    return _load();
  }

  Future<List<Song>> _imported() async {
    try {
      return await _links.songs();
    } on Object {
      return const []; // Imports never block the device library.
    }
  }

  Future<LibraryState> _load() async {
    try {
      final all = [...await _repo.songs(), ...await _imported()];
      return LibraryLoaded(sortSongs(all));
    } on Object catch (e) {
      throw toFailure(e);
    }
  }

  /// Adds a song that was just imported from a link, without a reload.
  void addImported(Song song) {
    state = AsyncData(switch (state.valueOrNull) {
      LibraryLoaded(:final songs) => LibraryLoaded(
          sortSongs([...songs.where((s) => s.id != song.id), song])),
      LibraryNeedsAccess(:final blocked, :final imported) => LibraryNeedsAccess(
          blocked: blocked,
          imported:
              sortSongs([...imported.where((s) => s.id != song.id), song]),
        ),
      _ => LibraryLoaded([song]),
    });
  }

  /// Deletes an imported song's files and drops it from the list.
  Future<void> removeImported(Song song) async {
    await _links.remove(song);
    state = AsyncData(switch (state.valueOrNull) {
      LibraryLoaded(:final songs) =>
        LibraryLoaded([...songs.where((s) => s.id != song.id)]),
      LibraryNeedsAccess(:final blocked, :final imported) => LibraryNeedsAccess(
          blocked: blocked,
          imported: [...imported.where((s) => s.id != song.id)],
        ),
      _ => const LibraryLoaded([]),
    });
  }

  Future<void> requestAccess() async {
    final current = state.valueOrNull;
    if (current is LibraryNeedsAccess && current.blocked) {
      await _perms.openSettings();
      return;
    }
    final access = await _perms.requestMusic();
    if (access != Access.granted) {
      state = AsyncData(LibraryNeedsAccess(
        blocked: access == Access.blocked,
        imported: await _imported(),
      ));
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
  return switch (ref.watch(libraryProvider).valueOrNull) {
    LibraryLoaded(:final songs) => songs,
    LibraryNeedsAccess(:final imported) => imported,
    _ => const [],
  };
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
