@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/features/karaoke/presentation/unsinging_view.dart';

import '../helpers/fakes.dart';
import '../helpers/fonts.dart';
import '../helpers/pump.dart';

/// The Unsinging painter frame by frame: progress 0 / 50 / 100%, then the
/// settle halfway and done (brief, signature moment 1).
void main() {
  setUpAll(loadAppFonts);

  testWidgets('unsinging frames', (tester) async {
    final inst = demoPeaks(3).sublist(0, 99);
    final voc = demoPeaks(4).sublist(0, 99);
    const frames = [
      ('0%', 0.0, 0.0),
      ('50%', 0.5, 0.0),
      ('100%', 1.0, 0.0),
      ('SETTLE 50%', 1.0, 0.5),
      ('SETTLED', 1.0, 1.0),
    ];
    await pumpScreen(
      tester,
      Builder(
        builder: (context) {
          final c = context.colors;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (label, progress, settle) in frames) ...[
                      Text(label, style: context.type.labelMuted),
                      const SizedBox(height: Space.xs),
                      CustomPaint(
                        size:
                            const Size(double.infinity, Sizes.waveformCompact),
                        painter: UnsingingPainter(
                          progress: progress,
                          settle: settle,
                          instrumental: inst,
                          vocal: voc,
                          band: Color.lerp(c.ink, c.inkMuted, settle)!,
                          ghost: c.raised,
                          voice: c.cue,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    await settleFrames(tester, frames: 2);
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('unsinging_frames.png'));
  });
}
