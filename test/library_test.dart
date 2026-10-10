import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/features/library/presentation/alphabet_scrub.dart';
import 'package:unsung/features/library/presentation/library_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

void main() {
  testWidgets('lists songs and marks ready ones', (tester) async {
    await pumpScreen(tester, const LibraryScreen(),
        overrides: libraryOverrides());
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('8 SONGS · 3 READY'), findsOneWidget);
    expect(find.text('Start with a classic'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Paper Moons'), 200,
        scrollable: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down));
    expect(find.text('Paper Moons'), findsOneWidget);
    expect(find.text('READY'), findsWidgets);
  });

  testWidgets('filters to ready songs', (tester) async {
    await pumpScreen(tester, const LibraryScreen(),
        overrides: libraryOverrides());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ready'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kerosene Summer'), findsNothing);
    expect(find.text('Paper Moons'), findsOneWidget);
  });

  testWidgets('asks for access when music permission is missing',
      (tester) async {
    await pumpScreen(
      tester,
      const LibraryScreen(),
      overrides: libraryOverrides(access: Access.denied),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Let Unsung see your music'), findsOneWidget);
    expect(find.text('Allow music access'), findsOneWidget);
  });

  testWidgets('library survives 200% text scale', (tester) async {
    await pumpScreen(
      tester,
      const LibraryScreen(),
      overrides: libraryOverrides(),
      textScale: 2,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  test('scrub files titles under letters', () {
    expect(scrubLetter('paper Moons'), 'P');
    expect(scrubLetter('  Harbour'), 'H');
    expect(scrubLetter('99 Problems'), '#');
    expect(scrubLetter('Ébène'), '#');
    expect(scrubIndex(['Addis', 'Apple', 'Kerosene', 'Paper']),
        {'A': 0, 'K': 2, 'P': 3});
  });

  testWidgets('short libraries have no scrub rail', (tester) async {
    await pumpScreen(tester, const LibraryScreen(),
        overrides: libraryOverrides());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlphabetScrub), findsNothing);
  });

  testWidgets('scrubbing a long library jumps to the letter', (tester) async {
    await pumpScreen(
      tester,
      const LibraryScreen(),
      overrides: [
        ...libraryOverrides(),
        nativeAudioProvider.overrideWithValue(_LongLibrary()),
      ],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Wolf 1'), findsNothing);

    final rail = tester.getRect(find.byType(AlphabetScrub));
    // 'W' is slot 23 of 27 (# A … Z).
    await tester
        .tapAt(Offset(rail.center.dx, rail.top + rail.height * (23.5 / 27)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Wolf 1'), findsOneWidget);
  });
}

/// Ten songs per letter for A–Z, delivered shuffled.
class _LongLibrary extends FakeAudio {
  @override
  Future<List<Map<Object?, Object?>>> querySongs() async {
    final words = {
      'A': 'Amber', 'B': 'Blue', 'C': 'Coral', 'D': 'Dawn', 'E': 'Echo', //
      'F': 'Fern', 'G': 'Glass', 'H': 'Haze', 'I': 'Ivory', 'J': 'Jade',
      'K': 'Kite', 'L': 'Lark', 'M': 'Moss', 'N': 'Night', 'O': 'Opal',
      'P': 'Pine', 'Q': 'Quartz', 'R': 'Rain', 'S': 'Salt', 'T': 'Tide',
      'U': 'Umber', 'V': 'Velvet', 'W': 'Wolf', 'X': 'Xenon', 'Y': 'Yarrow',
      'Z': 'Zinc',
    };
    final all = [
      for (final w in words.values.toList().reversed)
        for (var i = 1; i <= 10; i++)
          {
            'id': '$w$i',
            'title': '$w $i',
            'artist': 'Demo',
            'uri': 'content://media/$w$i',
            'durationMs': 200000,
          },
    ];
    return all;
  }
}
