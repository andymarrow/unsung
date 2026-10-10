import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/karaoke/data/karaoke_repository.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/library/domain/song.dart';

/// Finished instrumentals by song id.
class KaraokeTracks extends AsyncNotifier<Map<String, KaraokeTrack>> {
  KaraokeRepository get _repo => ref.read(karaokeRepositoryProvider);

  @override
  Future<Map<String, KaraokeTrack>> build() => _repo.load();

  Future<void> add(KaraokeTrack track) async {
    final all = await future;
    await _repo.put(all, track);
    state = AsyncData({...all, track.songId: track});
  }

  Future<void> remove(String songId) async {
    final all = await future;
    await _repo.remove(all, songId);
    state = AsyncData({...all}..remove(songId));
  }
}

final karaokeTracksProvider =
    AsyncNotifierProvider<KaraokeTracks, Map<String, KaraokeTrack>>(
  KaraokeTracks.new,
);

final karaokeTrackProvider = Provider.family<KaraokeTrack?, String>(
  (ref, songId) => ref.watch(
    karaokeTracksProvider.select((v) => v.valueOrNull?[songId]),
  ),
);

/// Running and failed conversions by song id. Conversions keep going when
/// the sheet that started them is closed.
class KaraokeJobs extends Notifier<Map<String, KaraokeJob>> {
  @override
  Map<String, KaraokeJob> build() => const {};

  void _set(String id, KaraokeJob? job) {
    final next = {...state};
    if (job == null) {
      next.remove(id);
    } else {
      next[id] = job;
    }
    state = next;
  }

  Future<void> start(Song song, SeparationMode mode) async {
    if (state[song.id] is KaraokeRunning) return;
    _set(song.id, KaraokeRunning(mode));
    try {
      final track = await ref.read(karaokeRepositoryProvider).unsing(
        song,
        mode,
        onProgress: (p) {
          final current = state[song.id];
          if (current is! KaraokeRunning) return;
          _set(
            song.id,
            KaraokeRunning(
              mode,
              progress: p.progress,
              instrumentalPeaks:
                  p.instrumentalPeaks ?? current.instrumentalPeaks,
              vocalPeaks: p.vocalPeaks ?? current.vocalPeaks,
            ),
          );
        },
      );
      await ref.read(karaokeTracksProvider.notifier).add(track);
      _set(song.id, null);
    } on CancelledFailure {
      _set(song.id, null);
    } on Object catch (e) {
      _set(song.id, KaraokeFailed(mode, toFailure(e).message));
    }
  }

  Future<void> cancel(Song song) async {
    await ref.read(karaokeRepositoryProvider).cancel(song);
    _set(song.id, null);
  }

  void dismiss(String songId) => _set(songId, null);
}

final karaokeJobsProvider =
    NotifierProvider<KaraokeJobs, Map<String, KaraokeJob>>(KaraokeJobs.new);

final karaokeJobProvider = Provider.family<KaraokeJob?, String>(
  (ref, songId) => ref.watch(karaokeJobsProvider.select((m) => m[songId])),
);
