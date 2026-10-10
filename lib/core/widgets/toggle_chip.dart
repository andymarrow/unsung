import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Filter pill. Selected = ink fill; resting = hairline outline only.
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
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          curve: Motion.standard,
          height: Sizes.chip,
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: selected ? c.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.full),
            border: Border.all(color: selected ? c.ink : c.hairline),
          ),
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
      ),
    );
  }
}
