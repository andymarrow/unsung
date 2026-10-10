import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unsung/core/env.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/studio/domain/take.dart';

/// The Stage backend (Supabase: auth, Postgres with row-level security,
/// storage). Every call maps errors to [AppFailure]s.
class SocialRepository {
  SocialRepository(this._client);

  final SupabaseClient? _client;
  static const _bucket = 'takes';
  static const pageSize = 20;
  static const _postSelect = '*, author:profiles!posts_author_id_fkey(*)';
  static const _commentSelect = '*, author:profiles!comments_author_id_fkey(*)';
  final _urls = <String, (String, DateTime)>{};

  bool get configured => _client != null;

  SupabaseClient get _db {
    final c = _client;
    if (c == null) {
      throw const NotConfiguredFailure(
        "The Stage isn't connected yet. Your takes stay on this phone until it is.",
      );
    }
    return c;
  }

  String? get userId => _client?.auth.currentUser?.id;

  Stream<String?> authChanges() {
    final c = _client;
    if (c == null) return Stream.value(null);
    return c.auth.onAuthStateChange.map((s) => s.session?.user.id);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AppFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_authMessage(e));
    } on PostgrestException catch (e) {
      throw UnknownFailure(_dbMessage(e));
    } on StorageException catch (e) {
      throw UnknownFailure('Upload failed: ${e.message}');
    } on SocketException {
      throw const OfflineFailure();
    } on Object catch (e) {
      throw toFailure(e);
    }
  }

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('expired') || m.contains('invalid')) {
      return "That code didn't work. Check it, or ask for a new one.";
    }
    if (m.contains('rate')) return 'Too many tries. Wait a minute and try again.';
    return e.message;
  }

  static String _dbMessage(PostgrestException e) {
    if (e.code == '23505') return 'That handle is taken. Try another.';
    if (e.code == '23514') return "Something you typed doesn't fit. Check the lengths.";
    return "The Stage didn't respond properly. Try again.";
  }

  // Auth ----------------------------------------------------------------------

  Future<void> sendCode(String email) => _guard(
        () => _db.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true),
      );

  Future<void> verifyCode(String email, String code) => _guard(
        () => _db.auth.verifyOTP(
          email: email.trim(),
          token: code.trim(),
          type: OtpType.email,
        ),
      );

  Future<void> signOut() => _guard(() => _db.auth.signOut());

  // Profiles --------------------------------------------------------------------

  Future<Profile> profile(String id) => _guard(() async {
        final row = await _db.from('profiles').select().eq('id', id).single();
        return Profile.fromJson(row);
      });

  Future<ProfileStats> stats(String id) => _guard(() async {
        final row = await _db.from('profile_stats').select().eq('id', id).maybeSingle();
        return row == null ? const ProfileStats() : ProfileStats.fromJson(row);
      });

  Future<Profile> updateProfile({
    required String handle,
    required String displayName,
    required String bio,
  }) =>
      _guard(() async {
        final row = await _db
            .from('profiles')
            .update({
              'handle': handle.trim().toLowerCase(),
              'display_name': displayName.trim(),
              'bio': bio.trim(),
            })
            .eq('id', userId!)
            .select()
            .single();
        return Profile.fromJson(row);
      });

  // Posts -------------------------------------------------------------------------

  Future<List<Post>> _withLikes(List<Map<String, dynamic>> rows) async {
    final me = userId;
    if (rows.isEmpty || me == null) return [for (final r in rows) Post.fromJson(r)];
    final ids = [for (final r in rows) r['id']! as String];
    final liked = await _db.from('likes').select('post_id').eq('user_id', me).inFilter('post_id', ids);
    final set = {for (final l in liked) l['post_id']! as String};
    return [for (final r in rows) Post.fromJson(r, likedByMe: set.contains(r['id']))];
  }

  Future<List<Post>> feed(FeedScope scope, {int page = 0}) => _guard(() async {
        final from = page * pageSize;
        var query = _db.from('posts').select(_postSelect).eq('visibility', 'public');
        if (scope == FeedScope.following) {
          final me = userId;
          if (me == null) return const <Post>[];
          final follows = await _db.from('follows').select('followee_id').eq('follower_id', me);
          final ids = [for (final f in follows) f['followee_id']! as String];
          if (ids.isEmpty) return const <Post>[];
          query = query.inFilter('author_id', ids);
        }
        final rows = await query.order('created_at', ascending: false).range(from, from + pageSize - 1);
        return _withLikes(rows);
      });

  /// Public posts by [authorId], plus private ones when it's you (RLS).
  Future<List<Post>> postsBy(String authorId) => _guard(() async {
        final rows = await _db
            .from('posts')
            .select(_postSelect)
            .eq('author_id', authorId)
            .order('created_at', ascending: false)
            .limit(60);
        return _withLikes(rows);
      });

  Future<Post> post(String id) => _guard(() async {
        final row = await _db.from('posts').select(_postSelect).eq('id', id).single();
        return (await _withLikes([row])).single;
      });

  /// Uploads the take's mix and creates the post.
  Future<Post> publish(
    Take take, {
    required TakeVisibility visibility,
    required String caption,
  }) =>
      _guard(() async {
        final me = userId;
        final mix = take.mixPath;
        if (me == null) throw const AuthFailure('Sign in to share takes.');
        if (mix == null) throw const AudioFailure('Save the mix first.');
        final path = '$me/${take.id}.m4a';
        await _db.storage.from(_bucket).upload(
              path,
              File(mix),
              fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: true),
            );
        final row = await _db
            .from('posts')
            .insert({
              'author_id': me,
              'song_title': take.songTitle,
              'artist': take.artist,
              'caption': caption.trim(),
              'audio_path': path,
              'duration_ms': take.duration.inMilliseconds,
              'peaks': take.peaks,
              'in_tune': take.inTune,
              'visibility': visibility.name,
            })
            .select(_postSelect)
            .single();
        return Post.fromJson(row);
      });

  Future<void> setVisibility(String postId, TakeVisibility v) => _guard(
        () => _db.from('posts').update({'visibility': v.name}).eq('id', postId),
      );

  Future<void> updateCaption(String postId, String caption) => _guard(
        () => _db.from('posts').update({'caption': caption.trim()}).eq('id', postId),
      );

  Future<void> deletePost(Post post) => _guard(() async {
        await _db.from('posts').delete().eq('id', post.id);
        await _db.storage.from(_bucket).remove([post.audioPath]);
      });

  /// Signed URL for playback, cached until shortly before it expires.
  Future<String> audioUrl(Post post) => _guard(() async {
        final cached = _urls[post.audioPath];
        if (cached != null && cached.$2.isAfter(DateTime.now())) return cached.$1;
        const ttl = Duration(hours: 1);
        final url = await _db.storage.from(_bucket).createSignedUrl(post.audioPath, ttl.inSeconds);
        _urls[post.audioPath] = (url, DateTime.now().add(ttl - const Duration(minutes: 5)));
        return url;
      });

  // Likes, comments, follows ------------------------------------------------------------

  Future<void> like(String postId) => _guard(
        () => _db.from('likes').insert({'post_id': postId, 'user_id': userId}),
      );

  Future<void> unlike(String postId) => _guard(
        () => _db.from('likes').delete().eq('post_id', postId).eq('user_id', userId!),
      );

  Future<List<Comment>> comments(String postId) => _guard(() async {
        final rows = await _db
            .from('comments')
            .select(_commentSelect)
            .eq('post_id', postId)
            .order('created_at')
            .limit(200);
        return [for (final r in rows) Comment.fromJson(r)];
      });

  Future<Comment> addComment(String postId, String body) => _guard(() async {
        final row = await _db
            .from('comments')
            .insert({'post_id': postId, 'author_id': userId, 'body': body.trim()})
            .select(_commentSelect)
            .single();
        return Comment.fromJson(row);
      });

  Future<void> deleteComment(String id) =>
      _guard(() => _db.from('comments').delete().eq('id', id));

  Future<bool> isFollowing(String userIdToCheck) => _guard(() async {
        final me = userId;
        if (me == null) return false;
        final row = await _db
            .from('follows')
            .select('followee_id')
            .eq('follower_id', me)
            .eq('followee_id', userIdToCheck)
            .maybeSingle();
        return row != null;
      });

  Future<void> follow(String id) => _guard(
        () => _db.from('follows').insert({'follower_id': userId, 'followee_id': id}),
      );

  Future<void> unfollow(String id) => _guard(
        () => _db.from('follows').delete().eq('follower_id', userId!).eq('followee_id', id),
      );
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(Env.hasBackend ? Supabase.instance.client : null),
);
