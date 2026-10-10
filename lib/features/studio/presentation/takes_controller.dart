import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/features/studio/data/takes_repository.dart';
import 'package:unsung/features/studio/domain/take.dart';

/// All takes on this device, newest first.
class TakesController extends AsyncNotifier<List<Take>> {
  TakesRepository get _repo => ref.read(takesRepositoryProvider);

  @override
  Future<List<Take>> build() => _repo.load();

  Future<void> upsert(Take take) async {
    final all = await future;
    final next = [
      take,
      for (final t in all)
        if (t.id != take.id) t,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _repo.saveAll(next);
    state = AsyncData(next);
  }

  Future<void> delete(Take take) async {
    final all = await future;
    final next = [
      for (final t in all)
        if (t.id != take.id) t,
    ];
    await _repo.saveAll(next);
    await _repo.deleteFiles(take);
    state = AsyncData(next);
  }
}

final takesProvider =
    AsyncNotifierProvider<TakesController, List<Take>>(TakesController.new);

final takeByIdProvider = Provider.family<Take?, String>((ref, id) {
  for (final t in ref.watch(takesProvider).valueOrNull ?? const <Take>[]) {
    if (t.id == id) return t;
  }
  return null;
});
