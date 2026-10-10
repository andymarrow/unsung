import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';

enum PressHaptic { none, selection, light, heavy }

/// The one press behaviour used across the app: scale to 0.96 on the
/// standard curve, optional haptic, 48dp minimum hit area, semantics.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.haptic = PressHaptic.none,
    this.minSize = Sizes.tap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final PressHaptic haptic;
  final double minSize;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  void _tap() {
    switch (widget.haptic) {
      case PressHaptic.none:
        break;
      case PressHaptic.selection:
        unawaited(HapticFeedback.selectionClick());
      case PressHaptic.light:
        unawaited(HapticFeedback.lightImpact());
      case PressHaptic.heavy:
        unawaited(HapticFeedback.heavyImpact());
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap == null ? null : _tap,
        onLongPress: widget.onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minSize,
            minHeight: widget.minSize,
          ),
          child: AnimatedScale(
            scale: _down ? Motion.pressedScale : 1,
            duration: Motion.of(context, Motion.fast),
            curve: Motion.standard,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : Alphas.disabled,
              duration: Motion.of(context, Motion.fast),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
