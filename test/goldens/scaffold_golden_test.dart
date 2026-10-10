@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/features/onboarding/onboarding_screen.dart';

import '../helpers/fonts.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final b in Brightness.values) {
    testWidgets('onboarding ${b.name}', (tester) async {
      await pumpScreen(tester, const OnboardingScreen(), brightness: b);
      await expectLater(
        find.byType(OnboardingScreen),
        matchesGoldenFile('onboarding_${b.name}.png'),
      );
    });
  }
}
