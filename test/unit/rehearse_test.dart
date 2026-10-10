import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/features/player/rehearse_controller.dart';

import '../helpers/fake_audio_players.dart';
import '../helpers/fakes.dart';

void main() {
  late FakePlayer music;
  late FakePlayer guide;
  late RehearseState state;
  late Rehearsal r;

  setUp(() async {
    music = FakePlayer();
    guide = FakePlayer();
    state = const RehearseState();
    r = Rehearsal(
      song: demoSongList.first,
      track: demoTrack('1'),
      onChange: (f) => state = f(state),
      music: music,
      guide: guide,
    );
    await r.open();
  });

  tearDown(() => r.dispose());

  test('opens ready with the guide silent', () {
    expect(state.ready, isTrue);
    expect(state.duration, const Duration(minutes: 3));
    expect(guide.volume, 0);
  });

  test('guide realigns only when it drifts past the tolerance', () async {
    await r.setGuide(0.5);
    music
      ..playing = true
      ..position = const Duration(seconds: 10);

    guide.position = const Duration(seconds: 10, milliseconds: 50);
    guide.calls.clear();
    await r.keepInSync();
    expect(guide.calls, isEmpty);

    guide.position = const Duration(seconds: 9, milliseconds: 700);
    await r.keepInSync();
    expect(guide.calls, ['seek 10000']);
  });

  test('a silent guide is left alone', () async {
    music
      ..playing = true
      ..position = const Duration(seconds: 10);
    guide.position = Duration.zero;
    guide.calls.clear();
    await r.keepInSync();
    expect(guide.calls, isEmpty);
  });

  test('fading the guide in from silence snaps it to the music', () async {
    music.position = const Duration(seconds: 42);
    guide.calls.clear();
    await r.setGuide(0.3);
    expect(state.guide, 0.3);
    expect(guide.calls, ['seek 42000']);
  });

  test('key change clamps to ±6 and moves both players', () async {
    await r.setKey(9);
    expect(state.semitones, Rehearsal.maxSemitones);
    expect(music.pitch, guide.pitch);
    expect(music.pitch, greaterThan(1));
  });

  test('play starts both in step; pause stops both', () async {
    music.position = const Duration(seconds: 5);
    await r.play();
    expect(guide.calls, contains('seek 5000'));
    expect(music.playing && guide.playing, isTrue);
    await r.pause();
    expect(music.playing || guide.playing, isFalse);
  });
}
