import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/features/library/domain/song.dart';

/// Big round play/pause in ink.
class PlayButton extends StatelessWidget {
  const PlayButton({required this.playing, required this.onTap, super.key});

  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.light,
      semanticLabel: playing ? 'Pause' : 'Play',
      child: Container(
        width: Sizes.recordButton,
        height: Sizes.recordButton,
        decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(playing),
            color: c.stage,
            size: Sizes.iconLg,
          ),
        ),
      ),
    );
  }
}

/// − KEY +2 + : semitone stepper.
class KeyStepper extends StatelessWidget {
  const KeyStepper({
    required this.semitones,
    required this.onChanged,
    this.max = 6,
    super.key,
  });

  final int semitones;
  final ValueChanged<int> onChanged;
  final int max;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final label = semitones == 0
        ? '0'
        : semitones > 0
            ? '+$semitones'
            : '$semitones';
    return Semantics(
      label: 'Key',
      value: '$label semitones',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundIconButton(
            icon: Icons.remove_rounded,
            label: 'Lower key',
            onTap: semitones > -max ? () => onChanged(semitones - 1) : null,
          ),
          SizedBox(
            width: Sizes.tap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('KEY', style: type.labelMuted),
                Text(label, style: type.numeral),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.add_rounded,
            label: 'Raise key',
            onTap: semitones < max ? () => onChanged(semitones + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Labelled 0–100% slider in mono.
class LevelSlider extends StatelessWidget {
  const LevelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.display,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Custom readout; defaults to a percentage.
  final String? display;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Row(
      children: [
        SizedBox(
          width: Sizes.sliderLabel,
          child: Text(label.toUpperCase(), style: type.labelMuted),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 1),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            semanticFormatterCallback: (v) => display ?? '${(v * 100).round()}%',
          ),
        ),
        SizedBox(
          width: Sizes.tap,
          child: Text(
            display ?? '${(value * 100).round()}%',
            textAlign: TextAlign.end,
            style: type.numeral,
          ),
        ),
      ],
    );
  }
}

/// 1:02 / 3:47
class TimeReadout extends StatelessWidget {
  const TimeReadout({required this.position, required this.duration, super.key});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Row(
      children: [
        Text(formatDuration(position), style: type.numeral),
        const Spacer(),
        Text(
          formatDuration(duration),
          style: type.numeral.copyWith(color: context.colors.inkMuted),
        ),
      ],
    );
  }
}
