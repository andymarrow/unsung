import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Soft radial spotlight behind the one focal element of a screen.
/// The only "depth" effect used on dark surfaces.
class CueGlow extends StatelessWidget {
  const CueGlow({
    required this.child,
    this.intensity = Alphas.glow,
    this.alignment = Alignment.center,
    this.radius = 0.8,
    super.key,
  });

  final Widget child;
  final double intensity;
  final Alignment alignment;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius,
          colors: [
            c.cue.withValues(alpha: intensity),
            c.cue.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}
