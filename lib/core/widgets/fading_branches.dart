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

class _Branch extends StatefulWidget {
  const _Branch({
    required this.active,
    required this.duration,
    required this.child,
  });

  final bool active;
  final Duration duration;
  final Widget child;

  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> {
  /// False once a hidden tab has finished fading out: it is then not
  /// painted at all, so transparent screens never show through each other.
  late bool _painted = widget.active;

  @override
  void didUpdateWidget(_Branch old) {
    super.didUpdateWidget(old);
    if (widget.active) _painted = true;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    // The fade itself must keep ticking while the tab hides; only the
    // tab's own content is paused.
    return Offstage(
      offstage: !_painted,
      child: IgnorePointer(
        ignoring: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: widget.duration,
          curve: Motion.standard,
          onEnd: () {
            if (!widget.active && mounted) setState(() => _painted = false);
          },
          child: AnimatedScale(
            scale: active ? 1 : Motion.tabScale,
            duration: widget.duration,
            curve: Motion.decelerate,
            child: TickerMode(
              enabled: active,
              child: ExcludeSemantics(excluding: !active, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
