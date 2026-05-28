import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/core/error/failure.dart';

part 'index_state.freezed.dart';

/// Lifecycle phase of the National-Dex index coordinator. The index drives
/// Search / Sort / Filters NumberRange / Generations across the entire
/// catalogue; downstream UI picks its rendering off the `status` value:
///
/// - **idle**: never loaded; sheets use `IndexFallbacks`.
/// - **loading**: fetch in flight (first or refresh); sheets show a hint
///   over `IndexFallbacks` until `ready` arrives.
/// - **ready**: fresh data live; sheets read `generationIds` / `minId` /
///   `maxId` directly.
/// - **stale**: cached but TTL-expired; sheets keep serving the cache while
///   a refresh runs in the background.
/// - **failed**: load attempt failed and there is no usable cache; sheets
///   degrade to `IndexFallbacks` and the coordinator exposes the failure.
enum IndexStatus {
  /// No data and no load attempted yet.
  idle,

  /// A first-load or refresh fetch is in flight.
  loading,

  /// Fresh data available; sheets render from the index directly.
  ready,

  /// Cache exists but is past `kPokemonIndexTtl`; the cache is still served
  /// while a refresh runs in the background.
  stale,

  /// The load attempt failed and there is no usable cache.
  failed,
}

/// Read model the index coordinator publishes. Empty defaults keep the type
/// safe to spread into a UI before any data lands.
@freezed
abstract class IndexState with _$IndexState {
  /// Creates an [IndexState].
  const factory IndexState({
    required IndexStatus status,
    int? minId,
    int? maxId,
    int? totalCount,
    @Default(<int>{}) Set<int> generationIds,

    /// Snapshot epoch milliseconds; null when no rows are cached.
    int? indexedAt,

    /// Most recent failure, when [status] is [IndexStatus.failed] or when a
    /// refresh attempt from [IndexStatus.stale] failed but the cache is
    /// still being served.
    Failure? lastError,
  }) = _IndexState;

  /// The pre-load state, before any cache or network read.
  factory IndexState.idle() => const IndexState(status: IndexStatus.idle);
}
