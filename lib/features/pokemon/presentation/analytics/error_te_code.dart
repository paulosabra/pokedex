import 'package:pokedex/core/error/failure.dart';

/// Maps a typed [Failure] to its PRD error code (`TE-xx`) for the
/// `error_shown` analytics event (plan §2.4 / §4.3).
///
/// The mapping is many-to-one: [NetworkFailure] and [CacheFailure] both surface
/// as **TE-01** (offline, no cache). The stale-cache **TE-02** case is *not*
/// derived here — it is a fixed, single-purpose banner site that passes its
/// code literally, because no [Failure] subtype uniquely identifies "offline
/// but still showing cached data" (TE-01 vs TE-02 is a UI-state distinction,
/// not a failure-type one).
///
/// Exhaustive over the sealed [Failure] hierarchy, so adding a new failure type
/// is a compile error here until its code is assigned — keeping analytics
/// honest as the error surface grows.
String teCodeFor(Failure failure) => switch (failure) {
  NetworkFailure() || CacheFailure() => 'TE-01',
  NotFoundFailure() => 'TE-03',
  TimeoutFailure() => 'TE-06',
  ServerFailure() => 'TE-07',
  RateLimitFailure() => 'TE-08',
  ParsingFailure() => 'TE-09',
};

/// As [teCodeFor], but tolerant of a non-[Failure] error (e.g. an
/// `AsyncError` carrying an arbitrary object). Unknown errors map to **TE-07**
/// — the generic "something went wrong" bucket the generic error widget shows.
String teCodeForError(Object? error) =>
    error is Failure ? teCodeFor(error) : 'TE-07';
