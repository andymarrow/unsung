import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Mono filter chip. Selected = ink fill, animates between states.
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
            color: selected ? c.ink : c.raised,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == null
                    ? label.toUpperCase()
                    : '${label.toUpperCase()}  $count',
                style: context.type.label.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
