import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/theme/app_theme.dart';

/// A 360x780 logical phone at 3x.
const phone = Size(1080, 2340);

Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  Size physicalSize = phone,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = physicalSize
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(instance), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
          ),
          child: inner!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

/// Pumps several frames so animations that start late (tickers take their
/// start time from the next frame) reach their end state before a golden.
Future<void> settleFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
