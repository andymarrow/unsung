import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/toggle_chip.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/social/presentation/widgets/avatar.dart';
import 'package:unsung/features/social/presentation/widgets/post_card.dart';
import 'package:unsung/features/social/presentation/widgets/stage_gate.dart';
import 'package:unsung/features/studio/domain/take.dart';
import 'package:unsung/features/studio/presentation/takes_controller.dart';

class PostScreen extends ConsumerWidget {
  const PostScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postProvider(postId));
    return Scaffold(
      appBar: AppBar(title: Text('TAKE', style: context.type.labelMuted)),
      body: StageGate(
        child: switch (post) {
          AsyncData(:final value) => _PostBody(post: value),
          AsyncError(:final error) => ErrorState(
              failure: toFailure(error),
              onRetry: () => ref.invalidate(postProvider(postId)),
            ),
          _ => const RowSkeletonList(count: 3),
        },
      ),
    );
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authUserIdProvider).valueOrNull;
    final mine = me == post.author.id;
    final comments = ref.watch(commentsProvider(post.id));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.lg),
            children: [
              PostCard(post: post),
              if (mine) _OwnerPanel(post: post),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.gutter, Space.lg, Space.gutter, Space.sm),
                child: Text('COMMENTS', style: context.type.labelMuted),
              ),
              ...switch (comments) {
                AsyncData(:final value) when value.isEmpty => [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Text(
                        post.isPublic
                            ? 'No comments yet. Say something kind.'
                            : 'Only you can see this take, so comments are off.',
                        style: context.type.bodyMuted,
                      ),
                    ),
                  ],
                AsyncData(:final value) => [
                    for (final c in value)
                      _CommentTile(
                          comment: c, canDelete: c.author.id == me || mine),
                  ],
                AsyncError(:final error) => [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Text(toFailure(error).message,
                          style: context.type.bodyMuted),
                    ),
                  ],
                _ => [const RowSkeletonList(count: 2)],
              },
            ],
          ),
        ),
        if (post.isPublic && me != null) _Composer(postId: post.id),
      ],
    );
  }
}

class _OwnerPanel extends ConsumerStatefulWidget {
  const _OwnerPanel({required this.post});

  final Post post;

  @override
  ConsumerState<_OwnerPanel> createState() => _OwnerPanelState();
}

class _OwnerPanelState extends ConsumerState<_OwnerPanel> {
  bool _busy = false;

  Future<void> _set(TakeVisibility v) async {
    if (v == widget.post.visibility || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareActionsProvider).setVisibility(widget.post, v);
      await _syncLocalTake(v);
      unawaited(HapticFeedback.mediumImpact());
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(toFailure(e).message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncLocalTake(TakeVisibility v) async {
    final takes = ref.read(takesProvider).valueOrNull ?? const <Take>[];
    for (final t in takes) {
      if (t.postId == widget.post.id) {
        await ref
            .read(takesProvider.notifier)
            .upsert(t.copyWith(visibility: v));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: d.colors.surface,
        title: Text('Remove from the Stage?', style: d.type.heading),
        content: Text(
            'Likes and comments go with it. The take stays on your phone.',
            style: d.type.bodyMuted),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text('KEEP', style: d.type.label)),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('REMOVE',
                style: d.type.label.copyWith(color: d.colors.cue)),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await ref.read(stagePlayerProvider.notifier).stop();
    await ref.read(shareActionsProvider).delete(widget.post);
    final takes = ref.read(takesProvider).valueOrNull ?? const <Take>[];
    for (final t in takes) {
      if (t.postId == widget.post.id) {
        await ref.read(takesProvider.notifier).upsert(
              Take.fromJson({
                ...t.toJson(),
                'postId': null,
                'visibility': TakeVisibility.private.name
              }),
            );
      }
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final public = widget.post.isPublic;
    return Container(
      margin:
          const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
          color: context.colors.raised,
          borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHO CAN HEAR THIS', style: type.labelMuted),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ToggleChip(
                  label: 'Only me',
                  selected: !public,
                  onTap: () => unawaited(_set(TakeVisibility.private))),
              ToggleChip(
                  label: 'Everyone',
                  selected: public,
                  onTap: () => unawaited(_set(TakeVisibility.public))),
              AnimatedOpacity(
                opacity: _busy ? 1 : 0,
                duration: Motion.of(context, Motion.fast),
                child: const SizedBox.square(
                  dimension: Sizes.iconSm,
                  child: CircularProgressIndicator(strokeWidth: Sizes.stroke),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            public
                ? 'On the Stage. Anyone can listen, like and comment.'
                : 'Saved to your profile, visible only to you. Make it public whenever you like.',
            style: type.rowMeta,
          ),
          const SizedBox(height: Space.sm),
          TextButton(
            onPressed: () => unawaited(_delete()),
            child: Text('REMOVE FROM STAGE', style: type.labelMuted),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment, required this.canDelete});

  final Comment comment;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter, vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(profile: comment.author),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: comment.author.name, style: type.rowTitle),
                      TextSpan(
                          text: '  ${timeAgo(comment.createdAt)}',
                          style: type.rowMeta),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xxs),
                Text(comment.body, style: type.body),
              ],
            ),
          ),
          if (canDelete)
            RoundIconButton(
              icon: Icons.close_rounded,
              label: 'Delete comment',
              onTap: () => unawaited(ref
                  .read(commentsProvider(comment.postId).notifier)
                  .remove(comment)),
            ),
        ],
      ),
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.postId});

  final String postId;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(commentsProvider(widget.postId).notifier).add(body);
      _text.clear();
      ref.invalidate(postProvider(widget.postId));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(toFailure(e).message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
          color: c.surface, border: Border(top: BorderSide(color: c.hairline))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Space.gutter, Space.xs, Space.xs, Space.xs),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 4,
                  style: context.type.body,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => unawaited(_send()),
                  decoration: const InputDecoration(
                      hintText: 'Add a comment', counterText: ''),
                ),
              ),
              const SizedBox(width: Space.xs),
              RoundIconButton(
                icon: Icons.arrow_upward_rounded,
                label: 'Send comment',
                filled: true,
                onTap: _busy ? null : () => unawaited(_send()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
