import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// The page behind everything: the stage colour, soft neutral shading (a
/// studio wall under diffuse light, no colour) and a fine static film grain.
/// The shading is what the glass panes above it pick up; colour is kept for
/// accents only.
class Backdrop extends StatelessWidget {
  const Backdrop({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.stage),
        const _Shading(),
        RepaintBoundary(
          child: CustomPaint(
            painter: _GrainPainter(
              color: c.ink.withValues(
                  alpha: dark ? Alphas.grainDark : Alphas.grainLight),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// Two broad, soft pools of neutral shade and one of light. Static.
class _Shading extends StatelessWidget {
  const _Shading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget pool(Alignment at, double size, Color color) => Align(
          alignment: at,
          child: FractionalTranslation(
            translation: Offset(at.x * 0.3, at.y * 0.3),
            child: SizedBox.square(
              dimension: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        );
    return LayoutBuilder(
      builder: (context, box) {
        final d = box.biggest.longestSide;
        return Stack(
          fit: StackFit.expand,
          children: [
            pool(Alignment.topRight, d * 0.9, c.ambient),
            pool(Alignment.bottomLeft, d * 0.8, c.ambient),
            pool(Alignment.topLeft, d * 0.6, c.glassRim),
          ],
        );
      },
    );
  }
}

/// Fixed random specks on a repeating tile. Deterministic (same seed every
/// launch) and painted once: the layer is cached by its RepaintBoundary.
class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.color});

  final Color color;

  static final Float32List _tile = () {
    final r = math.Random(7);
    final points = Float32List(Grain.specks * 2);
    for (var i = 0; i < points.length; i++) {
      points[i] = r.nextDouble() * Grain.tile;
    }
    return points;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = Grain.speck
      ..strokeCap = StrokeCap.round;
    for (var y = 0.0; y < size.height; y += Grain.tile) {
      for (var x = 0.0; x < size.width; x += Grain.tile) {
        canvas
          ..save()
          ..translate(x, y)
          ..drawRawPoints(ui.PointMode.points, _tile, paint)
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.color != color;
}
