@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unsung/app.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/library/presentation/library_screen.dart';
import 'package:unsung/features/library/presentation/song_sheet.dart';
import 'package:unsung/features/links/presentation/link_sheet.dart';
import 'package:unsung/features/lyrics/data/lyrics_repository.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_slot.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/stage/presentation/stage_screen.dart';

import '../helpers/demo_social.dart';
import '../helpers/fakes.dart';
import '../helpers/fonts.dart';
import '../helpers/pump.dart';

/// Opens a sheet over the Library the way the app does, so the shot shows
/// the real sheet chrome: frosted glass, radius, handle and scrim.
Future<void> _overLibrary(
  WidgetTester tester,
  Future<void> Function(BuildContext) open, {
  Brightness brightness = Brightness.dark,
}) async {
  await pumpScreen(
    tester,
    const LibraryScreen(),
    brightness: brightness,
    overrides: [
      ...libraryOverrides(),
      ...linkOverrides(FakeLinkSource()),
    ],
  );
  await settleFrames(tester);
  unawaited(open(tester.element(find.byType(LibraryScreen))));
  await settleFrames(tester);
}

/// The whole app past onboarding: shell, ambient light, floating glass bar.
Future<void> _pumpApp(WidgetTester tester, Brightness brightness) async {
  SharedPreferences.setMockInitialValues({PrefKeys.onboarded: true});
  final prefs = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = phone
    ..devicePixelRatio = 3;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        ...libraryOverrides(),
        ...linkOverrides(FakeLinkSource()),
      ],
      child: const UnsungApp(splash: false),
    ),
  );
  await settleFrames(tester);
}

void main() {
  setUpAll(loadAppFonts);

  for (final b in Brightness.values) {
    testWidgets('app shell ${b.name}', (tester) async {
      await _pumpApp(tester, b);
      await expectLater(
          find.byType(UnsungApp), matchesGoldenFile('app_${b.name}.png'));
    });
  }

  for (final b in Brightness.values) {
    testWidgets('link sheet preview ${b.name}', (tester) async {
      await _overLibrary(tester, showLinkSheet, brightness: b);
      await tester.enterText(
          find.descendant(
              of: find.byType(LinkSheet), matching: find.byType(TextField)),
          'https://youtu.be/dQw4w9WgXcQ');
      FocusManager.instance.primaryFocus?.unfocus();
      await settleFrames(tester);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('link_sheet_${b.name}.png'));
    });
  }

  testWidgets('song sheet in its sheet', (tester) async {
    await _overLibrary(
      tester,
      (c) => showSongSheet(c, demoSongList.first),
    );
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('song_sheet_glass.png'));
  });

  testWidgets('stage feed screen', (tester) async {
    await pumpScreen(
      tester,
      const StageScreen(),
      overrides: [socialRepositoryProvider.overrideWithValue(FakeSocial())],
    );
    await settleFrames(tester);
    await expectLater(
        find.byType(StageScreen), matchesGoldenFile('stage_screen_dark.png'));
  });

  testWidgets('library without access offers a link', (tester) async {
    await pumpScreen(
      tester,
      const LibraryScreen(),
      overrides: libraryOverrides(access: Access.denied),
    );
    await settleFrames(tester);
    await expectLater(find.byType(LibraryScreen),
        matchesGoldenFile('library_needs_access.png'));
  });

  testWidgets('lyrics unavailable offline', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: SafeArea(
          child: LyricsSlot(
            song: demoSongList.first,
            position: () => Duration.zero,
          ),
        ),
      ),
      overrides: [
        ...libraryOverrides(),
        lyricsProvider
            .overrideWith((ref, song) async => throw const OfflineFailure()),
      ],
    );
    await settleFrames(tester);
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('lyrics_offline.png'));
  });
}
