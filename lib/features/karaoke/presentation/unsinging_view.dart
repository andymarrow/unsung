import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Signature moment 1: "The Unsinging".
///
/// While a song is converted, its waveform splits in two behind the progress
/// head: the voice lifts off as a cue-coloured ribbon and dissolves upward,
/// and the band settles as solid bars. When [done] flips to true the last of
/// the ribbon floats away on the emphasized curve.
class UnsingingView extends StatefulWidget {
  const UnsingingView({
    required this.progress,
    required this.instrumentalPeaks,
    required this.vocalPeaks,
    this.done = false,
    this.height = Sizes.waveformHero,
    super.key,
  });

  final double progress;
  final List<double> instrumentalPeaks;
  final List<double> vocalPeaks;
  final bool done;
  final double height;

  @override
  State<UnsingingView> createState() => _UnsingingViewState();
}

class _UnsingingViewState extends State<UnsingingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: Motion.signature,
    value: widget.done ? 1 : 0,
  );

  @override
  void didUpdateWidget(UnsingingView old) {
    super.didUpdateWidget(old);
    if (!widget.done && old.done) {
      _settle.value = 0;
    } else if (widget.done && !old.done) {
      if (Motion.reduced(context)) {
        _settle.value = 1;
      } else {
        _settle.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: widget.done
          ? 'Vocals removed'
          : 'Removing vocals, ${(widget.progress * 100).round()} percent',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _settle,
          builder: (context, _) {
            final settle = Motion.emphasized.transform(_settle.value);
            return CustomPaint(
              size: Size(double.infinity, widget.height),
              painter: UnsingingPainter(
                progress: widget.done ? 1 : widget.progress,
                settle: settle,
                instrumental: widget.instrumentalPeaks,
                vocal: widget.vocalPeaks,
                // Bright while it's being worked on; settles to tape grey.
                band: Color.lerp(c.ink, c.inkMuted, settle.clamp(0, 1))!,
                ghost: c.raised,
                voice: c.cue,
              ),
            );
          },
        ),
      ),
    );
  }
}

class UnsingingPainter extends CustomPainter {
  UnsingingPainter({
    required this.progress,
    required this.settle,
    required this.instrumental,
    required this.vocal,
    required this.band,
    required this.ghost,
    required this.voice,
  });

  final double progress;
  final double settle;
  final List<double> instrumental;
  final List<double> vocal;
  final Color band;
  final Color ghost;
  final Color voice;

  static const _bar = 3.0;
  static const _gap = 2.0;

  static List<double> _normalised(List<double> v) {
    final top = v.fold<double>(0, math.max);
    return top <= 0 ? v : [for (final x in v) x / top];
  }

  double _at(List<double> v, double t) =>
      v.isEmpty ? 0 : v[(t * v.length).floor().clamp(0, v.length - 1)];

  @override
  void paint(Canvas canvas, Size size) {
    // The ribbon floats up and away; keep it inside our own box.
    canvas.clipRect(Offset.zero & size);
    final inst = _normalised(instrumental);
    final voc = _normalised(vocal);
    final count = (size.width / (_bar + _gap)).floor().clamp(1, 400);
    final baseline = size.height * 0.72;
    final bandMax = size.height * 0.42;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _bar;
    final ribbon = Path();
    var ribbonStarted = false;

    for (var i = 0; i < count; i++) {
      final t = i / count;
      final x = i * (_bar + _gap) + _bar / 2;
      if (t > progress) {
        // Not processed yet: a quiet ghost of what's coming.
        final h = 2 + 4 * (0.5 + 0.5 * math.sin(i * 0.7));
        paint.color = ghost;
        canvas.drawLine(Offset(x, baseline - h), Offset(x, baseline), paint);
        continue;
      }
      // Distance behind the head, 0 at the head and 1 at the very start.
      final age =
          progress <= 0 ? 0.0 : ((progress - t) / progress).clamp(0.0, 1.0);
      final bandH = math.max(_bar, _at(inst, t) * bandMax);
      // Fresh bars glow cue at the head and cool to the band colour; once
      // finished everything settles to the band colour.
      paint.color = Color.lerp(
        voice,
        band,
        math.max((age * 6).clamp(0.0, 1.0), settle),
      )!;
      canvas.drawLine(Offset(x, baseline - bandH), Offset(x, baseline), paint);

      // The voice ribbon rises with age and with the final settle.
      final lift = (age * 0.35 + settle) * size.height * 0.5;
      final vy = math.max(
        _bar,
        baseline - bandH - Space.xs - _at(voc, t) * size.height * 0.2 - lift,
      );
      if (!ribbonStarted) {
        ribbon.moveTo(x, vy);
        ribbonStarted = true;
      } else {
        ribbon.lineTo(x, vy);
      }
    }

    final fade = (1 - settle).clamp(0.0, 1.0);
    if (ribbonStarted && fade > 0) {
      final bounds = Rect.fromLTWH(0, 0, size.width * progress, size.height);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _bar
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            voice.withValues(alpha: 0),
            voice.withValues(alpha: fade),
          ],
        ).createShader(bounds);
      canvas.drawPath(ribbon, stroke);
    }

    // The progress head.
    if (progress > 0 && progress < 1) {
      final x = size.width * progress;
      canvas.drawLine(
        Offset(x, size.height * 0.08),
        Offset(x, baseline + Space.xs),
        Paint()
          ..color = voice
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(UnsingingPainter old) =>
      old.progress != progress ||
      old.settle != settle ||
      !identical(old.instrumental, instrumental) ||
      !identical(old.vocal, vocal) ||
      old.band != band ||
      old.voice != voice;
}
