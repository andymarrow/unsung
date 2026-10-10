import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Signature moment 3: "The Spotlight".
///
/// The studio is revealed through a circle opening from the bottom centre,
/// where the Sing and record buttons live, while the button itself morphs
/// into the record disc (see [spotlightShuttle]). Shape only: no glow.
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
      final reveal = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasized,
        reverseCurve: Motion.standard,
      );
      return AnimatedBuilder(
        animation: reveal,
        child: child,
        builder: (context, child) => ClipPath(
          clipper: _CircleReveal(reveal.value),
          child: child,
        ),
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
