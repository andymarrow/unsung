import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/features/karaoke/presentation/unsinging_view.dart';
import 'package:unsung/features/studio/presentation/pitch_ribbon.dart';
import 'package:unsung/features/studio/presentation/studio_session.dart';

/// Deterministic, music-like envelope for illustrations.
List<double> _envelope(int seed, int n) => [
      for (var i = 0; i < n; i++)
        (0.3 +
                0.45 * math.sin(i / 7 + seed).abs() +
                0.25 * math.sin(i * 1.7 + seed * 3).abs())
            .clamp(0.0, 1.0),
    ];

/// Beat 1: the Unsinging, looping slowly.
class UnsingBeatVisual extends StatefulWidget {
  const UnsingBeatVisual({super.key});

  @override
  State<UnsingBeatVisual> createState() => _UnsingBeatVisualState();
}

class _UnsingBeatVisualState extends State<UnsingBeatVisual>
    with SingleTickerProviderStateMixin {
  static const _loop = Duration(milliseconds: 4200);
  static final _inst = _envelope(1, 120);
  static final _voice = _envelope(4, 120);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 0.62;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Run to 85% of the loop, then hold "done" so the ribbon floats off.
        final p = (_c.value / 0.85).clamp(0.0, 1.0);
        final n = (p * _inst.length).ceil().clamp(1, _inst.length);
        return UnsingingView(
          progress: p,
          done: p >= 1,
          instrumentalPeaks: _inst.sublist(0, n),
          vocalPeaks: _voice.sublist(0, n),
        );
      },
    );
  }
}

/// Beat 2: a half-sung line over a glowing pitch ribbon.
class StudioBeatVisual extends StatefulWidget {
  const StudioBeatVisual({super.key});

  @override
  State<StudioBeatVisual> createState() => _StudioBeatVisualState();
}

class _StudioBeatVisualState extends State<StudioBeatVisual> {
  final _history = PitchHistory();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _history.length; i++) {
      final phrase = i ~/ 30;
      final gap = i % 30 > 26;
      final drift = (i % 30) < 6 ? 0.45 : 0.04;
      _history.push(gap ? null : 60 + [0, 2, 4, 2, 0, -1][phrase % 6] + drift);
    }
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.type.lyricActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => LinearGradient(
            colors: [c.cue, c.cue, c.ink, c.ink],
            stops: const [0, 0.55, 0.55, 1],
          ).createShader(b),
          child: Text('Sing it like nobody’s listening', style: style),
        ),
        const SizedBox(height: Space.md),
        PitchRibbon(history: _history),
      ],
    );
  }
}

/// Beat 3: private → on stage, with a like count.
class StageBeatVisual extends StatelessWidget {
  const StageBeatVisual({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    return Column(
      children: [
        const _MiniCard(
          title: 'Take 3 · rough',
          tag: TapeLabel('Only you', icon: Icons.lock_rounded),
        ),
        const SizedBox(height: Space.sm),
        _MiniCard(
          title: 'Take 7 · the one',
          lit: true,
          tag: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: c.cue, size: Sizes.iconSm),
              const SizedBox(width: Space.xxs),
              Text('128', style: type.numeral),
              const SizedBox(width: Space.sm),
              const TapeLabel('On stage',
                  icon: Icons.podcasts_rounded, tone: TapeTone.cue),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.title, required this.tag, this.lit = false});

  final String title;
  final Widget tag;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: lit ? Border.all(color: c.cue) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.type.rowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Space.xs),
          tag,
        ],
      ),
    );
  }
}
