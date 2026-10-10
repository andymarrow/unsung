import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';

/// Shows [child] only when the Stage backend is connected (and, if
/// [requireSignIn], the user is signed in). Otherwise a designed explainer.
class StageGate extends ConsumerWidget {
  const StageGate({
    required this.child,
    this.requireSignIn = false,
    this.kicker = 'The Stage',
    super.key,
  });

  final Widget child;
  final bool requireSignIn;
  final String kicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(socialRepositoryProvider);
    if (!repo.configured) {
      return EmptyState(
        icon: Icons.podcasts_rounded,
        kicker: kicker,
        title: 'The Stage opens soon',
        message:
            "Sharing needs the Unsung server, and this build isn't connected to one yet. Unsinging, rehearsing and recording all work, and your takes are safe on this phone.",
      );
    }
    if (!requireSignIn) return child;
    final user = ref.watch(authUserIdProvider);
    return switch (user) {
      AsyncData(value: final String _) => child,
      AsyncData() => EmptyState(
          icon: Icons.person_outline_rounded,
          kicker: kicker,
          title: 'Claim your name',
          message:
              'Sign in with your email to get a profile, share takes, like and follow. Takes stay private until you choose otherwise.',
          actionLabel: 'Sign in with email',
          onAction: () => unawaited(context.push(Routes.signIn)),
        ),
      _ => const RowSkeletonList(count: 3),
    };
  }
}
