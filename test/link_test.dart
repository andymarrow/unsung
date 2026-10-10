import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';
import 'package:unsung/features/links/presentation/link_sheet.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

const _link = 'https://youtu.be/dQw4w9WgXcQ';

Future<ProviderContainer> _pumpSheet(
  WidgetTester tester,
  FakeLinkSource source, {
  double textScale = 1,
}) async {
  await pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: LinkSheet())),
    overrides: [...libraryOverrides(), ...linkOverrides(source)],
    textScale: textScale,
  );
  return ProviderScope.containerOf(tester.element(find.byType(LinkSheet)));
}

/// Imports write real files, which only complete outside the fake clock.
Future<void> _realIo(WidgetTester tester, Future<void> Function() act) async {
  await tester.runAsync(() async {
    await act();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('paste, preview, bring in: the song joins the library',
      (tester) async {
    final source = FakeLinkSource();
    final container = await _pumpSheet(tester, source);
    await container.read(libraryProvider.future);

    await tester.enterText(find.byType(TextField), _link);
    await tester.pumpAndSettle();
    expect(find.text('Velvet Hours'), findsOneWidget);
    expect(find.text('Ode to June'), findsOneWidget);
    expect(find.text('3:41'), findsOneWidget);

    await _realIo(tester, () => tester.tap(find.text('Bring it in')));
    expect(source.downloads, 1);
    expect(find.text('IN YOUR LIBRARY'), findsOneWidget);
    expect(find.text('Unsing it'), findsOneWidget);

    final song = container.read(songByIdProvider('yt-dQw4w9WgXcQ'));
    expect(song?.title, 'Velvet Hours');
    expect(song?.isImported, isTrue);
  });

  testWidgets('a link that is not YouTube says so', (tester) async {
    await _pumpSheet(tester, FakeLinkSource());
    await tester.enterText(find.byType(TextField), 'https://vimeo.com/1234');
    await tester.pumpAndSettle();
    expect(find.textContaining('isn’t a YouTube song link'), findsOneWidget);
  });

  testWidgets('a failed download offers a retry', (tester) async {
    final source =
        FakeLinkSource(fail: const LinkFailure('This video is private.'));
    await _pumpSheet(tester, source);
    await tester.enterText(find.byType(TextField), _link);
    await tester.pumpAndSettle();
    await _realIo(tester, () => tester.tap(find.text('Bring it in')));
    expect(find.text('This video is private.'), findsOneWidget);
    await _realIo(tester, () => tester.tap(find.text('Try again')));
    expect(source.downloads, 2);
  });

  testWidgets('link sheet survives 200% text scale', (tester) async {
    await _pumpSheet(tester, FakeLinkSource(), textScale: 2);
    await tester.enterText(find.byType(TextField), _link);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
