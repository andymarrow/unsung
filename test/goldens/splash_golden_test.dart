@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/widgets/ambient_light.dart';
import 'package:unsung/features/splash/splash.dart';

import '../helpers/fonts.dart';
import '../helpers/pump.dart';

/// The splash as a filmstrip: each frame is the full phone screen at one
/// moment of the story, side by side.
void main() {
  setUpAll(loadAppFonts);

  const moments = [0.0, 0.18, 0.32, 0.48, 0.62, 0.78, 1.0];

  testWidgets('splash filmstrip', (tester) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) {
          final c = context.colors;
          return ColoredBox(
            color: c.stage,
            child: Row(
              children: [
                for (final t in moments)
                  Expanded(
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
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
                              label: context.type.labelMuted,
                              scaler: TextScaler.noScaling,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      physicalSize: Size(1080.0 * moments.length, 2340),
    );
    await settleFrames(tester, frames: 2);
    await expectLater(
        find.byType(Row).first, matchesGoldenFile('splash_filmstrip.png'));
  });

  testWidgets('splash plays, can be skipped, and hands over', (tester) async {
    var done = false;
    await pumpScreen(tester, Splash(onDone: () => done = true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(done, isFalse);
    await tester.tap(find.byType(Splash));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });
}
