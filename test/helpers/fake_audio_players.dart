import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

/// A player that only keeps state. Anything not used by the app throws.
class FakePlayer implements AudioPlayer {
  FakePlayer({this.failOpen = false});

  final bool failOpen;
  final calls = <String>[];
  final _states = StreamController<PlayerState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  @override
  double volume = 1;
  @override
  double pitch = 1;

  @override
  Future<Duration?> setFilePath(String filePath,
      {Duration? initialPosition, bool preload = true, Object? tag}) async {
    if (failOpen) throw Exception('cannot open');
    calls.add('open');
    return const Duration(minutes: 3);
  }

  @override
  Future<Duration?> setAudioSource(AudioSource source,
      {bool preload = true,
      int? initialIndex,
      Duration? initialPosition}) async {
    calls.add('source');
    return const Duration(minutes: 3);
  }

  @override
  Future<void> setPitch(double pitch) async => this.pitch = pitch;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    calls.add('seek ${position?.inMilliseconds}');
    this.position = position ?? Duration.zero;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
  }

  @override
  Stream<PlayerState> get playerStateStream => _states.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  void emitPosition(Duration p) {
    position = p;
    _positions.add(p);
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _positions.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A recorder whose PCM stream the test drives.
class FakeRecorder implements AudioRecorder {
  final pcm = StreamController<Uint8List>();
  bool stopped = false;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      pcm.stream;

  @override
  Future<String?> stop() async {
    stopped = true;
    return null;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
