import 'dart:math';

import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/index_coordinator.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/index_fallbacks.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generation_sample.g.dart';

/// Stash for the random seed driving the Generations sheet's per-tile
/// sample. Stored in a sibling provider so the sheet's children only watch
/// the seed (not a Notifier with methods), and `reshuffle()` is fired
/// exactly once per sheet open from the parent's `initState`.
///
/// Per-second throttle blocks rapid re-opens (debug double-tap, animated
/// router back-pop) from re-rolling the trio.
@Riverpod(keepAlive: true)
class GenerationSampleSeed extends _$GenerationSampleSeed {
  DateTime? _lastReshuffle;

  @override
  int build() => DateTime.now().microsecondsSinceEpoch;

  /// Re-rolls the seed (and therefore every `generationSample`). Throttled
  /// to once per second.
  void reshuffle() {
    final now = DateTime.now();
    final last = _lastReshuffle;
    if (last != null && now.difference(last).inMilliseconds < 1000) return;
    _lastReshuffle = now;
    state = now.microsecondsSinceEpoch;
  }
}

/// Returns up to 3 random distinct National-Dex ids for [generationId] from
/// the live index, or the per-generation fallback when the index isn't
/// available. Reads off [generationSampleSeedProvider] so the seed lives
/// in a single place.
@riverpod
Future<List<int>> generationSample(Ref ref, int generationId) async {
  final seed = ref.watch(generationSampleSeedProvider);
  final index = await ref.watch(indexCoordinatorProvider.future);

  final members =
      index.status == IndexStatus.ready || index.status == IndexStatus.stale
      ? await ref
            .read(pokemonRepositoryProvider)
            .listGenerationMembers(generationId)
      : IndexFallbacks.starterTrios[generationId] ?? const <int>[];

  if (members.isEmpty) return const [];
  final rng = Random(seed ^ generationId);
  final picks = <int>[];
  final pool = [...members];
  final take = min(3, pool.length);
  for (var i = 0; i < take; i++) {
    final pick = pool.removeAt(rng.nextInt(pool.length));
    picks.add(pick);
  }
  return picks;
}
