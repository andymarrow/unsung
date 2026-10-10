import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Private ↔ public switch. Going public flips the lock into a broadcast
/// mark and sends a cue ripple out from it; going private folds back
/// without the ripple.
class VisibilityToggle extends StatefulWidget {
  const VisibilityToggle({
    required this.public,
    required this.onChanged,
    this.busy = false,
    super.key,
  });

  final bool public;
  final ValueChanged<bool> onChanged;
  final bool busy;

  @override
  State<VisibilityToggle> createState() => _VisibilityToggleState();
}

class _VisibilityToggleState extends State<VisibilityToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: Motion.ripple);

  @override
  void didUpdateWidget(VisibilityToggle old) {
    super.didUpdateWidget(old);
    if (widget.public && !old.public && !Motion.reduced(context)) {
      unawaited(_ripple.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final public = widget.public;
    final duration = Motion.of(context, Motion.base);

    final mark = SizedBox.square(
      dimension: Sizes.tap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ripple,
            builder: (context, _) {
              final t = Motion.decelerate.transform(_ripple.value);
              if (_ripple.value == 0 || _ripple.value == 1) {
                return const SizedBox.shrink();
              }
              return Container(
                width: Sizes.tap * (0.6 + t),
                height: Sizes.tap * (0.6 + t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.cue.withValues(alpha: 1 - t),
                    width: Sizes.strokeBold,
                  ),
                ),
              );
            },
          ),
          AnimatedContainer(
            duration: duration,
            curve: Motion.standard,
            width: Sizes.chip,
            height: Sizes.chip,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: public ? c.cue : c.raised,
            ),
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Motion.emphasized,
              transitionBuilder: (child, a) => RotationTransition(
                turns:
                    Tween<double>(begin: Motion.flipTurns, end: 0).animate(a),
                child: ScaleTransition(scale: a, child: child),
              ),
              child: Icon(
                public ? Icons.podcasts_rounded : Icons.lock_rounded,
                key: ValueKey(public),
                size: Sizes.icon,
                color: public ? c.onCue : c.ink,
              ),
            ),
          ),
        ],
      ),
    );

    final track = AnimatedContainer(
      duration: duration,
      curve: Motion.standard,
      width: Sizes.switchWidth,
      height: Sizes.switchHeight,
      padding: const EdgeInsets.all(Space.xxs),
      decoration: BoxDecoration(
        color: public ? c.cue : c.raised,
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: c.hairline),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Motion.emphasized,
        alignment: public ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: Sizes.switchThumb,
          height: Sizes.switchThumb,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: public ? c.onCue : c.inkMuted,
          ),
        ),
      ),
    );

    return Semantics(
      toggled: public,
      label: public ? 'Public, on the Stage' : 'Private, only you',
      child: Pressable(
        onTap: widget.busy ? null : () => widget.onChanged(!public),
        haptic: PressHaptic.selection,
        child: Row(
          children: [
            mark,
            const SizedBox(width: Space.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: Text(
                  public ? 'EVERYONE' : 'ONLY ME',
                  key: ValueKey(public),
                  style: type.label,
                ),
              ),
            ),
            if (widget.busy)
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: SizedBox.square(
                  dimension: Sizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: Sizes.stroke,
                    color: c.inkMuted,
                  ),
                ),
              ),
            track,
          ],
        ),
      ),
    );
  }
}
