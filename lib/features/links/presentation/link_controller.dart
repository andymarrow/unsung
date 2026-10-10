import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';
import 'package:unsung/features/links/data/link_repository.dart';
import 'package:unsung/features/links/data/link_sources.dart';
import 'package:unsung/features/links/domain/link.dart';

/// Paste → preview → import. One flow at a time, owned by the link sheet.
sealed class LinkState {
  const LinkState();
}

final class LinkIdle extends LinkState {
  const LinkIdle();
}

final class LinkResolving extends LinkState {
  const LinkResolving(this.videoId);

  final String videoId;
}

final class LinkReady extends LinkState {
  const LinkReady(this.preview, {this.alreadyHave});

  final LinkPreview preview;

  /// The song is already in the library from an earlier import.
  final Song? alreadyHave;
}

final class LinkImporting extends LinkState {
  const LinkImporting(this.preview, this.progress);

  final LinkPreview preview;

  /// 0..1, or null while the size is unknown.
  final double? progress;
}

final class LinkDone extends LinkState {
  const LinkDone(this.song);

  final Song song;
}

final class LinkFailed extends LinkState {
  const LinkFailed(this.message, {this.preview});

  final String message;

  /// Set when the failure came after a preview, so "try again" can retry the
  /// import rather than the lookup.
  final LinkPreview? preview;
}

class LinkController extends AutoDisposeNotifier<LinkState> {
  LinkRepository get _repo => ref.read(linkRepositoryProvider);
  bool _cancelled = false;

  @override
  LinkState build() {
    ref.onDispose(() => _cancelled = true);
    return const LinkIdle();
  }

  /// Text changed: look up a YouTube link as soon as there is one.
  Future<void> submit(String text) async {
    final id = youTubeIdFrom(text);
    final current = state;
    if (id == null) {
      if (current is! LinkImporting) {
        state = text.trim().isEmpty
            ? const LinkIdle()
            : const LinkFailed(
                'That isn’t a YouTube song link. Try one from youtube.com, youtu.be or YouTube Music.');
      }
      return;
    }
    // Same link again, or busy importing: keep what we have.
    if (_videoIdOf(current) == id || current is LinkImporting) return;
    state = LinkResolving(id);
    try {
      final preview = await _repo.resolve(id);
      if (!_stillLookingAt(id)) return;
      if (preview.duration > maxLinkDuration) {
        state = LinkFailed(
            'Songs up to ${maxLinkDuration.inMinutes} minutes only. This one is ${formatDuration(preview.duration)}.');
        return;
      }
      state = LinkReady(preview,
          alreadyHave: ref.read(songByIdProvider(preview.songId)));
    } on Object catch (e) {
      if (_stillLookingAt(id)) state = LinkFailed(toFailure(e).message);
    }
  }

  bool _stillLookingAt(String id) =>
      state is LinkResolving && _videoIdOf(state) == id;

  static String? _videoIdOf(LinkState s) => switch (s) {
        LinkResolving(:final videoId) => videoId,
        LinkReady(:final preview) ||
        LinkImporting(:final preview) =>
          preview.videoId,
        _ => null,
      };

  Future<void> import() async {
    final preview = switch (state) {
      LinkReady(:final preview) => preview,
      LinkFailed(:final preview?) => preview,
      _ => null,
    };
    if (preview == null) return;
    _cancelled = false;
    state = LinkImporting(preview, null);
    try {
      final song = await _repo.import(
        preview,
        onProgress: (p) {
          if (!_cancelled) state = LinkImporting(preview, p);
        },
        cancelled: () => _cancelled,
      );
      if (_cancelled) return;
      ref.read(libraryProvider.notifier).addImported(song);
      state = LinkDone(song);
    } on CancelledFailure {
      // Back to the preview; the user may still want it later.
      state = LinkReady(preview);
    } on Object catch (e) {
      if (!_cancelled) {
        state = LinkFailed(toFailure(e).message, preview: preview);
      }
    }
  }

  void cancel() {
    _cancelled = true;
    if (state case LinkImporting(:final preview)) state = LinkReady(preview);
  }

  void reset() => state = const LinkIdle();
}

final linkControllerProvider =
    AutoDisposeNotifierProvider<LinkController, LinkState>(LinkController.new);
