import 'package:flutter/material.dart';

/// Colour tokens from docs/design-brief.md. Widgets read these through
/// `context.colors`; no widget hardcodes a colour.
@immutable
class UnsungColors extends ThemeExtension<UnsungColors> {
  const UnsungColors({
    required this.stage,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.cue,
    required this.onCue,
    required this.tune,
    required this.hairline,
    required this.scrim,
    required this.glass,
    required this.glassSheen,
    required this.glassRim,
    required this.ambient,
  });

  // Neutral graphite: no warm cast, so the cue is the only colour on screen.
  static const dark = UnsungColors(
    stage: Color(0xFF0D0D0E),
    surface: Color(0xFF17171A),
    raised: Color(0xFF222226),
    ink: Color(0xFFF2F2F0),
    inkMuted: Color(0xFF9D9DA3),
    inkFaint: Color(0xFF64646A),
    cue: Color(0xFFFF5B24),
    onCue: Color(0xFF0D0D0E),
    tune: Color(0xFF5BF0A0),
    hairline: Color(0x17F2F2F0),
    scrim: Color(0xB30D0D0E),
    glass: Color(0xB81C1C20),
    glassSheen: Color(0x12FFFFFF),
    glassRim: Color(0x40FFFFFF),
    ambient: Color(0xFF1D1D21),
  );

  static const light = UnsungColors(
    stage: Color(0xFFF6F5F3),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEDECE9),
    ink: Color(0xFF141415),
    inkMuted: Color(0xFF66666C),
    inkFaint: Color(0xFF85858B),
    cue: Color(0xFFC2410C),
    onCue: Color(0xFFFFFFFF),
    tune: Color(0xFF0E8A4F),
    hairline: Color(0x14141415),
    scrim: Color(0x99141415),
    glass: Color(0x9EFFFFFF),
    glassSheen: Color(0x66FFFFFF),
    glassRim: Color(0xF2FFFFFF),
    ambient: Color(0xFFDCDBD7),
  );

  /// Page background.
  final Color stage;

  /// Cards and rows.
  final Color surface;

  /// Chips, inputs, pressed states.
  final Color raised;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color inkMuted;

  /// Sung lyrics, disabled. Large text only.
  final Color inkFaint;

  /// The one accent: the spotlight.
  final Color cue;

  /// Text and icons on [cue].
  final Color onCue;

  /// "On pitch" signal inside the pitch ribbon only.
  final Color tune;

  /// 1px dividers.
  final Color hairline;

  /// Behind sheets and dialogs.
  final Color scrim;

  /// Translucent fill of frosted layers (tab bar, sheets).
  final Color glass;

  /// The light band in loading shimmers.
  final Color glassSheen;

  /// The specular edge of glass: bright where light catches the rim.
  final Color glassRim;

  /// Neutral shading in the backdrop, so glass has something to show.
  final Color ambient;

  @override
  UnsungColors copyWith({
    Color? stage,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? cue,
    Color? onCue,
    Color? tune,
    Color? hairline,
    Color? scrim,
    Color? glass,
    Color? glassSheen,
    Color? glassRim,
    Color? ambient,
  }) {
    return UnsungColors(
      stage: stage ?? this.stage,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      cue: cue ?? this.cue,
      onCue: onCue ?? this.onCue,
      tune: tune ?? this.tune,
      hairline: hairline ?? this.hairline,
      scrim: scrim ?? this.scrim,
      glass: glass ?? this.glass,
      glassSheen: glassSheen ?? this.glassSheen,
      glassRim: glassRim ?? this.glassRim,
      ambient: ambient ?? this.ambient,
    );
  }

  @override
  UnsungColors lerp(ThemeExtension<UnsungColors>? other, double t) {
    if (other is! UnsungColors) return this;
    return UnsungColors(
      stage: Color.lerp(stage, other.stage, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      cue: Color.lerp(cue, other.cue, t)!,
      onCue: Color.lerp(onCue, other.onCue, t)!,
      tune: Color.lerp(tune, other.tune, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassSheen: Color.lerp(glassSheen, other.glassSheen, t)!,
      glassRim: Color.lerp(glassRim, other.glassRim, t)!,
      ambient: Color.lerp(ambient, other.ambient, t)!,
    );
  }
}

/// Spacing scale. Use these instead of literal paddings.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Horizontal page gutter.
  static const double gutter = 20;

  /// Tape label insets.
  static const double tapeX = 6;
  static const double tapeY = 3;
}

