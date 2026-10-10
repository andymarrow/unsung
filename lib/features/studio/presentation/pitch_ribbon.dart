import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/features/studio/domain/pitch.dart';
import 'package:unsung/features/studio/presentation/studio_session.dart';

/// The live pitch ribbon: the last few seconds of your voice as a line over
/// faint note lanes. Segments centred on a note glow in `tune`; the head is a
/// cue dot with the note name beside it.
class PitchRibbon extends StatelessWidget {
  const PitchRibbon({required this.history, super.key});

  final PitchHistory history;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Live pitch',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: Sizes.pitchRibbon,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PitchRibbonPainter(
                      history: history,
                      lane: c.hairline,
                      line: c.ink,
                      tune: c.tune,
                      head: c.cue,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: ListenableBuilder(
                    listenable: history,
                    builder: (context, _) {
                      final m = history.latest;
                      return Text(
                        m == null ? '—' : noteName(m),
                        style: context.type.numeral.copyWith(
                          color: m != null &&
                                  centsOff(m).abs() <= SingingStats.tolerance
                              ? c.tune
                              : c.inkMuted,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PitchRibbonPainter extends CustomPainter {
  PitchRibbonPainter({
    required this.history,
    required this.lane,
    required this.line,
    required this.tune,
    required this.head,
  }) : super(repaint: history);

  final PitchHistory history;
  final Color lane;
  final Color line;
  final Color tune;
  final Color head;

  /// Visible range around the centre note.
  static const _span = 14.0;
  double _centre = 60;

  @override
  void paint(Canvas canvas, Size size) {
    // Follow the singer: centre on the median of recent voiced notes.
    final voiced = <double>[
      for (var i = 0; i < history.length; i++)
        if (!history.at(i).isNaN) history.at(i),
    ]..sort();
    if (voiced.isNotEmpty) _centre = voiced[voiced.length ~/ 2].roundToDouble();
    final low = _centre - _span / 2;
    double y(double midi) =>
        size.height - ((midi - low) / _span).clamp(0.0, 1.0) * size.height;

    final lanePaint = Paint()
      ..color = lane
      ..strokeWidth = 1;
    for (var n = low.ceil(); n <= low + _span; n++) {
      final yy = y(n.toDouble());
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), lanePaint);
    }

    final dx = size.width / (history.length - 1);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = Sizes.strokeBold;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = Sizes.strokeBold * 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = tune.withValues(alpha: Alphas.glowStrong);

    Offset? prev;
    var prevTuned = false;
    Offset? last;
    for (var i = 0; i < history.length; i++) {
      final m = history.at(i);
      if (m.isNaN) {
        prev = null;
        continue;
      }
      final p = Offset(i * dx, y(m));
      final tuned = centsOff(m).abs() <= SingingStats.tolerance;
      if (prev != null) {
        // Fade the oldest part of the ribbon.
        final age = 1 - i / history.length;
        final alpha = math.max(0.15, 1 - age * 0.85);
        final colour = (tuned && prevTuned) ? tune : line;
        if (tuned && prevTuned) canvas.drawLine(prev, p, glow);
        canvas.drawLine(
          prev,
          p,
          stroke..color = colour.withValues(alpha: alpha),
        );
      }
      prev = p;
      prevTuned = tuned;
      last = p;
    }

    if (last != null && !history.at(history.length - 1).isNaN) {
      canvas
        ..drawCircle(
          last,
          Sizes.strokeBold * 3,
          Paint()..color = head.withValues(alpha: Alphas.glow),
        )
        ..drawCircle(last, Sizes.strokeBold * 1.5, Paint()..color = head);
    }
  }

  @override
  bool shouldRepaint(PitchRibbonPainter old) =>
      old.history != history || old.line != line || old.tune != tune;
}
