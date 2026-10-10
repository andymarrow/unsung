import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/storage/app_files.dart';
import 'package:unsung/features/studio/data/takes_repository.dart';
import 'package:unsung/features/studio/presentation/studio_session.dart';

import '../helpers/fake_audio_players.dart';
import '../helpers/fakes.dart';

class _Mic extends Permissions {
  _Mic(this.access);

  Access access;
  int requests = 0;

  @override
  Future<Access> microphone() async => access;

  @override
  Future<Access> requestMicrophone() async {
    requests++;
    return access;
  }
}

void main() {
  late Directory root;
  late FakePlayer music;
  late FakeRecorder recorder;

  setUp(() {
    root = Directory.systemTemp.createTempSync('unsung-studio');
    music = FakePlayer();
    recorder = FakeRecorder();
  });

  StudioSession session(Permissions p, {FakePlayer? player}) => StudioSession(
        song: demoSongList.first,
        track: demoTrack('1'),
        takes: TakesRepository(AppFiles(root), FakeAudio()),
        permissions: p,
        music: player ?? music,
        recorder: recorder,
      );

  test('prepare: mic granted → ready', () async {
    final s = session(_Mic(Access.granted));
    await s.prepare();
    expect(s.phase, StudioPhase.ready);
    expect(music.calls, contains('open'));
  });

  test('prepare: mic denied asks once, then waits; blocked points to settings',
      () async {
    final mic = _Mic(Access.denied);
    final s = session(mic);
    await s.prepare();
    expect(s.phase, StudioPhase.needsMic);
    expect(mic.requests, 1);
    expect(s.micBlocked, isFalse);

    mic.access = Access.blocked;
    await s.prepare();
    expect(s.micBlocked, isTrue);
  });

  test('prepare: an unreadable instrumental fails with a message', () async {
    final s = session(_Mic(Access.granted), player: FakePlayer(failOpen: true));
    await s.prepare();
    expect(s.phase, StudioPhase.failed);
    expect(s.failure, isNotNull);
  });

  test('count-in beats 3-2-1, records, and stop returns a synced take',
      () async {
    final s = session(_Mic(Access.granted));
    await s.prepare();
    final beats = <int>[];
    await s.countIn(Duration.zero, beats.add);
    expect(beats, [3, 2, 1]);
    expect(s.phase, StudioPhase.recording);

    // 0.5 s of silence-ish PCM; music starts with the first chunk.
    recorder.pcm.add(Uint8List(StudioSession.sampleRate));
    await Future<void>.delayed(Duration.zero);
    expect(music.playing, isTrue);
    music.emitPosition(const Duration(milliseconds: 100));
    await Future<void>.delayed(Duration.zero);

    final take = await s.stop();
    expect(s.phase, StudioPhase.saving);
    expect(recorder.stopped, isTrue);
    expect(take, isNotNull);
    expect(take!.songId, demoSongList.first.id);
    expect(take.duration, const Duration(milliseconds: 500));
    // 500 ms recorded − 100 ms music + 90 ms output latency.
    expect(take.settings.offsetMs, 490);
    expect(File(take.vocalPath).existsSync(), isTrue);
  });

  test('discard mid-take deletes the files and returns to ready', () async {
    final s = session(_Mic(Access.granted));
    await s.prepare();
    await s.countIn(Duration.zero, (_) {});
    recorder.pcm.add(Uint8List(4410));
    await Future<void>.delayed(Duration.zero);
    final folder = Directory(root.path)
        .listSync(recursive: true)
        .whereType<File>()
        .single
        .parent;

    await s.discard();
    expect(s.phase, StudioPhase.ready);
    expect(folder.existsSync(), isFalse);
    expect(music.calls.last, 'seek 0');
  });

  test('key change sets the pitch ratio', () async {
    final s = session(_Mic(Access.granted));
    await s.setKey(12);
    expect(music.pitch, closeTo(2, 1e-9));
    await s.setKey(-12);
    expect(music.pitch, closeTo(0.5, 1e-9));
  });
}
