@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/profile_view.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/post_card.dart';
import 'package:unsung/features/stage/presentation/stage_screen.dart';
import 'package:unsung/features/studio/domain/take.dart';

import '../helpers/fakes.dart';
import '../helpers/fonts.dart';
import '../helpers/pump.dart';

const _hanna = Profile(
    id: 'u1',
    handle: 'hanna_b',
    displayName: 'Hanna Bekele',
    bio: 'Night-bus soprano. Learning harmonies one take at a time.');
const _dawit = Profile(id: 'u2', handle: 'dawit', displayName: 'Dawit');

final _posts = [
  Post(
    id: 'p1',
    author: _hanna,
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
    author: _dawit,
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

void main() {
  setUpAll(loadAppFonts);

  for (final b in Brightness.values) {
    testWidgets('stage feed ${b.name}', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              itemCount: _posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
              itemBuilder: (_, i) => PostCard(post: _posts[i]),
            ),
          ),
        ),
        brightness: b,
      );
      await settleFrames(tester);
      await expectLater(
          find.byType(Scaffold), matchesGoldenFile('stage_feed_${b.name}.png'));
    });
  }

  testWidgets('profile', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: SafeArea(
          child: ProfileView(userId: 'u1', action: FollowButton(userId: 'u1')),
        ),
      ),
      overrides: [
        profileProvider.overrideWith((ref, id) async => _hanna),
        statsProvider.overrideWith(
          (ref, id) async => const ProfileStats(
              publicPosts: 12,
              likesReceived: 318,
              followers: 87,
              following: 40),
        ),
        postsByProvider.overrideWith((ref, id) async => [_posts.first]),
        followingProvider.overrideWith((ref, id) async => false),
      ],
    );
    await settleFrames(tester);
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('profile_dark.png'));
  });

  testWidgets('stage without a server', (tester) async {
    await pumpScreen(tester, const StageScreen());
    await settleFrames(tester);
    await expectLater(
        find.byType(StageScreen), matchesGoldenFile('stage_offline_dark.png'));
  });
}
