import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/studio/domain/take.dart';

import 'fakes.dart';

// Invented people and posts for tests and screenshots.

const demoHanna = Profile(
    id: 'u1',
    handle: 'hanna_b',
    displayName: 'Hanna Bekele',
    bio: 'Night-bus soprano. Learning harmonies one take at a time.');
const demoDawit = Profile(id: 'u2', handle: 'dawit', displayName: 'Dawit');

final demoPosts = [
  Post(
    id: 'p1',
    author: demoHanna,
    songTitle: 'Addis at 3am',
    artist: 'Hanna Bekele',
    caption: 'First try with the new reverb. The bridge finally sits right.',
    audioPath: 'u1/a.m4a',
    duration: const Duration(minutes: 4, seconds: 15),
    peaks: demoPeaks(7),
    inTune: 0.81,
    visibility: TakeVisibility.public,
    likeCount: 42,
    commentCount: 6,
    likedByMe: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  Post(
    id: 'p2',
    author: demoDawit,
    songTitle: 'Slow Dance in the Kitchen',
    artist: 'Marlow & Finch',
    audioPath: 'u2/b.m4a',
    duration: const Duration(minutes: 3, seconds: 2),
    peaks: demoPeaks(8),
    inTune: 0.67,
    visibility: TakeVisibility.public,
    likeCount: 9,
    commentCount: 1,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

/// A connected, signed-in Stage that serves [demoPosts].
class FakeSocial extends SocialRepository {
  FakeSocial() : super(null);

  @override
  bool get configured => true;

  @override
  String? get userId => demoHanna.id;

  @override
  Stream<String?> authChanges() => Stream.value(demoHanna.id);

  @override
  Future<List<Post>> feed(FeedScope scope, {int page = 0}) async =>
      page == 0 ? demoPosts : const [];
}
