import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/features/social/presentation/profile_view.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/stage_gate.dart';

/// Another singer's profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authUserIdProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(),
      body: StageGate(
        child: ProfileView(
          userId: userId,
          action: me == userId
              ? QuietButton(
                  label: 'Edit profile',
                  icon: Icons.edit_rounded,
                  expand: true,
                  onTap: () => unawaited(context.push(Routes.editProfile)),
                )
              : FollowButton(userId: userId),
        ),
      ),
    );
  }
}
