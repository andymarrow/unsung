import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/theme/typography.dart';
import 'package:unsung/core/widgets/ambient_light.dart';

/// The launch sequence. It starts on the exact frame Android's splash shows
/// (the U over its cue underline, see res/drawable/launch_background.xml),
/// then plays the app's own story in under two seconds:
///
/// 1. the underline wakes up into a waveform (the song),
/// 2. the U breathes open and "nsung" opens beside it, letter by letter,
///    on the same variable-font width axis the lyrics use,
/// 3. the voice lifts out of the waveform as a cue ribbon and rises through
///    the word while the bars settle to tape grey (the Unsinging),
/// 4. the bars close back into one cue line under the whole word, the stage
///    light comes up, and the splash dissolves into the app.
///
/// Tap anywhere to skip. With reduce-motion it shows the finished lockup and
/// fades. It never waits on anything: the app is already built underneath.
class Splash extends StatefulWidget {
  const Splash({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late final AnimationController _story =
      AnimationController(vsync: this, duration: Motion.splash);
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: Motion.slow);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _story.value = 1;
      unawaited(Future<void>.delayed(Motion.slow, _leave));
    } else {
      unawaited(_story.forward().whenComplete(_leave));
      // A light tick as the waveform wakes.
      unawaited(Future<void>.delayed(
        Motion.splash * SplashBeats.wakeAt,
        HapticFeedback.lightImpact,
      ));
    }
  }

  Future<void> _leave() async {
    if (!mounted || _exit.isAnimating || _exit.isCompleted) return;
    await _exit.forward();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _story.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_leave()),
      child: Semantics(
        label: 'Unsung',
        child: AnimatedBuilder(
          animation: Listenable.merge([_story, _exit]),
          builder: (context, _) {
            final t = _story.value;
            final out = Motion.standard.transform(_exit.value);
            return Opacity(
              opacity: 1 - out,
              child: Transform.scale(
                scale: 1 + Motion.splashExitScale * out,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: c.stage),
                    // The stage light comes up as the word settles: the
                    // same light the app runs on, so the hand-off is seamless.
                    Opacity(
                      opacity: SplashBeats.light.transform(t),
                      child: const AmbientLight(),
                    ),
                    CustomPaint(
                      painter: SplashPainter(
                        t: t,
                        ink: c.ink,
                        cue: c.cue,
                        tape: c.inkMuted,
                        label: type.labelMuted,
                        scaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// When each part of the story happens, as fractions of [Motion.splash].
abstract final class SplashBeats {
  /// The underline starts to move.
  static const wakeAt = 0.08;

  static const wave = Interval(0.08, 0.36, curve: Motion.decelerate);
  static const grow = Interval(0.14, 0.62, curve: Motion.emphasized);
  static const openU = Interval(0.14, 0.52, curve: Motion.standard);
  static const letters = 0.24;
  static const letterStep = 0.055;
  static const letterSpan = 0.26;
  static const voice = Interval(0.40, 0.82, curve: Motion.decelerate);
  static const tape = Interval(0.42, 0.62, curve: Motion.standard);
  static const settle = Interval(0.64, 0.86, curve: Motion.emphasized);
  static const light = Interval(0.42, 0.95, curve: Motion.standard);
  static const tagline = Interval(0.74, 0.96, curve: Motion.decelerate);
}

/// Paints one frame of the splash at [t] (0..1). Public for the golden
/// filmstrip test.
class SplashPainter extends CustomPainter {
  SplashPainter({
    required this.t,
    required this.ink,
    required this.cue,
    required this.tape,
    required this.label,
    required this.scaler,
  });

  final double t;
  final Color ink;
  final Color cue;
  final Color tape;
  final TextStyle label;
  final TextScaler scaler;

  static const word = 'Unsung';
  static const tagline = 'SING THE SONGS YOU OWN';

  // Mark geometry in em of the glyph size, measured from the brand font
  // (wght 800, opsz 96) the same way tool/make_icons.py draws the icon.
  static const _capAbove = 0.660; // ink top above the baseline
  static const _inkBelow = 0.012; // overshoot below the baseline
  static const _gap = 0.0726; // glyph to underline
  static const _stripe = 0.121; // underline thickness
  static const _uWidth = 0.427; // U ink width at wdth 75
  static const _descender = 0.158; // the g's tail below the baseline

  /// Glyph size on the native splash: the 108dp adaptive foreground drawn at
  /// 288dp, with the mark at 0.62 of the canvas and the glyph 0.62 of that.
  static const nativeGlyph = 288 * 0.62 * 0.62;

  // Deterministic "song" so every launch draws the same waveform.
  static final _peaks = [
    for (var i = 0; i < SplashGeometry.bars; i++)
      0.35 + 0.65 * (0.5 + 0.5 * math.sin(i * 0.9) * math.cos(i * 0.37)).abs(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final grow = SplashBeats.grow.transform(t);
    final glyph = nativeGlyph + (SplashGeometry.wordmark - nativeGlyph) * grow;

    // Letters: U opens from 75 to 100; the rest open in one by one.
    final spans = <TextSpan>[];
    for (var i = 0; i < word.length; i++) {
      final double open;
      final double alpha;
      if (i == 0) {
        open = SplashBeats.openU.transform(t);
        alpha = 1;
      } else {
        final start = SplashBeats.letters + (i - 1) * SplashBeats.letterStep;
        final p = ((t - start) / SplashBeats.letterSpan).clamp(0.0, 1.0);
        open = Motion.emphasized.transform(p);
        alpha = Motion.standard.transform(p);
      }
      final width = 75 + 25 * open.clamp(0.0, 1.0);
      spans.add(TextSpan(
        text: word[i],
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: glyph,
          height: 1,
          color: ink.withValues(alpha: alpha.clamp(0.0, 1.0)),
          fontWeight: FontWeight.w800,
          fontVariations: Axes.display(
            weight: 800,
            width: width,
            opticalSize: 96,
          ),
        ),
      ));
    }
    final full = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling, // the logotype is a picture
    )..layout();
    final uOnly = TextPainter(
      text: spans.first,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    // Centre on what is visible: the U alone at first, the word at the end.
    final reveal = SplashBeats.grow.transform(t).clamp(0.0, 1.0);
    final visibleWidth = uOnly.width + (full.width - uOnly.width) * reveal;
    final left = centre.dx - visibleWidth / 2;

    // Vertical: the lockup (ink + gap + underline) centred, as on the icon.
    final lockup = (_capAbove + _inkBelow + _gap + _stripe) * glyph;
    final baseline = centre.dy - lockup / 2 + _capAbove * glyph;
    final textTop = baseline -
        full.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    // The underline: from the U's width out to the whole word.
    final underlineWidth =
        _uWidth * nativeGlyph * (1 - reveal) + full.width * reveal;
    final settle = SplashBeats.settle.transform(t);
    final thickness = _stripe * glyph * (1 - SplashGeometry.thinFinal * settle);
    // The U sits on the line; once the word arrives the line drops to clear
    // the g's tail.
    final below = _inkBelow + (_descender - _inkBelow) * reveal;
    final stripeTop = baseline + (below + _gap) * glyph;
    final stripe = Rect.fromLTWH(left + (visibleWidth - underlineWidth) / 2,
        stripeTop, underlineWidth, thickness);

    _paintVoice(canvas, stripe, textTop, glyph);
    full.paint(canvas, Offset(left, textTop));
    _paintWave(canvas, stripe, glyph);
    _paintTagline(canvas, centre, stripe);
  }

  /// The underline as a waveform hanging below it. Amplitude rises, holds,
  /// then closes back into a solid line; colour goes cue → tape → cue.
  void _paintWave(Canvas canvas, Rect stripe, double glyph) {
    final wave = SplashBeats.wave.transform(t);
    final settle = SplashBeats.settle.transform(t);
    final amp = (wave * (1 - settle)).clamp(0.0, 1.0);
    final toTape = SplashBeats.tape.transform(t) * (1 - settle);
    final color = Color.lerp(cue, tape, toTape.clamp(0.0, 1.0))!;
    final slot = stripe.width / SplashGeometry.bars;
    // Bars touch when still (one solid line) and part as they move.
    final barWidth = slot * (1 - SplashGeometry.barGap * amp);
    final paint = Paint()..color = color;
    final reach = glyph * SplashGeometry.waveReach;
    for (var i = 0; i < SplashGeometry.bars; i++) {
      final wobble =
          0.75 + 0.25 * math.sin(t * SplashGeometry.wobble + i * 1.3);
      final h = stripe.height + reach * amp * _peaks[i] * wobble;
      final x = stripe.left + i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, stripe.top, barWidth, h),
          Radius.circular(math.min(barWidth, stripe.height) / 2 * amp),
        ),
        paint,
      );
    }
  }

  /// The voice: a glowing cue line traced through the bar tips that lifts
  /// up through the word and fades, painted behind the letters.
  void _paintVoice(Canvas canvas, Rect stripe, double textTop, double glyph) {
    final v = SplashBeats.voice.transform(t);
    if (v <= 0 || v >= 1) return;
    // Lifts off the bars into the gap and up behind the base of the word,
    // fading before it reaches the middle of the letters.
    final rise = (stripe.bottom - textTop) * SplashGeometry.voiceRise * v;
    final fade = math.sin(v * math.pi);
    final reach = glyph * SplashGeometry.waveReach;
    final slot = stripe.width / SplashGeometry.bars;
    final path = Path();
    for (var i = 0; i < SplashGeometry.bars; i++) {
      final x = stripe.left + (i + 0.5) * slot;
      final y = stripe.top + reach * _peaks[(i + 3) % _peaks.length] - rise;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = stripe.left + (i - 0.5) * slot;
        final py = stripe.top + reach * _peaks[(i + 2) % _peaks.length] - rise;
        path.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
      }
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Sizes.strokeBold * 2
          ..color = cue.withValues(alpha: Alphas.glowStrong * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, Blurs.voice),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = Sizes.stroke
          ..strokeCap = StrokeCap.round
          ..color = cue.withValues(alpha: fade),
      );
  }

  void _paintTagline(Canvas canvas, Offset centre, Rect stripe) {
    final p = SplashBeats.tagline.transform(t);
    if (p <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: tagline,
        style: label.copyWith(
            color: label.color!.withValues(alpha: label.color!.a * p)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final y = stripe.bottom + Space.xl + Space.sm * (1 - p);
    tp.paint(canvas, Offset(centre.dx - tp.width / 2, y));
  }

  @override
  bool shouldRepaint(SplashPainter old) =>
      old.t != t || old.ink != ink || old.cue != cue || old.tape != tape;
}

/// Splash proportions.
abstract final class SplashGeometry {
  /// Final wordmark glyph size.
  static const double wordmark = 64;

  /// Bars across the underline.
  static const bars = 28;

  /// Gap between bars at full motion, as a fraction of a bar slot.
  static const double barGap = 0.45;

  /// How far bars hang below the line, in em of the glyph.
  static const double waveReach = 0.55;

  /// How much thinner the final underline is than the icon's.
  static const double thinFinal = 0.55;

  /// How far the voice rises, as a fraction of the word's height.
  static const double voiceRise = 0.75;

  /// Bar wobble speed (radians per unit of t).
  static const double wobble = 40;
}
