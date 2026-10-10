import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/lyrics/data/lyrics_repository.dart';
import 'package:unsung/features/studio/domain/take.dart';

void main() {
  test('song from platform map', () {
    final s = Song.fromMap({
      'id': '7',
      'title': 'Blue',
      'artist': null,
      'uri': 'content://media/7',
      'durationMs': 187000,
    });
    expect(s.artistOrUnknown, 'Unknown artist');
    expect(formatDuration(s.duration), '3:07');
  });

  test('guesses artist from "Artist - Title" names', () {
    const s = Song(
      id: '1',
      title: 'Nina Simone - Feeling Good',
      uri: 'u',
      duration: Duration(minutes: 3),
    );
    expect(LyricsRepository.guessNames(s), ('Nina Simone', 'Feeling Good'));
  });

  test('karaoke track round-trips and flags near-mono mixes', () {
    final t = KaraokeTrack(
      songId: '1',
      path: '/x.m4a',
      duration: const Duration(seconds: 200),
      instrumentalPeaks: const [0.1, 1],
      vocalPeaks: const [0.5, 0.2],
      stereoRatio: 0.05,
      mode: SeparationMode.quick,
      createdAt: DateTime(2026, 10, 10),
    );
    final back = KaraokeTrack.fromJson(t.toJson());
    expect(back.instrumentalPeaks, [0.1, 1]);
    expect(back.mayLeakVocals, isTrue);
  });

  test('take round-trips with its mix settings', () {
    final t = Take(
      id: 'a',
      songId: '1',
      songTitle: 'Blue',
      createdAt: DateTime(2026, 10, 10),
      duration: const Duration(seconds: 90),
      vocalPath: '/v.wav',
      settings: const MixSettings(reverb: 0.4, offsetMs: 120, semitones: -2),
      inTune: 0.72,
    );
    final back = Take.fromJson(t.toJson());
    expect(back.settings, t.settings);
    expect(back.visibility, TakeVisibility.private);
    expect(back.inTune, 0.72);
  });
}
