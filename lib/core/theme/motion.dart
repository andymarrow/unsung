import 'package:flutter/widgets.dart';

/// Motion tokens. Every animation in the app uses these.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);

  /// Reserved for signature moments.
  static const signature = Duration(milliseconds: 650);

  /// The visibility flip ripple (lock → broadcast).
  static const ripple = Duration(milliseconds: 280);

  /// Fraction of a turn the visibility mark spins as it flips.
  static const flipTurns = -0.12;

  /// The Spotlight reveal into the Studio (brief: 600ms, emphasized).
  static const spotlight = Duration(milliseconds: 600);

  /// Inactive tabs sit a hair smaller, so the incoming one settles in.
  static const tabScale = 0.985;

  /// One loop of the ambient stage light. Slow enough to feel still.
  static const ambient = Duration(seconds: 36);

  /// One full cycle of the equalizer bars.
  static const eqBeat = Duration(milliseconds: 1800);

  /// One sweep of the loading shimmer.
  static const shimmer = Duration(milliseconds: 1400);

  /// Rise distance for staggered list entrances.
  static const rise = 12.0;

  /// Peak scale of the like-button pop.
  static const popScale = 1.35;

  /// One loop of the onboarding Unsinging illustration.
  static const onboardingLoop = Duration(milliseconds: 4200);

  /// Wait after the last edit before re-rendering a preview mix.
  static const debounce = Duration(milliseconds: 500);

  /// How far content rises as it fades in, as a fraction of its height.
  static const riseFraction = 0.06;

  /// Per-item delay for staggered list entrances, and the cap.
  static const stagger = Duration(milliseconds: 30);
  static const staggerMaxItems = 8;

  /// Countdown beat before recording.
  static const beat = Duration(milliseconds: 800);

  /// Lyrics/pitch UI refresh interval when driven by a timer.
  static const tick = Duration(milliseconds: 33);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const emphasized = Cubic(0.34, 1.4, 0.64, 1);
  static const decelerate = Cubic(0, 0, 0, 1);

  /// Pressed scale for tappable surfaces.
  static const pressedScale = 0.96;

  /// Whether the user asked the system to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when reduce-motion is on.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Breathing-lyrics axes: the active word opens from closed to open as it
/// is sung (variable-font width and weight), ending on the brief's 750.
abstract final class Lyric {
  static const closedWidth = 82.0;
  static const openWidth = 100.0;
  static const closedWeight = 680.0;
  static const openWeight = 750.0;

  /// Gap between words, as a fraction of the font size.
  static const wordGap = 0.28;
}
