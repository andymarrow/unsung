import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/entrance.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/toggle_chip.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/post_card.dart';
import 'package:unsung/features/social/presentation/widgets/stage_gate.dart';

class StageScreen extends ConsumerStatefulWidget {
  const StageScreen({super.key});

  @override
  ConsumerState<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends ConsumerState<StageScreen> {
  FeedScope _scope = FeedScope.forYou;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.lg, Space.gutter, Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stage', style: context.type.title),
                  const SizedBox(height: Space.xxs),
                  Text('VOICES FROM EVERYWHERE',
                      style: context.type.labelMuted),
                ],
              ),
            ),
            Expanded(
              child: StageGate(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Space.gutter, 0, Space.gutter, Space.sm),
                      child: Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          ToggleChip(
                            label: 'For you',
                            selected: _scope == FeedScope.forYou,
                            onTap: () =>
                                setState(() => _scope = FeedScope.forYou),
                          ),
                          ToggleChip(
                            label: 'Following',
                            selected: _scope == FeedScope.following,
                            onTap: () =>
                                setState(() => _scope = FeedScope.following),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _Feed(scope: _scope)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.scope});

  final FeedScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider(scope));
    return switch (feed) {
      AsyncData(:final value) when value.posts.isEmpty =>
        scope == FeedScope.forYou
            ? EmptyState(
                icon: Icons.nightlife_rounded,
                kicker: 'Quiet night',
                title: 'Nobody has taken the stage yet',
                message:
                    'Be the first. Save a take, then share it publicly from your Takes.',
                actionLabel: 'Open Takes',
                onAction: () => context.go(Routes.takes),
              )
            : const EmptyState(
                icon: Icons.group_add_rounded,
                kicker: 'Following',
                title: 'Follow voices you love',
                message:
                    'Open a singer from For you and tap Follow. Their new takes show up here.',
              ),
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(feedProvider(scope).future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < Sizes.artworkHero) {
                unawaited(ref.read(feedProvider(scope).notifier).more());
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: Space.xxl),
              itemCount: value.posts.length + (value.loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
              itemBuilder: (context, i) => i >= value.posts.length
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Skeleton(
                          height: Sizes.postSkeleton, radius: Radii.card),
                    )
                  : Entrance(index: i, child: PostCard(post: value.posts[i])),
            ),
          ),
        ),
      AsyncError(:final error) => ErrorState(
          failure: toFailure(error),
          onRetry: () => ref.invalidate(feedProvider(scope)),
        ),
      _ => const RowSkeletonList(count: 4),
    };
  }
}
