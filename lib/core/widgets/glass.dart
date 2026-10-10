import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// A surface pane: the glass tint with a hairline edge. With [frost] it
/// also blurs what is behind it (for layers over content: bars, sheets);
/// without, it is a calm card on the page. No sheen, no glow, no shadow:
/// depth comes from the tint step and the hairline alone.
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
    final c = context.colors;
    final shape = BorderRadius.circular(radius);
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: tint ?? (frost ? c.glass : c.surface),
        border: Border.all(color: c.hairline),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
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
