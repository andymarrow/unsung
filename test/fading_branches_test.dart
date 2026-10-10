import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/widgets/fading_branches.dart';

void main() {
  Widget tabs(int index) => MaterialApp(
        home: FadingBranches(
          index: index,
          children: const [Text('Library tab'), Text('Takes tab')],
        ),
      );

  testWidgets('a tab you leave fades out and stops painting', (tester) async {
    await tester.pumpWidget(tabs(0));
    expect(find.text('Library tab'), findsOneWidget);
    expect(find.text('Takes tab'), findsNothing); // never shown: offstage

    await tester.pumpWidget(tabs(1));
    await tester.pumpAndSettle();
    // Offstage widgets are skipped by the default finder.
    expect(find.text('Takes tab'), findsOneWidget);
    expect(find.text('Library tab'), findsNothing);
    // ...but still alive, so scroll positions and state are kept.
    expect(find.text('Library tab', skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(tabs(0));
    await tester.pumpAndSettle();
    expect(find.text('Library tab'), findsOneWidget);
    expect(find.text('Takes tab'), findsNothing);
  });
}
