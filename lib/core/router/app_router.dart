import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/widgets/app_shell.dart';
import 'package:unsung/features/library/presentation/library_screen.dart';
import 'package:unsung/features/me/presentation/me_screen.dart';
import 'package:unsung/features/onboarding/onboarding_screen.dart';
import 'package:unsung/features/stage/presentation/stage_screen.dart';
import 'package:unsung/features/takes/presentation/takes_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          shell: shell,
          onSing: () => shell.goBranch(0),
        ),
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
    ],
  );
});
