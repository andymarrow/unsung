import 'package:flutter/foundation.dart';
import 'package:unsung/features/studio/domain/take.dart';

typedef Json = Map<String, Object?>;

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.handle,
    this.displayName = '',
    this.bio = '',
  });

  factory Profile.fromJson(Json j) => Profile(
        id: j['id']! as String,
        handle: j['handle']! as String,
        displayName: (j['display_name'] as String?) ?? '',
        bio: (j['bio'] as String?) ?? '',
      );

  final String id;
  final String handle;
  final String displayName;
  final String bio;

  String get name => displayName.trim().isEmpty ? handle : displayName;

  /// Up to two initials for the monogram avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final s = parts.take(2).map((p) => String.fromCharCode(p.runes.first)).join();
    return s.isEmpty ? '?' : s.toUpperCase();
  }
}

@immutable
class ProfileStats {
  const ProfileStats({
    this.publicPosts = 0,
    this.likesReceived = 0,
    this.followers = 0,
    this.following = 0,
  });

  factory ProfileStats.fromJson(Json j) => ProfileStats(
        publicPosts: (j['public_posts'] as num?)?.toInt() ?? 0,
        likesReceived: (j['likes_received'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
      );

  final int publicPosts;
  final int likesReceived;
  final int followers;
  final int following;
}

/// A take shared to the server.
@immutable
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.songTitle,
    required this.audioPath,
    required this.duration,
    required this.createdAt,
    this.artist,
    this.caption = '',
    this.peaks = const [],
    this.inTune = 0,
    this.visibility = TakeVisibility.private,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  factory Post.fromJson(Json j, {bool likedByMe = false}) => Post(
        id: j['id']! as String,
        author: Profile.fromJson(j['author']! as Json),
        songTitle: j['song_title']! as String,
        artist: j['artist'] as String?,
        caption: (j['caption'] as String?) ?? '',
        audioPath: j['audio_path']! as String,
        duration: Duration(milliseconds: (j['duration_ms']! as num).toInt()),
        peaks: [
          for (final p in (j['peaks'] as List<Object?>?) ?? const <Object?>[])
            (p! as num).toDouble(),
        ],
        inTune: (j['in_tune'] as num?)?.toDouble() ?? 0,
        visibility: TakeVisibility.values.byName(
          (j['visibility'] as String?) ?? TakeVisibility.private.name,
        ),
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['created_at']! as String),
        likedByMe: likedByMe,
      );

  final String id;
  final Profile author;
  final String songTitle;
  final String? artist;
  final String caption;
  final String audioPath;
  final Duration duration;
  final List<double> peaks;
  final double inTune;
  final TakeVisibility visibility;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final bool likedByMe;

  bool get isPublic => visibility == TakeVisibility.public;

  Post copyWith({
    TakeVisibility? visibility,
    String? caption,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
  }) {
    return Post(
      id: id,
      author: author,
      songTitle: songTitle,
      artist: artist,
      caption: caption ?? this.caption,
      audioPath: audioPath,
      duration: duration,
      peaks: peaks,
      inTune: inTune,
      visibility: visibility ?? this.visibility,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  factory Comment.fromJson(Json j) => Comment(
        id: j['id']! as String,
        postId: j['post_id']! as String,
        author: Profile.fromJson(j['author']! as Json),
        body: j['body']! as String,
        createdAt: DateTime.parse(j['created_at']! as String),
      );

  final String id;
  final String postId;
  final Profile author;
  final String body;
  final DateTime createdAt;
}

enum FeedScope { forYou, following }

/// "2 min", "3 h", "5 d", or a date.
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes} min';
  if (d.inDays < 1) return '${d.inHours} h';
  if (d.inDays < 7) return '${d.inDays} d';
  return '${t.day}.${t.month}.${t.year}';
}
