import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Four bars bouncing out of phase: "music is happening". Used while music
/// loads and as the now-playing mark. When [playing] is false the bars ease
/// down to a resting line instead of freezing mid-bounce.
class Equalizer extends StatefulWidget {
  const Equalizer({
    this.playing = true,
    this.size = Sizes.icon,
    this.color,
    super.key,
  });

  final bool playing;
  final double size;
  final Color? color;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with TickerProviderStateMixin {
  late final AnimationController _beat =
      AnimationController(vsync: this, duration: Motion.eqBeat);
  late final AnimationController _level = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: widget.playing ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Equalizer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.playing && !Motion.reduced(context);
    if (run) {
      if (!_beat.isAnimating) _beat.repeat();
      _level.forward();
    } else {
      _level.reverse().whenComplete(() {
        if (!widget.playing && mounted) _beat.stop();
      });
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.playing ? 'Playing' : null,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _EqualizerPainter(
            beat: _beat,
            level: _level,
            color: widget.color ?? context.colors.cue,
          ),
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({
    required this.beat,
    required this.level,
    required this.color,
  }) : super(repaint: Listenable.merge([beat, level]));

  final Animation<double> beat;
  final Animation<double> level;
  final Color color;

  static const _bars = 4;

  // Different speeds and phases per bar so the pattern never lines up.
  static const _speeds = [1.0, 1.6, 1.25, 2.1];
  static const _phases = [0.0, 1.3, 2.6, 0.7];

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / (_bars * 3 - 1);
    final w = gap * 2;
    final paint = Paint()..color = color;
    final a = beat.value * 2 * math.pi;
    final l = Motion.standard.transform(level.value);
    for (var i = 0; i < _bars; i++) {
      final wave = 0.5 + 0.5 * math.sin(a * _speeds[i] + _phases[i]);
      final h = size.height * (Alphas.eqRest + (1 - Alphas.eqRest) * wave * l);
      final x = i * (w + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, w, h),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) => old.color != color;
}
