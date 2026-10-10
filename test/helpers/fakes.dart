import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/storage/app_files.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/links/data/link_repository.dart';
import 'package:unsung/features/links/data/link_sources.dart';
import 'package:unsung/features/links/domain/link.dart';

/// Invented demo catalogue (no real artists) for tests and screenshots.
const demoSongs = <(String, String, String, int)>[
  ('1', 'Paper Moons', 'The Lanterns', 214000),
  ('2', 'Kerosene Summer', 'Ada Vale', 187000),
  ('3', 'Slow Dance in the Kitchen', 'Marlow & Finch', 243000),
  ('4', 'Neon Psalm', 'Kidus', 201000),
  ('5', 'Harbour Lights', 'Sofia Ren', 226000),
  ('6', 'Gold Teeth, Silver Tongue', 'Velvet Static', 198000),
  ('7', 'Addis at 3am', 'Hanna Bekele', 255000),
  ('8', 'Little Earthquakes of the Heart', 'Ode to June', 212000),
];

List<Song> get demoSongList => [
      for (final s in demoSongs)
        Song(
          id: s.$1,
          title: s.$2,
          artist: s.$3,
          uri: 'content://media/${s.$1}',
          duration: Duration(milliseconds: s.$4),
        ),
    ];

List<double> demoPeaks(int seed, {int n = 160}) {
  final r = math.Random(seed);
  return [
    for (var i = 0; i < n; i++)
      (0.35 + 0.5 * math.sin(i / 9).abs() + 0.15 * r.nextDouble())
          .clamp(0.0, 1.0),
  ];
}

class FakeAudio extends NativeAudio {
  @override
  Stream<TaskProgress> get progress => const Stream.empty();

  @override
  Future<List<Map<Object?, Object?>>> querySongs() async => [
        for (final s in demoSongs)
          {
            'id': s.$1,
            'title': s.$2,
            'artist': s.$3,
            'uri': 'content://media/${s.$1}',
            'durationMs': s.$4,
          },
      ];

  @override
  Future<Uint8List?> artwork(String uri, {int size = 512}) async => null;
}

class FakePermissions extends Permissions {
  const FakePermissions(this.access);

  final Access access;

  @override
  Future<Access> music() async => access;

  @override
  Future<Access> microphone() async => access;
}

KaraokeTrack demoTrack(String songId) => KaraokeTrack(
      songId: songId,
      path: '/demo/$songId.m4a',
      duration: const Duration(minutes: 3),
      instrumentalPeaks: demoPeaks(1),
      vocalPeaks: demoPeaks(2),
      stereoRatio: 0.6,
      mode: SeparationMode.quick,
      createdAt: DateTime(2026, 10, 10),
    );

class FakeTracks extends KaraokeTracks {
  FakeTracks([this.ready = const ['1', '3', '7']]);

  final List<String> ready;

  @override
  Future<Map<String, KaraokeTrack>> build() async =>
      {for (final id in ready) id: demoTrack(id)};
}

List<Override> libraryOverrides({Access access = Access.granted}) => [
      nativeAudioProvider.overrideWithValue(FakeAudio()),
      permissionsProvider.overrideWithValue(FakePermissions(access)),
      appFilesProvider.overrideWithValue(
        AppFiles(Directory.systemTemp.createTempSync('unsung')),
      ),
      karaokeTracksProvider.overrideWith(FakeTracks.new),
    ];

/// A link source that answers instantly with an invented song.
class FakeLinkSource implements LinkSource {
  FakeLinkSource({this.fail});

  /// When set, downloads fail with this.
  final AppFailure? fail;
  int downloads = 0;

  @override
  Future<LinkPreview> resolve(String videoId) async => LinkPreview(
        videoId: videoId,
        title: 'Velvet Hours',
        artist: 'Ode to June',
        duration: const Duration(minutes: 3, seconds: 41),
      );

  @override
  Future<void> download(
    LinkPreview preview,
    File out, {
    required void Function(double? progress) onProgress,
    required bool Function() cancelled,
  }) async {
    downloads++;
    if (fail != null) throw fail!;
    onProgress(0.5);
    await out.writeAsBytes([1, 2, 3]);
    onProgress(1);
  }
}

List<Override> linkOverrides(LinkSource source) => [
      linkRepositoryProvider.overrideWith(
        (ref) => LinkRepository(
          AppFiles(Directory.systemTemp.createTempSync('unsung-links')),
          sources: [source],
          client: MockClient((_) async => http.Response('', 404)),
        ),
      ),
    ];
