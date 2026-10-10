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
      hero: display(56, 800, width: 78, height: 0.95, tracking: -0.02),
      title: display(32, 700, width: 85, height: 1.05, tracking: -0.01),
      heading: display(22, 650, width: 90),
      lyricActive: display(34, 750, width: 82, height: 1.1, tracking: -0.01),
      lyricNext: display(26, 600, width: 90),
      lyricPast: display(24, 600, width: 90, color: c.inkFaint),
      body: display(16, 420, height: 1.45),
      bodyMuted: display(16, 420, height: 1.45, color: c.inkMuted),
      rowTitle: display(17, 620, width: 92, height: 1.2),
      rowMeta: display(13, 420, height: 1.3, color: c.inkMuted),
      label: mono(11, 600, tracking: 0.12),
      labelMuted: mono(11, 600, tracking: 0.12, color: c.inkMuted),
      button: mono(13, 700, tracking: 0.1),
      numeral: mono(13, 500),
    );
  }

  final TextStyle hero;
  final TextStyle title;
  final TextStyle heading;
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

  /// Button labels: the label voice, one step bigger and bolder.
  final TextStyle button;
  final TextStyle numeral;

  @override
  UnsungType copyWith({
    TextStyle? hero,
    TextStyle? title,
    TextStyle? heading,
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
    TextStyle? numeral,
  }) {
    return UnsungType(
      hero: hero ?? this.hero,
      title: title ?? this.title,
      heading: heading ?? this.heading,
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
      numeral: TextStyle.lerp(numeral, other.numeral, t)!,
    );
  }
}
