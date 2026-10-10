import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/glass.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Filter pill. Resting = clear glass; selected = ink fill.
class ToggleChip extends StatelessWidget {
  const ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.stage : c.ink;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        haptic: PressHaptic.selection,
        semanticLabel: label,
        child: SizedBox(
          height: Sizes.chip,
          child: Stack(
            children: [
              // Glass at rest; ink fades in over it when selected.
              const Positioned.fill(
                child: GlassSurface(
                  radius: Radii.full,
                  frost: false,
                  child: SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Motion.of(context, Motion.fast),
                  curve: Motion.standard,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Center(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        label,
                        style: context.type.button.copyWith(
                          color: fg,
                          fontSize: context.type.rowMeta.fontSize,
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: Space.xs),
                        Text(
                          '$count',
                          style: context.type.numeral.copyWith(
                            color: selected ? fg : c.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
