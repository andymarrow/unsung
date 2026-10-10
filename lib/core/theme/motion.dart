import 'package:flutter/widgets.dart';

/// Motion tokens. Every animation in the app uses these.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);

  /// Reserved for signature moments.
  static const signature = Duration(milliseconds: 650);

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
