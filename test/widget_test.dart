import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/features/onboarding/onboarding_screen.dart';

import 'helpers/pump.dart';

void main() {
  testWidgets('onboarding walks through three beats', (tester) async {
    await pumpScreen(tester, const OnboardingScreen());
    expect(find.textContaining('karaoke track'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('every take'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text("LET'S SING"), findsOneWidget);
  });

  testWidgets('onboarding survives 200% text scale without overflow',
      (tester) async {
    await pumpScreen(tester, const OnboardingScreen(), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  test('both themes expose the token extensions', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      expect(theme.extension<UnsungColors>(), isNotNull);
    }
  });
}
