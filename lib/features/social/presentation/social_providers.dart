import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/studio/domain/take.dart';

/// Signed-in user id, or null.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final repo = ref.watch(socialRepositoryProvider);
  yield repo.userId;
  yield* repo.authChanges();
});

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final id = ref.watch(authUserIdProvider).valueOrNull;
  if (id == null) return null;
  return ref.watch(socialRepositoryProvider).profile(id);
});

final profileProvider = FutureProvider.autoDispose.family<Profile, String>(
  (ref, id) => ref.watch(socialRepositoryProvider).profile(id),
);

final statsProvider = FutureProvider.autoDispose.family<ProfileStats, String>(
  (ref, id) => ref.watch(socialRepositoryProvider).stats(id),
);

final postsByProvider = FutureProvider.autoDispose.family<List<Post>, String>(
  (ref, id) {
    ref.watch(authUserIdProvider);
    return ref.watch(socialRepositoryProvider).postsBy(id);
  },
);

final postProvider = FutureProvider.autoDispose.family<Post, String>(
  (ref, id) => ref.watch(socialRepositoryProvider).post(id),
);

/// Paged feed.
class FeedState {
  const FeedState(
      {this.posts = const [],
      this.page = 0,
      this.done = false,
      this.loadingMore = false});

  final List<Post> posts;
  final int page;
  final bool done;
  final bool loadingMore;
}

class FeedController
    extends AutoDisposeFamilyAsyncNotifier<FeedState, FeedScope> {
  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  @override
  Future<FeedState> build(FeedScope scope) async {
    ref.watch(authUserIdProvider);
    final posts = await _repo.feed(scope);
    return FeedState(
        posts: posts, done: posts.length < SocialRepository.pageSize);
  }

  Future<void> more() async {
    final s = state.valueOrNull;
    if (s == null || s.done || s.loadingMore) return;
    state =
        AsyncData(FeedState(posts: s.posts, page: s.page, loadingMore: true));
    try {
      final next = await _repo.feed(arg, page: s.page + 1);
      state = AsyncData(
        FeedState(
          posts: [...s.posts, ...next],
          page: s.page + 1,
          done: next.length < SocialRepository.pageSize,
        ),
      );
    } on Object {
      state = AsyncData(FeedState(posts: s.posts, page: s.page));
    }
  }
}

final feedProvider = AsyncNotifierProvider.autoDispose
    .family<FeedController, FeedState, FeedScope>(
  FeedController.new,
);

/// Optimistic like state layered over whatever a post object says.
class LikesController extends Notifier<Map<String, (bool, int)>> {
  @override
  Map<String, (bool, int)> build() => const {};

  (bool, int) of(Post p) => state[p.id] ?? (p.likedByMe, p.likeCount);

  /// Returns a failure message if the server rejected the change.
  Future<String?> toggle(Post p) async {
    final (liked, count) = of(p);
    final next = (!liked, count + (liked ? -1 : 1));
    state = {...state, p.id: next};
    try {
      final repo = ref.read(socialRepositoryProvider);
      if (repo.userId == null)
        throw const AuthFailure('Sign in to like takes.');
      await (liked ? repo.unlike(p.id) : repo.like(p.id));
      return null;
    } on Object catch (e) {
      state = {...state, p.id: (liked, count)};
      return toFailure(e).message;
    }
  }
}

final likesProvider =
    NotifierProvider<LikesController, Map<String, (bool, int)>>(
        LikesController.new);

class CommentsController
    extends AutoDisposeFamilyAsyncNotifier<List<Comment>, String> {
  @override
  Future<List<Comment>> build(String postId) =>
      ref.watch(socialRepositoryProvider).comments(postId);

  Future<void> add(String body) async {
    final c = await ref.read(socialRepositoryProvider).addComment(arg, body);
    state = AsyncData([...state.valueOrNull ?? const [], c]);
  }

  Future<void> remove(Comment c) async {
    await ref.read(socialRepositoryProvider).deleteComment(c.id);
    state = AsyncData([
      for (final x in state.valueOrNull ?? const <Comment>[])
        if (x.id != c.id) x,
    ]);
  }
}

final commentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsController, List<Comment>, String>(
  CommentsController.new,
);

final followingProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(socialRepositoryProvider).isFollowing(id),
);

/// One player for the whole Stage, so only one take plays at a time.
class StagePlayback {
  const StagePlayback(
      {this.postId,
      this.playing = false,
      this.loading = false,
      this.position = Duration.zero});

  final String? postId;
  final bool playing;
  final bool loading;
  final Duration position;
}

class StagePlayer extends Notifier<StagePlayback> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];

  AudioPlayer get _p {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _subs
      ..add(p.playerStateStream.listen((s) {
        final done = s.processingState == ProcessingState.completed;
        state = StagePlayback(
          postId: state.postId,
          playing: s.playing && !done,
          loading: s.processingState == ProcessingState.loading ||
              s.processingState == ProcessingState.buffering,
          position: state.position,
        );
        if (done) unawaited(p.seek(Duration.zero).then((_) => p.pause()));
      }))
      ..add(p.positionStream.listen((pos) {
        state = StagePlayback(
          postId: state.postId,
          playing: state.playing,
          loading: state.loading,
          position: pos,
        );
      }));
    return _player = p;
  }

  @override
  StagePlayback build() {
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      unawaited(_player?.dispose());
    });
    return const StagePlayback();
  }

  Future<String?> toggle(Post post) async {
    if (state.postId == post.id) {
      await (state.playing ? _p.pause() : _p.play());
      return null;
    }
    state = StagePlayback(postId: post.id, loading: true);
    try {
      final url = await ref.read(socialRepositoryProvider).audioUrl(post);
      await _p.setUrl(url);
      unawaited(_p.play());
      return null;
    } on Object catch (e) {
      state = const StagePlayback();
      return toFailure(e).message;
    }
  }

  Future<void> seek(Post post, double fraction) async {
    if (state.postId != post.id) return;
    await _p.seek(post.duration * fraction);
  }

  Future<void> stop() async {
    await _player?.stop();
    state = const StagePlayback();
  }
}

final stagePlayerProvider =
    NotifierProvider<StagePlayer, StagePlayback>(StagePlayer.new);

/// Publish/visibility actions for one of your takes.
class ShareActions {
  ShareActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  Future<Post> publish(Take take, TakeVisibility v, String caption) async {
    final post = await _repo.publish(take, visibility: v, caption: caption);
    _invalidate(post.author.id);
    return post;
  }

  Future<void> setVisibility(Post post, TakeVisibility v) async {
    await _repo.setVisibility(post.id, v);
    _ref.invalidate(postProvider(post.id));
    _invalidate(post.author.id);
  }

  Future<void> delete(Post post) async {
    await _repo.deletePost(post);
    _invalidate(post.author.id);
  }

  void _invalidate(String authorId) {
    _ref
      ..invalidate(postsByProvider(authorId))
      ..invalidate(statsProvider(authorId))
      ..invalidate(feedProvider(FeedScope.forYou));
  }
}

final shareActionsProvider = Provider<ShareActions>(ShareActions.new);
