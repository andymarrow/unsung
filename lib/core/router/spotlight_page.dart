import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Signature moment 3: "The Spotlight".
///
/// The studio opens as a circle of light expanding from the bottom centre
/// (where the record and Sing buttons live): first a flash of cue light,
/// then the studio is revealed through the growing circle.
CustomTransitionPage<void> spotlightPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Motion.spotlight,
    reverseTransitionDuration: Motion.slow,
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      // Emphasized: the circle overshoots past the screen edge and settles,
      // which reads as light swelling rather than a wipe.
      final reveal = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasized,
        reverseCurve: Motion.standard,
      );
      final flash = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Motion.standard),
      );
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final c = context.colors;
          // Flash rises then falls back as the page comes through.
          final glow = math.sin(flash.value * math.pi);
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: _CircleReveal(reveal.value),
                child: child,
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 0.2 + reveal.value * 1.3,
                      colors: [
                        c.cue.withValues(alpha: glow * Alphas.glowStrong),
                        c.cue.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hero flight between the Sing pill and the record disc: the cue shape
/// morphs (the rect is interpolated by the Hero; both ends are fully round)
/// while the mic fades out, so nothing pops when the Studio lands.
Widget spotlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final c = flightContext.colors;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.cue,
          borderRadius: BorderRadius.circular(Radii.full),
          boxShadow: [
            BoxShadow(
              color: c.cue.withValues(alpha: Alphas.glowStrong),
              blurRadius: Space.lg + Space.sm * t,
            ),
          ],
        ),
        child: Opacity(
          opacity: (1 - t * 2).clamp(0, 1),
          child: Icon(Icons.mic_rounded, color: c.onCue, size: Sizes.iconLg),
        ),
      );
    },
  );
}

class _CircleReveal extends CustomClipper<Path> {
  _CircleReveal(this.t);

  final double t;

  @override
  Path getClip(Size size) {
    final centre = Offset(size.width / 2, size.height - Sizes.navBar);
    final far = math.sqrt(
      math.pow(size.width / 2, 2) + math.pow(size.height, 2),
    );
    final radius = far * t + Sizes.recordButton / 2 * (1 - t);
    return Path()
      ..addOval(Rect.fromCircle(center: centre, radius: math.max(0, radius)));
  }

  @override
  bool shouldReclip(_CircleReveal old) => old.t != t;
}
