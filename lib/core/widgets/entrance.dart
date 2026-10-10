import 'package:flutter/material.dart';
import 'package:unsung/core/theme/motion.dart';

/// Staggered entrance: fade + 12px rise, delayed by [index] × stagger,
/// capped at [Motion.staggerMaxItems] so long lists never feel slow.
class Entrance extends StatefulWidget {
  const Entrance({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final int _slot = widget.index.clamp(0, Motion.staggerMaxItems);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow + Motion.stagger * _slot,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      (Motion.stagger * _slot).inMicroseconds / _c.duration!.inMicroseconds,
      1,
      curve: Motion.decelerate,
    ),
  );

  static const _rise = 12.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context) || widget.index > Motion.staggerMaxItems * 3) {
      _c.value = 1;
    } else if (_c.isDismissed) {
      _c.forward();
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
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * _rise),
          child: child,
        ),
      ),
    );
  }
}
