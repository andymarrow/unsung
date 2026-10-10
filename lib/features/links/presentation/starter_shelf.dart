import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/entrance.dart';
import 'package:unsung/core/widgets/glass.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';
import 'package:unsung/features/links/domain/starters.dart';
import 'package:unsung/features/links/presentation/link_sheet.dart';

/// "Start with a classic": a horizontal shelf of well-known songs on glass.
/// Tapping one opens From a link with it filled in; songs already brought in
/// are left off the shelf.
class StarterShelf extends ConsumerWidget {
  const StarterShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final have = {for (final s in ref.watch(songsProvider)) s.id};
    final shelf = [
      for (final s in starters)
        if (!have.contains('yt-${s.videoId}')) s,
    ];
    if (shelf.isEmpty) return const SizedBox.shrink();
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Space.gutter, Space.lg, Space.gutter, Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Start with a classic', style: type.section),
              ),
              Text('FROM YOUTUBE', style: type.labelMuted),
            ],
          ),
        ),
        SizedBox(
          height: Sizes.shelfCard / Sizes.videoAspect +
              MediaQuery.textScalerOf(context).scale(Sizes.shelfText),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: shelf.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) => Entrance(
              index: i,
              child: _StarterCard(
                starter: shelf[i],
                onTap: () => unawaited(
                    showLinkSheet(context, initialText: shelf[i].url)),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({required this.starter, required this.onTap});

  final Starter starter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Bring in ${starter.title} by ${starter.artist}',
      child: SizedBox(
        width: Sizes.shelfCard,
        child: GlassSurface(
          frost: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: Sizes.videoAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: c.raised),
                    Image.network(
                      starter.thumbnailUrl,
                      fit: BoxFit.cover,
                      cacheWidth: (Sizes.shelfCard * dpr).round(),
                      semanticLabel: 'Video thumbnail',
                      frameBuilder: (context, child, frame, sync) => sync
                          ? child
                          : AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: Motion.of(context, Motion.slow),
                              curve: Motion.decelerate,
                              child: child,
                            ),
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note_rounded,
                          color: c.inkFaint,
                          size: Sizes.iconLg),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.sm, Space.sm, Space.sm, Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(starter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.rowTitle),
                    Text(starter.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.rowMeta),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
