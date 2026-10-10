import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/widgets/visibility_toggle.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/stage/presentation/stage_screen.dart';

import 'helpers/pump.dart';

void main() {
  test('post parses from a joined row', () {
    final p = Post.fromJson(const {
      'id': 'p',
      'author': {'id': 'u', 'handle': 'sam', 'display_name': '', 'bio': ''},
      'song_title': 'Blue',
      'artist': null,
      'caption': 'hi',
      'audio_path': 'u/p.m4a',
      'duration_ms': 1000,
      'peaks': [0.1, 0.2],
      'in_tune': 0.5,
      'visibility': 'public',
      'like_count': 3,
      'comment_count': 1,
      'created_at': '2026-10-10T10:00:00Z',
    }, likedByMe: true);
    expect(p.author.name, 'sam');
    expect(p.isPublic, isTrue);
    expect(p.likedByMe, isTrue);
    expect(p.copyWith(likeCount: 4).likeCount, 4);
  });

  test('initials and time ago', () {
    expect(
        const Profile(id: '1', handle: 'x', displayName: 'Hanna Bekele')
            .initials,
        'HB');
    final now = DateTime(2026, 10, 10, 12);
    expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min');
    expect(timeAgo(now.subtract(const Duration(hours: 2)), now: now), '2 h');
  });

  testWidgets('stage explains itself when no server is configured',
      (tester) async {
    await pumpScreen(tester, const StageScreen());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The Stage opens soon'), findsOneWidget);
  });

  testWidgets('visibility toggle flips between only me and everyone',
      (tester) async {
    var public = false;
    await pumpScreen(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: VisibilityToggle(
            public: public,
            onChanged: (v) => setState(() => public = v),
          ),
        ),
      ),
      textScale: 2,
    );
    expect(find.text('ONLY ME'), findsOneWidget);
    await tester.tap(find.byType(VisibilityToggle));
    await tester.pump(const Duration(milliseconds: 140));
    expect(public, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('EVERYONE'), findsOneWidget);
    expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
