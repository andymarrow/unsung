import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Primary action. Solid cue pill. Used once per screen at most.
class CueButton extends StatelessWidget {
  const CueButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          child: busy
              ? SizedBox.square(
                  key: const ValueKey('busy'),
                  dimension: Sizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: Sizes.stroke,
                    color: c.onCue,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : icon == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Icon(
                      icon,
                      key: const ValueKey('icon'),
                      size: Sizes.icon,
                      color: c.onCue,
                    ),
        ),
        if (icon != null || busy) const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.label.copyWith(color: c.onCue),
          ),
        ),
      ],
    );

    return Pressable(
      onTap: busy ? null : onTap,
      haptic: PressHaptic.light,
      semanticLabel: label,
      child: Container(
        height: Sizes.button,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        decoration: BoxDecoration(
          color: c.cue,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: content,
      ),
    );
  }
}

/// Secondary action. Raised surface, ink label.
class QuietButton extends StatelessWidget {
  const QuietButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.selection,
      semanticLabel: label,
      child: Container(
        height: Sizes.tap,
        padding: const EdgeInsets.symmetric(horizontal: Space.md + Space.xxs),
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: Sizes.iconMd, color: c.ink),
              const SizedBox(width: Space.xs),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round icon-only button with a semantic label.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  /// Draws the icon in cue (e.g. a liked heart).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.selection,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.standard,
        width: Sizes.tap,
        height: Sizes.tap,
        decoration: BoxDecoration(
          color: filled ? c.raised : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: Sizes.icon, color: active ? c.cue : c.ink),
      ),
    );
  }
}
