import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/equalizer.dart';
import 'package:unsung/core/widgets/glass.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/core/widgets/waveform.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/avatar.dart';
import 'package:unsung/features/social/presentation/widgets/like_button.dart';

/// A take on the Stage: who sang what, play it in place, like, open comments.
class PostCard extends ConsumerWidget {
  const PostCard({required this.post, this.showAuthor = true, super.key});

  final Post post;
  final bool showAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final c = context.colors;
    final playback = ref.watch(stagePlayerProvider);
    final mine = playback.postId == post.id;
    final progress = mine && post.duration.inMilliseconds > 0
        ? playback.position.inMilliseconds / post.duration.inMilliseconds
        : 0.0;

    Future<void> play() async {
      final error = await ref.read(stagePlayerProvider.notifier).toggle(post);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }

    return Pressable(
      onTap: () => unawaited(context.push(Routes.postFor(post.id))),
      semanticLabel: '${post.author.name} sings ${post.songTitle}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        // Glass on the ambient light; your own posts carry a cue tint.
        child: GlassSurface(
          frost: false,
          padding: const EdgeInsets.all(Space.md),
          tint: mine
              ? Color.alphaBlend(c.cue.withValues(alpha: Alphas.ghost), c.glass)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAuthor) ...[
                _AuthorRow(post: post),
                const SizedBox(height: Space.sm),
              ],
              Text(post.songTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.heading),
              if (post.artist != null)
                Text('originally by ${post.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.rowMeta),
              if (post.caption.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Text(post.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: type.body),
              ],
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  _MiniPlay(
                    playing: mine && playback.playing,
                    loading: mine && playback.loading,
                    onTap: () => unawaited(play()),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Waveform(
                      peaks: post.peaks.isEmpty
                          ? const [0.3, 0.5, 0.3]
                          : post.peaks,
                      progress: progress.clamp(0.0, 1.0),
                      onSeek: mine
                          ? (f) => unawaited(ref
                              .read(stagePlayerProvider.notifier)
                              .seek(post, f))
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  LikeButton(post: post),
                  Semantics(
                    label: '${post.commentCount} comments',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mode_comment_outlined,
                            size: Sizes.iconMd, color: c.inkMuted),
                        const SizedBox(width: Space.xxs),
                        Text('${post.commentCount}',
                            style: type.numeral.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  if (!post.isPublic)
                    const TapeLabel('Only you', icon: Icons.lock_rounded),
                  TapeLabel('${(post.inTune * 100).round()}% in tune',
                      tone: TapeTone.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Pressable(
      onTap: () => unawaited(context.push(Routes.profileFor(post.author.id))),
      semanticLabel: 'Open ${post.author.name}’s profile',
      minSize: Sizes.avatarSm,
      child: Row(
        children: [
          Avatar(profile: post.author),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: post.author.name, style: type.rowTitle),
                  TextSpan(
                      text: '  @${post.author.handle}', style: type.rowMeta),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(timeAgo(post.createdAt).toUpperCase(), style: type.labelMuted),
        ],
      ),
    );
  }
}

class _MiniPlay extends StatelessWidget {
  const _MiniPlay(
      {required this.playing, required this.loading, required this.onTap});

  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.selection,
      semanticLabel: playing ? 'Pause' : 'Play',
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        width: Sizes.tap,
        height: Sizes.tap,
        decoration: BoxDecoration(
            color: playing ? c.cue : c.ink, shape: BoxShape.circle),
        child: loading
            ? Center(child: Equalizer(size: Sizes.iconSm, color: c.stage))
            : Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: playing ? c.onCue : c.stage,
                size: Sizes.icon,
              ),
      ),
    );
  }
}
