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

import '../helpers/demo_social.dart';
import '../helpers/fonts.dart';
import '../helpers/pump.dart';

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
              itemCount: demoPosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
              itemBuilder: (_, i) => PostCard(post: demoPosts[i]),
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
        profileProvider.overrideWith((ref, id) async => demoHanna),
        statsProvider.overrideWith(
          (ref, id) async => const ProfileStats(
              publicPosts: 12,
              likesReceived: 318,
              followers: 87,
              following: 40),
        ),
        postsByProvider.overrideWith((ref, id) async => [demoPosts.first]),
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
