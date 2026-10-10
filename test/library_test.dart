import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/features/library/presentation/library_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

void main() {
  testWidgets('lists songs and marks ready ones', (tester) async {
    await pumpScreen(tester, const LibraryScreen(),
        overrides: libraryOverrides());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Paper Moons'), findsOneWidget);
    expect(find.text('READY'), findsWidgets);
    expect(find.textContaining('8 SONGS · 3 READY'), findsOneWidget);
  });

  testWidgets('filters to ready songs', (tester) async {
    await pumpScreen(tester, const LibraryScreen(),
        overrides: libraryOverrides());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.textContaining('READY  3'));
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
    expect(find.text('ALLOW MUSIC ACCESS'), findsOneWidget);
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
}
