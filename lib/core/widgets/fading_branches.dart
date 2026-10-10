import 'package:flutter/material.dart';
import 'package:unsung/core/theme/motion.dart';

/// The shell's tabs, all kept alive (scroll positions, playing state), with
/// a quick cross-fade and a slight settle when switching. Hidden tabs don't
/// tick animations or take touches.
class FadingBranches extends StatelessWidget {
  const FadingBranches({
    required this.index,
    required this.children,
    super.key,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.base);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(
            active: i == index,
            duration: d,
            child: children[i],
          ),
      ],
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.active,
    required this.duration,
    required this.child,
  });

  final bool active;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: Motion.standard,
          child: AnimatedScale(
            scale: active ? 1 : Motion.tabScale,
            duration: duration,
            curve: Motion.decelerate,
            child: ExcludeSemantics(excluding: !active, child: child),
          ),
        ),
      ),
    );
  }
}
