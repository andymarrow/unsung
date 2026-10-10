import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/router/spotlight_page.dart';
import 'package:unsung/core/widgets/app_shell.dart';
import 'package:unsung/core/widgets/fading_branches.dart';
import 'package:unsung/core/widgets/glass_sheet.dart';
import 'package:unsung/features/library/presentation/library_screen.dart';
import 'package:unsung/features/me/presentation/me_screen.dart';
import 'package:unsung/features/onboarding/onboarding_screen.dart';
import 'package:unsung/features/player/rehearse_screen.dart';
import 'package:unsung/features/social/presentation/edit_profile_screen.dart';
import 'package:unsung/features/social/presentation/post_screen.dart';
import 'package:unsung/features/social/presentation/profile_screen.dart';
import 'package:unsung/features/social/presentation/sign_in_screen.dart';
import 'package:unsung/features/stage/presentation/stage_screen.dart';
import 'package:unsung/features/studio/presentation/review_screen.dart';
import 'package:unsung/features/studio/presentation/studio_screen.dart';
import 'package:unsung/features/takes/presentation/takes_screen.dart';

/// The app's top navigator. Sheets opened from outside a screen (e.g. a
/// shared link arriving) use its context.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The Sing button: pick a ready song, then open the studio.
void _openSingPicker(BuildContext context) {
  unawaited(
    showGlassSheet<void>(
      context,
      builder: (sheet) => ReadySongPicker(
        onPick: (song) {
          Navigator.of(sheet).pop();
          unawaited(context.push(Routes.studioFor(song.id)));
        },
      ),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.library,
    redirect: (context, state) {
      final onboarded = ref.read(onboardedProvider);
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!onboarded && !atOnboarding) return Routes.onboarding;
      if (onboarded && atOnboarding) return Routes.library;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(
          shell: shell,
          onSing: () => _openSingPicker(context),
        ),
        navigatorContainerBuilder: (context, shell, children) =>
            FadingBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (_, __) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stage,
                builder: (_, __) => const StageScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.takes,
                builder: (_, __) => const TakesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.me,
                builder: (_, __) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.rehearse,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            RehearseScreen(songId: state.pathParameters['songId']!),
      ),
      GoRoute(
        path: Routes.studio,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => spotlightPage(
          key: state.pageKey,
          child: StudioScreen(songId: state.pathParameters['songId']!),
        ),
      ),
      GoRoute(
        path: Routes.signIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.post,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            PostScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            ProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: Routes.review,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            ReviewScreen(takeId: state.pathParameters['takeId']!),
      ),
    ],
  );
});
