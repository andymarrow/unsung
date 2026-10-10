import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Bar waveform from normalised peaks (0..1). The played part is cue.
class Waveform extends StatelessWidget {
  const Waveform({
    required this.peaks,
    this.progress = 0,
    this.height = Sizes.waveformRow,
    this.onSeek,
    super.key,
  });

  final List<double> peaks;

  /// 0..1 played fraction.
  final double progress;
  final double height;

  /// Called with a 0..1 position when the user taps or drags.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final paint = RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: WaveformPainter(
          peaks: peaks,
          progress: progress,
          played: c.cue,
          unplayed: c.inkFaint,
        ),
      ),
    );
    final seek = onSeek;
    if (seek == null) return SizedBox(height: height, child: paint);
    return LayoutBuilder(
      builder: (context, box) {
        void at(Offset p) => seek((p.dx / box.maxWidth).clamp(0.0, 1.0));
        return Semantics(
          slider: true,
          label: 'Seek',
          value: '${(progress * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => at(d.localPosition),
            onHorizontalDragUpdate: (d) => at(d.localPosition),
            child: SizedBox(
              height: math.max(height, Sizes.tap),
              child: Center(child: SizedBox(height: height, child: paint)),
            ),
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  final List<double> peaks;
  final double progress;
  final Color played;
  final Color unplayed;

  static const _barWidth = 2.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0) return;
    final bars = (size.width / (_barWidth + _gap)).floor().clamp(1, 400);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;
    final mid = size.height / 2;
    for (var i = 0; i < bars; i++) {
      final t = i / bars;
      final peak = peaks[(t * peaks.length).floor().clamp(0, peaks.length - 1)];
      final h = math.max(_barWidth, peak.clamp(0.0, 1.0) * size.height);
      final x = i * (_barWidth + _gap) + _barWidth / 2;
      paint.color = t <= progress ? played : unplayed;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      !identical(old.peaks, peaks) ||
      old.played != played ||
      old.unplayed != unplayed;
}
