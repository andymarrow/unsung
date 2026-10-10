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
    transitionDuration: Motion.signature,
    reverseTransitionDuration: Motion.slow,
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      final reveal = CurvedAnimation(
        parent: animation,
        curve: Motion.decelerate,
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

class _CircleReveal extends CustomClipper<Path> {
  _CircleReveal(this.t);

  final double t;

  @override
  Path getClip(Size size) {
    final centre = Offset(size.width / 2, size.height - Sizes.navBar);
    final far = math.sqrt(
      math.pow(size.width / 2, 2) + math.pow(size.height, 2),
    );
    return Path()
      ..addOval(Rect.fromCircle(
          center: centre, radius: far * t + Sizes.recordButton / 2 * (1 - t)));
  }

  @override
  bool shouldReclip(_CircleReveal old) => old.t != t;
}
