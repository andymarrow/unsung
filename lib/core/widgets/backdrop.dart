import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// The page behind everything: the flat stage colour with a fine, static
/// film grain, so large dark or light areas read as a material (paper,
/// matte card) rather than a flat fill. Neutral by design: colour is kept
/// for accents only.
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
