import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Stage light drifting slowly behind the app: two warm pools of cue light
/// and one ember, moving on long, out-of-phase loops so the glass above has
/// something to catch. Barely there by design; still with reduce-motion.
class AmbientLight extends StatefulWidget {
  const AmbientLight({this.child, super.key});

  final Widget? child;

  /// Holds the light still (tests and screenshots need settled frames).
  @visibleForTesting
  static bool debugStill = false;

  @override
  State<AmbientLight> createState() => _AmbientLightState();
}

class _AmbientLightState extends State<AmbientLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: Motion.ambient);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context) || AmbientLight.debugStill) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.stage),
        RepaintBoundary(
          child: CustomPaint(
            painter: _AmbientPainter(
              t: _drift,
              cue: c.cue,
              ember: Color.lerp(c.cue, c.ink, Alphas.emberMix)!,
              strength: dark ? Alphas.ambientDark : Alphas.ambientLight,
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.t,
    required this.cue,
    required this.ember,
    required this.strength,
  }) : super(repaint: t);

  final Animation<double> t;
  final Color cue;
  final Color ember;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * math.pi;
    void pool(Color color, double x, double y, double r, double alpha) {
      final centre = Offset(size.width * x, size.height * y);
      final radius = size.longestSide * r;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    // Three pools on different loops (1x, 2x, 3x) so the light never
    // visibly repeats.
    pool(cue, 0.15 + 0.10 * math.sin(a), 0.08 + 0.05 * math.cos(a), 0.55,
        strength);
    pool(ember, 0.90 + 0.08 * math.cos(2 * a), 0.45 + 0.10 * math.sin(a), 0.50,
        strength * 0.8);
    pool(cue, 0.40 + 0.15 * math.sin(3 * a + 1), 1, 0.45, strength * 0.6);
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.cue != cue || old.ember != ember || old.strength != strength;
}