/// Corner radii.
abstract final class Radii {
  /// Square-ish tape labels (metadata tags).
  static const double tape = 3;
  static const double chip = 6;

  /// Row artwork and thumbnails.
  static const double art = 12;
  static const double card = 20;
  static const double sheet = 28;
  static const double full = 999;
}

/// Fixed sizes that recur across components.
abstract final class Sizes {
  /// Minimum tap target.
  static const double tap = 48;
  static const double chip = 36;

  /// Search field and other single-line inputs.
  static const double field = 48;

  /// Header icon buttons (link, back, more).
  static const double iconButton = 44;
  static const double sliderLabel = 104;
  static const double button = 52;
  static const double artworkRow = 56;
  static const double artworkHero = 220;
  static const double artworkSheet = 112;
  static const double avatarSm = 32;
  static const double avatarLg = 88;
  static const double recordButton = 64;

  /// The Sing button in the tab bar: a round cue key.
  static const double singButton = 52;
  static const double recordButtonLarge = 84;
  static const double navBar = 68;
  static const double hairline = 1;
  static const double iconLg = 26;
  static const double icon = 22;
  static const double iconMd = 18;
  static const double iconSm = 16;
  static const double iconXs = 12;
  static const double stroke = 2;
  static const double strokeBold = 3;
  static const double waveformRow = 28;
  static const double waveformHero = 120;
  static const double waveformCompact = 72;
  static const double pitchRibbon = 140;
  static const double maxContentWidth = 560;

  /// Link preview thumbnail; video frames are 16:9.
  static const double linkThumb = 78;
  static const double videoAspect = 16 / 9;

  /// Indeterminate progress segment, as a fraction of the track.
  static const double progressSegment = 0.3;

  /// Alphabet scrub rail width (fits inside the page gutter) and the
  /// letter bubble shown while scrubbing.
  static const double scrubRail = 20;
  static const double scrubBubble = 56;

  /// Narrowest a profile stat may be before the row goes 2 x 2
  /// ("FOLLOWERS" in the mono label plus breathing room), at 1x text.
  static const double statMin = 84;

  /// Placeholder for a post card while more of the feed loads.
  static const double postSkeleton = 168;

  /// Waveform bars.
  static const double waveBar = 2;
  static const double waveGap = 2;

  /// Starter shelf cards (16:9 thumbnail).
  static const double shelfCard = 220;

  /// Room for a shelf card's two text lines and padding, at 1x text.
  static const double shelfText = 68;

  /// The visibility switch.
  static const double switchWidth = 48;
  static const double switchHeight = 28;
  static const double switchThumb = 18;
}

/// Blur strengths.
abstract final class Blurs {
  /// Frosted glass on sheets and floating bars.
  static const double glass = 24;

  /// Lighter frost for the tab bar, so content stays readable through it.
  static const double bar = 18;
}

/// Opacities used for glows and overlays.
abstract final class Alphas {
  static const double glow = 0.24;
  static const double glowStrong = 0.42;
  static const double disabled = 0.38;
  static const double glass = 0.72;
  static const double ghost = 0.08;

  /// Glass: the sheen at the top of a pane, and how much of the rim's
  /// light is left across the middle and at the far corner.
  static const double sheen = 0.5;
  static const double rimMid = 0.15;
  static const double rimEnd = 0.55;

  /// Film grain over the stage: present, never noticed.
  static const double grainDark = 0.05;
  static const double grainLight = 0.035;

  /// Resting height of an equalizer bar, as a fraction of its box.
  static const double eqRest = 0.18;
}

/// The stage's film grain.
abstract final class Grain {
  /// Size of the repeating tile, and specks per tile.
  static const double tile = 96;
  static const specks = 900;

  /// Speck diameter.
  static const double speck = 1;
}
