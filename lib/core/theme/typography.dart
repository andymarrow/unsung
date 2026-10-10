import 'package:flutter/material.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Font families bundled in assets/fonts (SIL OFL 1.1).
abstract final class Fonts {
  static const display = 'Bricolage';
  static const mono = 'JetBrainsMono';
}

/// Variable-font helpers. Bricolage Grotesque has wght 200–800,
/// wdth 75–100 and opsz 12–96 axes; JetBrains Mono has wght 100–800.
abstract final class Axes {
  static List<FontVariation> display({
    required double weight,
    double width = 100,
    double? opticalSize,
  }) {
    return [
      FontVariation('wght', weight),
      FontVariation('wdth', width),
      if (opticalSize != null) FontVariation('opsz', opticalSize),
    ];
  }

  static List<FontVariation> mono(double weight) => [
        FontVariation('wght', weight),
      ];

  static FontWeight nearestWeight(double w) {
    final index = ((w / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }
}

/// The type scale from the design brief.
@immutable
class UnsungType extends ThemeExtension<UnsungType> {
  const UnsungType({
    required this.hero,
    required this.title,
    required this.heading,
    required this.section,
    required this.lyricActive,
    required this.lyricNext,
    required this.lyricPast,
    required this.body,
    required this.bodyMuted,
    required this.rowTitle,
    required this.rowMeta,
    required this.label,
    required this.labelMuted,
    required this.button,
    required this.nav,
    required this.numeral,
  });

  factory UnsungType.from(UnsungColors c) {
    TextStyle display(
      double size,
      double weight, {
      double width = 100,
      double height = 1.15,
      double tracking = 0,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: Fonts.display,
        fontSize: size,
        height: height,
        letterSpacing: tracking * size,
        fontWeight: Axes.nearestWeight(weight),
        fontVariations: Axes.display(
          weight: weight,
          width: width,
          opticalSize: size.clamp(12, 96).toDouble(),
        ),
        color: color ?? c.ink,
      );
    }

    TextStyle mono(double size, double weight,
        {double tracking = 0, Color? color}) {
      return TextStyle(
        fontFamily: Fonts.mono,
        fontSize: size,
        height: 1.2,
        letterSpacing: tracking * size,
        fontWeight: Axes.nearestWeight(weight),
        fontVariations: Axes.mono(weight),
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? c.ink,
      );
    }

    return UnsungType(
      // Calmer than a poster: a touch of width contraction for character,
      // tight tracking, weights that stop short of black.
      hero: display(48, 760, width: 86, height: 1, tracking: -0.025),
      title: display(30, 700, width: 94, height: 1.1, tracking: -0.02),
      heading: display(20, 640, height: 1.2, tracking: -0.01),
      section: display(17, 640, height: 1.25, tracking: -0.005),
      lyricActive: display(34, 740, width: 82, height: 1.1, tracking: -0.015),
      lyricNext: display(26, 620, width: 92, tracking: -0.01),
      lyricPast: display(24, 600, width: 92, color: c.inkFaint),
      body: display(16, 420, height: 1.45),
      bodyMuted: display(16, 420, height: 1.45, color: c.inkMuted),
      rowTitle: display(16, 600, height: 1.25, tracking: -0.005),
      rowMeta: display(13.5, 430, height: 1.3, color: c.inkMuted),
      label: mono(10.5, 560, tracking: 0.08),
      labelMuted: mono(10.5, 560, tracking: 0.08, color: c.inkMuted),
      button: display(15, 640, height: 1.2),
      nav: display(11, 560, height: 1.2),
      numeral: mono(13, 500),
    );
  }

  final TextStyle hero;
  final TextStyle title;
  final TextStyle heading;

  /// Section titles inside a screen ("Start with a classic").
  final TextStyle section;
  final TextStyle lyricActive;
  final TextStyle lyricNext;
  final TextStyle lyricPast;
  final TextStyle body;
  final TextStyle bodyMuted;

  /// List row title and secondary line.
  final TextStyle rowTitle;
  final TextStyle rowMeta;

  /// Uppercase mono label. Callers pass upper-case strings.
  final TextStyle label;
  final TextStyle labelMuted;

  /// Button labels: sentence case in the display face.
  final TextStyle button;

  /// Tab bar labels: sentence case, sized to fit a fifth of the bar.
  final TextStyle nav;
  final TextStyle numeral;

  @override
  UnsungType copyWith({
    TextStyle? hero,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? section,
    TextStyle? lyricActive,
    TextStyle? lyricNext,
    TextStyle? lyricPast,
    TextStyle? body,
    TextStyle? bodyMuted,
    TextStyle? rowTitle,
    TextStyle? rowMeta,
    TextStyle? label,
    TextStyle? labelMuted,
    TextStyle? button,
    TextStyle? nav,
    TextStyle? numeral,
  }) {
    return UnsungType(
      hero: hero ?? this.hero,
      title: title ?? this.title,
      heading: heading ?? this.heading,
      section: section ?? this.section,
      lyricActive: lyricActive ?? this.lyricActive,
      lyricNext: lyricNext ?? this.lyricNext,
      lyricPast: lyricPast ?? this.lyricPast,
      body: body ?? this.body,
      bodyMuted: bodyMuted ?? this.bodyMuted,
      rowTitle: rowTitle ?? this.rowTitle,
      rowMeta: rowMeta ?? this.rowMeta,
      label: label ?? this.label,
      labelMuted: labelMuted ?? this.labelMuted,
      button: button ?? this.button,
      nav: nav ?? this.nav,
      numeral: numeral ?? this.numeral,
    );
  }

  @override
  UnsungType lerp(ThemeExtension<UnsungType>? other, double t) {
    if (other is! UnsungType) return this;
    return UnsungType(
      hero: TextStyle.lerp(hero, other.hero, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      section: TextStyle.lerp(section, other.section, t)!,
      lyricActive: TextStyle.lerp(lyricActive, other.lyricActive, t)!,
      lyricNext: TextStyle.lerp(lyricNext, other.lyricNext, t)!,
      lyricPast: TextStyle.lerp(lyricPast, other.lyricPast, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyMuted: TextStyle.lerp(bodyMuted, other.bodyMuted, t)!,
      rowTitle: TextStyle.lerp(rowTitle, other.rowTitle, t)!,
      rowMeta: TextStyle.lerp(rowMeta, other.rowMeta, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      labelMuted: TextStyle.lerp(labelMuted, other.labelMuted, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      nav: TextStyle.lerp(nav, other.nav, t)!,
      numeral: TextStyle.lerp(numeral, other.numeral, t)!,
    );
  }
}
