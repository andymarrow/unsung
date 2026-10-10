import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/glass_sheet.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/presentation/profile_view.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/stage_gate.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authUserIdProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.lg, Space.xs, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Me', style: context.type.title)),
                  if (userId != null)
                    RoundIconButton(
                      icon: Icons.logout_rounded,
                      label: 'Sign out',
                      onTap: () => unawaited(_signOut(context, ref)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StageGate(
                kicker: 'Your profile',
                requireSignIn: true,
                child: userId == null
                    ? const SizedBox.shrink()
                    : ProfileView(
                        userId: userId,
                        action: QuietButton(
                          label: 'Edit profile',
                          icon: Icons.edit_rounded,
                          expand: true,
                          onTap: () =>
                              unawaited(context.push(Routes.editProfile)),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: 'Sign out?',
      message: 'Your takes stay on this phone.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay',
    );
    if (ok) {
      await ref.read(stagePlayerProvider.notifier).stop();
      await ref.read(socialRepositoryProvider).signOut();
    }
  }
}
