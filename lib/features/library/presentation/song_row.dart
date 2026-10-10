import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/artwork.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';

class SongRow extends ConsumerWidget {
  const SongRow({required this.song, required this.onTap, super.key});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final art = ref.watch(artworkProvider(song)).valueOrNull;
    final ready = ref.watch(karaokeTrackProvider(song.id)) != null;
    final job = ref.watch(karaokeJobProvider(song.id));

    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${song.title} by ${song.artistOrUnknown}${ready ? ', karaoke ready' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.xs,
        ),
        child: Row(
          children: [
            Hero(
              tag: 'art-${song.id}',
              child: Artwork(
                title: song.title,
                bytes: art,
                size: Sizes.artworkRow,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.rowTitle,
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    '${song.artistOrUnknown} · ${formatDuration(song.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.rowMeta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.base),
              switchInCurve: Motion.emphasized,
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: switch (job) {
                KaraokeRunning(:final progress) => _Ring(
                    key: const ValueKey('ring'),
                    value: progress,
                  ),
                KaraokeFailed() => const TapeLabel(
                    'Failed',
                    key: ValueKey('failed'),
                    tone: TapeTone.outline,
                  ),
                null when ready => const TapeLabel(
                    'Ready',
                    key: ValueKey('ready'),
                    tone: TapeTone.cue,
                  ),
                null => const SizedBox.shrink(key: ValueKey('none')),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: Sizes.icon,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: Motion.of(context, Motion.base),
        builder: (_, v, __) => CircularProgressIndicator(
          value: v,
          strokeWidth: Sizes.stroke,
          semanticsLabel: 'Unsinging',
          semanticsValue: '${(v * 100).round()}%',
        ),
      ),
    );
  }
}
