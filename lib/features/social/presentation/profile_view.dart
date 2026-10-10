import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/entrance.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/avatar.dart';
import 'package:unsung/features/social/presentation/widgets/post_card.dart';

/// Profile header, stats and takes. Used for "Me" and for other singers.
class ProfileView extends ConsumerWidget {
  const ProfileView({required this.userId, required this.action, super.key});

  final String userId;

  /// Edit profile (you) or Follow (others).
  final Widget action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(userId));
    final posts = ref.watch(postsByProvider(userId));
    return switch (profile) {
      AsyncData(value: final p) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(profileProvider(userId))
              ..invalidate(statsProvider(userId));
            await ref.refresh(postsByProvider(userId).future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(profile: p, action: action)),
              ...switch (posts) {
                AsyncData(:final value) when value.isEmpty => [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        kicker: 'Takes',
                        title: 'No takes shared yet',
                        message: 'Shared takes show up here.',
                      ),
                    ),
                  ],
                AsyncData(:final value) => [
                    SliverList.separated(
                      itemCount: value.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
                      itemBuilder: (_, i) => Entrance(
                        index: i,
                        child: PostCard(post: value[i], showAuthor: false),
                      ),
                    ),
                  ],
                AsyncError(:final error) => [
                    SliverToBoxAdapter(
                      child: ErrorState(
                        failure: toFailure(error),
                        onRetry: () => ref.invalidate(postsByProvider(userId)),
                      ),
                    ),
                  ],
                _ => [const SliverToBoxAdapter(child: RowSkeletonList(count: 3))],
              },
              const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
            ],
          ),
        ),
      AsyncError(:final error) => ErrorState(
          failure: toFailure(error),
          onRetry: () => ref.invalidate(profileProvider(userId)),
        ),
      _ => const RowSkeletonList(count: 4),
    };
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile, required this.action});

  final Profile profile;
  final Widget action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final stats = ref.watch(statsProvider(profile.id)).valueOrNull ?? const ProfileStats();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(profile: profile, size: Sizes.avatarLg, ring: true),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: type.title),
                    Text('@${profile.handle}'.toUpperCase(), style: type.labelMuted),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text(profile.bio, style: type.body),
          ],
          const SizedBox(height: Space.lg),
          Row(
            children: [
              _Stat(label: 'Takes', value: stats.publicPosts),
              _Stat(label: 'Likes', value: stats.likesReceived),
              _Stat(label: 'Followers', value: stats.followers),
              _Stat(label: 'Following', value: stats.following),
            ],
          ),
          const SizedBox(height: Space.lg),
          action,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: value.toDouble()),
                duration: Motion.of(context, Motion.signature),
                builder: (_, v, __) => Text('${v.round()}', style: context.type.heading),
              ),
              Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: context.type.labelMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Follow / Following toggle with an optimistic flip.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool? _override;
  bool _busy = false;

  Future<void> _toggle(bool following) async {
    setState(() {
      _override = !following;
      _busy = true;
    });
    try {
      final repo = ref.read(socialRepositoryProvider);
      if (repo.userId == null) throw const AuthFailure('Sign in to follow singers.');
      await (following ? repo.unfollow(widget.userId) : repo.follow(widget.userId));
      ref.invalidate(statsProvider(widget.userId));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _override = following);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFailure(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(followingProvider(widget.userId)).valueOrNull ?? false;
    final following = _override ?? server;
    return following
        ? QuietButton(
            label: 'Following',
            icon: Icons.check_rounded,
            expand: true,
            onTap: _busy ? null : () => unawaited(_toggle(true)),
          )
        : CueButton(
            label: 'Follow',
            icon: Icons.add_rounded,
            expand: true,
            busy: _busy,
            onTap: () => unawaited(_toggle(false)),
          );
  }
}
