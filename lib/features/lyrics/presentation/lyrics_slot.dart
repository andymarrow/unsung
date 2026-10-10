import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/lyrics/data/lyrics_repository.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_editor_sheet.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_view.dart';

/// Lyrics for a song in every state: breathing skeleton lines while they
/// load, the live view when they're here, and a calm way forward (retry or
/// add your own) when they can't be fetched. Used by Rehearse and Studio so
/// the singing area is never blank.
class LyricsSlot extends ConsumerWidget {
  const LyricsSlot({
    required this.song,
    required this.position,
    this.offset = Duration.zero,
    this.topInset = Space.lg,
    this.running = true,
    super.key,
  });

  final Song song;
  final Duration Function() position;
  final Duration offset;
  final double topInset;

  /// See [LyricsView.running].
  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider(song));
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.base),
      switchInCurve: Motion.decelerate,
      child: switch (lyrics) {
        AsyncData(:final value) => LyricsView(
            key: const ValueKey('lyrics'),
            lyrics: value,
            position: position,
            offset: offset,
            topInset: topInset,
            running: running,
            onAddLyrics: () => unawaited(showLyricsEditor(context, song)),
          ),
        AsyncError(:final error) => _Unavailable(
            key: const ValueKey('error'),
            failure: toFailure(error),
            onRetry: () => ref.invalidate(lyricsProvider(song)),
            onAdd: () => unawaited(showLyricsEditor(context, song)),
          ),
        _ => LyricsSkeleton(key: const ValueKey('loading'), top: topInset),
      },
    );
  }
}

/// Three lyric-shaped lines that breathe while lyrics load.
class LyricsSkeleton extends StatelessWidget {
  const LyricsSkeleton({this.top = Space.lg, super.key});

  final double top;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading lyrics',
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.gutter, top, Space.gutter, 0),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: Sizes.artworkHero, height: Space.lg),
            SizedBox(height: Space.md),
            Skeleton(width: Sizes.artworkHero * 1.2, height: Space.xl),
            SizedBox(height: Space.md),
            Skeleton(width: Sizes.artworkHero * 0.8, height: Space.lg),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.failure,
    required this.onRetry,
    required this.onAdd,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final offline = failure is OfflineFailure;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(offline ? 'NO CONNECTION' : 'NO LYRICS YET',
              style: type.labelMuted),
          const SizedBox(height: Space.xs),
          Text(
            offline
                ? 'Lyrics need a connection the first time. You can still sing, or paste your own.'
                : "We couldn't fetch lyrics for this one. Paste your own and they'll stay with the song.",
            style: type.bodyMuted,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              QuietButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry),
              QuietButton(
                  label: 'Add lyrics',
                  icon: Icons.edit_note_rounded,
                  onTap: onAdd),
            ],
          ),
        ],
      ),
    );
  }
}
