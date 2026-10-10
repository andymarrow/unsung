import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/entrance.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/core/widgets/waveform.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/studio/domain/take.dart';
import 'package:unsung/features/studio/presentation/takes_controller.dart';

class TakesScreen extends ConsumerWidget {
  const TakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takes = ref.watch(takesProvider);
    return Scaffold(
      // Transparent: the shell's ambient light shows through.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: switch (takes) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
              icon: Icons.graphic_eq_rounded,
              kicker: 'Takes',
              title: 'Your first take is one song away',
              message:
                  'Unsing a song from your Library, then tap Sing. Every take lands here, private until you share it.',
              actionLabel: 'Open Library',
              onAction: () => context.go(Routes.library),
            ),
          AsyncData(:final value) => _TakeList(takes: value),
          AsyncError(:final error) => ErrorState(
              failure: toFailure(error),
              onRetry: () => ref.invalidate(takesProvider),
            ),
          _ => const RowSkeletonList(),
        },
      ),
    );
  }
}

class _TakeList extends StatelessWidget {
  const _TakeList({required this.takes});

  final List<Take> takes;

  @override
  Widget build(BuildContext context) {
    final public = takes.where((t) => t.isPublic).length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.lg, Space.gutter, Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Takes', style: context.type.title),
                const SizedBox(height: Space.xxs),
                Text(
                  '${takes.length} TAKES · $public ON STAGE',
                  style: context.type.labelMuted,
                ),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: takes.length,
          separatorBuilder: (_, __) => const SizedBox(height: Space.xs),
          itemBuilder: (context, i) => Entrance(
            index: i,
            child: TakeRow(
              take: takes[i],
              onTap: () =>
                  unawaited(context.push(Routes.reviewFor(takes[i].id))),
            ),
          ),
        ),
        // Clear the floating tab bar.
        SliverToBoxAdapter(
            child: SizedBox(
                height: Space.xxl + MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }
}

class TakeRow extends StatelessWidget {
  const TakeRow({required this.take, required this.onTap, super.key});

  final Take take;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${take.songTitle}, ${take.isPublic ? 'public' : 'private'} take',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(take.songTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.rowTitle),
                ),
                const SizedBox(width: Space.xs),
                TapeLabel(
                  take.isPublic
                      ? 'On stage'
                      : (take.postId != null ? 'Uploaded' : 'Private'),
                  icon: take.isPublic
                      ? Icons.podcasts_rounded
                      : Icons.lock_rounded,
                  tone: take.isPublic ? TapeTone.cue : TapeTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: Space.xxs),
            Text(
              '${take.artist ?? 'Unknown artist'} · ${_when(take.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.rowMeta,
            ),
            const SizedBox(height: Space.sm),
            Waveform(peaks: take.peaks.isEmpty ? const [0.2, 0.2] : take.peaks),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                TapeLabel(formatDuration(take.duration),
                    tone: TapeTone.outline),
                TapeLabel('In tune ${(take.inTune * 100).round()}%',
                    tone: TapeTone.outline),
                if (take.mixPath == null)
                  const TapeLabel('Not mixed yet', tone: TapeTone.outline),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return '${t.day}.${t.month}.${t.year}';
  }
}
