import 'package:freezed_annotation/freezed_annotation.dart';

part 'backfill_progress.freezed.dart';

/// Progress snapshot the `BackfillCoordinator` exposes to UI consumers
/// (Filters sheet header, list footer). Counts are post-eviction-friendly:
/// `total` decrements on a 404 so the ratio always renders correctly.
@freezed
abstract class BackfillProgress with _$BackfillProgress {
  /// Creates a [BackfillProgress].
  const factory BackfillProgress({
    /// Pokémon hydrated into `PokemonSummaries` so far.
    @Default(0) int hydrated,

    /// Total catalogue size after subtracting 404-evicted ids; null when
    /// the index hasn't loaded yet.
    int? total,

    /// `true` while a drain loop is actively running.
    @Default(false) bool isRunning,

    /// `true` after the session-level error budget has been exhausted; the
    /// drain will not retry until the next cold start.
    @Default(false) bool isHaltedThisSession,
  }) = _BackfillProgress;

  const BackfillProgress._();

  /// The pre-drain state — nothing hydrated, total unknown.
  factory BackfillProgress.idle() => const BackfillProgress();

  /// `true` when `hydrated == total` and `total` is non-null — the drain has
  /// fully caught up with the index.
  bool get isComplete => total != null && total! > 0 && hydrated >= total!;
}
