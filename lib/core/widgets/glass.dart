import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// A pane of glass: tinted, frosted, with a rim of light along its edge and
/// a soft sheen across the top, the way light catches real glass.
///
/// [frost] turns on a real backdrop blur. It costs a render pass, so it is
/// for floating layers (tab bar, sheets, overlays). Cards that sit on the
/// ambient light set it to false: the light behind them is already soft, so
/// the tint, rim and sheen read as glass without the blur.
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

  /// Overrides the glass tint (e.g. a cue-tinted pane).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = BorderRadius.circular(radius);
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: tint ?? c.glass,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [c.glassSheen, c.glassSheen.withValues(alpha: 0)],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _RimPainter(radius: radius, light: c.glassEdge),
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

/// A hairline rim that is brightest at the top-left and fades around the
/// shape: the specular edge of a glass pane.
class _RimPainter extends CustomPainter {
  _RimPainter({required this.radius, required this.light});

  final double radius;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(Sizes.hairline / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Sizes.hairline
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          light,
          light.withValues(alpha: light.a * Alphas.rimMid),
          light.withValues(alpha: light.a * Alphas.rimFar),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.light != light;
}
