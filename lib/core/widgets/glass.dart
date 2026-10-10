import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// A pane of glass: a translucent fill, a specular rim that catches the
/// light along its top-left edge, a soft sheen across the top and a hairline
/// so it holds its shape on a white page. With [frost] it also blurs what
/// is behind it (for layers over content: bars, sheets). No drop shadow:
/// depth comes from the rim and the translucency.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.radius = Radii.card,
    this.padding,
    this.frost = true,
    this.blur = Blurs.glass,
    this.tint,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool frost;
  final double blur;

  /// Overrides the fill.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget pane = DecoratedBox(
      decoration: glassFill(context, tint: tint),
      child: CustomPaint(
        foregroundPainter: GlassRimPainter.of(context, radius: radius),
        child:
            padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    if (frost) {
      pane = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: pane,
      );
    }
    return ClipRRect(borderRadius: shape, child: pane);
  }
}

/// The glass fill: the translucent tint with a sheen fading down from the
/// top edge.
BoxDecoration glassFill(BuildContext context, {Color? tint}) {
  final c = context.colors;
  final base = tint ?? c.glass;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        Color.alphaBlend(c.glassRim.withValues(alpha: Alphas.sheen), base),
        base,
      ],
    ),
  );
}

/// Draws the glass edge: a hairline for shape, then a 1px specular rim that
/// is bright at the top-left, fades across the middle and picks up again at
/// the bottom-right, the way light runs round a curved edge.
class GlassRimPainter extends CustomPainter {
  GlassRimPainter({
    required this.radius,
    required this.rim,
    required this.hairline,
  });

  factory GlassRimPainter.of(BuildContext context, {required double radius}) {
    final c = context.colors;
    return GlassRimPainter(
        radius: radius, rim: c.glassRim, hairline: c.hairline);
  }

  final double radius;
  final Color rim;
  final Color hairline;

  static const _stroke = Sizes.hairline;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(radius.clamp(0, size.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(rect.deflate(_stroke / 2), r);
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = hairline,
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              rim,
              rim.withValues(alpha: rim.a * Alphas.rimMid),
              rim.withValues(alpha: rim.a * Alphas.rimEnd),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(rect),
      );
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius || old.rim != rim || old.hairline != hairline;
}
