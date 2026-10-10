@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/presentation/library_screen.dart';
import 'package:unsung/features/library/presentation/song_sheet.dart';
import 'package:unsung/features/lyrics/domain/lyrics.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_view.dart';
import 'package:unsung/features/studio/domain/take.dart';
import 'package:unsung/features/studio/presentation/pitch_ribbon.dart';
import 'package:unsung/features/studio/presentation/studio_session.dart';
import 'package:unsung/features/studio/presentation/takes_controller.dart';
import 'package:unsung/features/takes/presentation/takes_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/fonts.dart';
import '../helpers/pump.dart';

// Invented lyrics for screenshots.
const _lrc = '''
[00:08.00]Under the paper moons we swore
[00:12.00]We'd never fold the night away
[00:16.50]But every lantern by the shore
[00:20.80]Was asking us to stay
[00:25.00]So stay, so stay
''';

class _RunningJobs extends KaraokeJobs {
  @override
  Map<String, KaraokeJob> build() => {
        '2': KaraokeRunning(
          SeparationMode.quick,
          progress: 0.62,
          instrumentalPeaks: demoPeaks(3).sublist(0, 99),
          vocalPeaks: demoPeaks(4).sublist(0, 99),
        ),
      };
}

class _Takes extends TakesController {
  @override
  Future<List<Take>> build() async => [
        Take(
          id: 'a',
          songId: '1',
          songTitle: 'Paper Moons',
          artist: 'The Lanterns',
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
          duration: const Duration(minutes: 3, seconds: 34),
          vocalPath: '/a.wav',
          mixPath: '/a.m4a',
          settings: const MixSettings(),
          peaks: demoPeaks(5),
          inTune: 0.78,
          presence: 0.6,
          visibility: TakeVisibility.public,
        ),
        Take(
          id: 'b',
          songId: '7',
          songTitle: 'Addis at 3am',
          artist: 'Hanna Bekele',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          duration: const Duration(minutes: 4, seconds: 15),
          vocalPath: '/b.wav',
          settings: const MixSettings(),
          peaks: demoPeaks(6),
          inTune: 0.64,
          presence: 0.7,
        ),
      ];
}

void main() {
  setUpAll(loadAppFonts);

  for (final b in Brightness.values) {
    testWidgets('library ${b.name}', (tester) async {
      await pumpScreen(tester, const LibraryScreen(),
          brightness: b, overrides: libraryOverrides());
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(LibraryScreen),
          matchesGoldenFile('library_${b.name}.png'));
    });
  }

  testWidgets('song sheet unsinging', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(body: SafeArea(child: SongSheet(song: demoSongList[1]))),
      overrides: [
        ...libraryOverrides(),
        karaokeJobsProvider.overrideWith(_RunningJobs.new),
      ],
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('song_sheet_unsinging.png'));
  });

  testWidgets('song sheet ready', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(body: SafeArea(child: SongSheet(song: demoSongList[0]))),
      overrides: libraryOverrides(),
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('song_sheet_ready.png'));
  });

  for (final b in Brightness.values) {
    testWidgets('studio surface ${b.name}', (tester) async {
      final history = PitchHistory();
      for (var i = 0; i < history.length; i++) {
        final t = i / history.length;
        history
            .push(i % 37 < 4 ? null : 57 + 3 * t + (i % 23 < 12 ? 0.05 : 0.4));
      }
      final lyrics =
          Lyrics.parse(_lrc, songDuration: const Duration(seconds: 30));
      await pumpScreen(
        tester,
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LyricsView(
                    lyrics: lyrics,
                    position: () => const Duration(milliseconds: 14200),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.gutter),
                  child: PitchRibbon(history: history),
                ),
              ],
            ),
          ),
        ),
        brightness: b,
      );
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('studio_surface_${b.name}.png'));
    });
  }

  testWidgets('takes', (tester) async {
    await pumpScreen(
      tester,
      const TakesScreen(),
      overrides: [takesProvider.overrideWith(_Takes.new)],
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
        find.byType(TakesScreen), matchesGoldenFile('takes_dark.png'));
  });
}
