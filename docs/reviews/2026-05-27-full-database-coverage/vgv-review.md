# VGV Code Review — Full Database Coverage

**Branch:** `feature/presentation-part4` (uncommitted)
**Plan:** `docs/plan/2026-05-27-feat-full-database-coverage-plan.md`
**Reviewer:** VGV review agent
**Date:** 2026-05-27

## Summary

This is a substantial and well-engineered slice. The architectural decisions (separate `PokemonIndex` table, two-coordinator split, named `IndexFallbacks`) match the plan and the rationale in the source comments is exemplary — easily the strongest aspect of the change. The data and domain layers are clean, the migration is genuinely additive, and the DAO/repository tests are thorough and behaviour-focused.

**Verdict: Needs work before merge.** The diff has one regression that breaks existing tests (the GenerationsSheet `Clear` button was removed without updating the two tests that assert it), the new skeleton card has zero widget-test coverage despite being explicitly called out in the plan's Quality Gates, and there's a small but real logic bug in `IndexCoordinator._runFetch` that can demote a `ready` cache to `stale` when a forced refresh hits an offline device. The three new use-case files (`refresh_index`, `list_generations`, `get_catalogue_bounds`) are wired with Riverpod providers but never consumed by any caller — pure dead code as currently shipped.

The architecture and conventions are otherwise on-pattern; once the critical items are addressed, this is mergeable.

---

## Critical — Must Fix Before Merge

### C1 — `GenerationsSheet` Clear button removed, two tests still assert it
**Files:** `lib/features/pokemon/presentation/widgets/sheets/generations_sheet.dart`, `test/features/pokemon/presentation/widgets/sheets/generations_sheet_test.dart:101-122`

The diff removes the `titleTrailing: hasActive ? TextButton('Clear', …) : null` block from `GenerationsSheet`, but two existing tests still assert it:

- `Clear pops with a null value even when a generation is active` (taps `find.text('Clear')`)
- `Clear button is hidden when no generation is active` (asserts `find.text('Clear'), findsNothing`)

The first test will fail (no `Clear` widget exists); the second test now passes for the wrong reason (Clear is always absent now). Beyond the broken tests, this is also a **lost feature** — UC-05 explicitly supports an explicit clear gesture (the plan never asked for it to be removed; the only clearing path now is "tap the active tile again," which is less discoverable).

**Fix:** Either (a) restore the `titleTrailing` Clear button (preferred — matches Figma + UC-05) and keep the tests, or (b) delete the two tests and document that tap-to-toggle is the only clear gesture. Pick one, but not silently.

### C2 — `_SkeletonPokemonCard` ships with zero widget tests
**Files:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart:61-174`, plan §"Quality Gates"

The plan explicitly requires: "Widget test for `_SkeletonPokemonCard` rendering + tap-to-hydrate." Neither exists. `test/features/pokemon/presentation/widgets/pokemon_card_test.dart` is unmodified in this diff — there is no test that:

1. The adapter routes to `_SkeletonPokemonCard` when `pokemon.types.isEmpty`.
2. The skeleton renders `#$id` padded, the capitalized name, and shimmer chips.
3. Tapping a skeleton invokes `context.go('/pokemon/$id')`.
4. The image falls back to the broken-image icon on a 404 (this is the alt-form case explicitly called out in `officialArtworkUrl`'s docstring).

This is the most user-visible new widget in the slice and the plan's #1 listed test gate. Add the tests.

### C3 — `IndexCoordinator.refresh()` demotes `ready` to `stale` on offline refresh
**File:** `lib/features/pokemon/presentation/coordinators/index_coordinator.dart:82-103`

`refresh()` can be called from `IndexStatus.ready` (force = true). If the device is offline at that moment, `_runFetch` falls into the `previous.status == ready` branch (line 87) and emits `previous.copyWith(status: IndexStatus.stale, lastError: NetworkFailure())`. That is wrong: the cached data is still within its 30-day TTL — it is *fresh*, just not *re-refreshed*. The state machine's own contract (`index_state.dart:29-31`) says stale = "Cache exists but is past `kPokemonIndexTtl`," which is not the case here.

This will manifest as: a user pulls to refresh while offline, and the Filters sheet header copy / NumberRange slider could shift behaviour purely because the user pulled-to-refresh while disconnected.

**Fix:** when `previous.status == IndexStatus.ready`, the offline branch should leave status at `ready` (only set `lastError`). Only demote `stale → stale` (i.e. keep stale) and `idle/failed → failed`.

```dart
// Sketch
if (previous.status == IndexStatus.ready) {
  state = AsyncData(previous.copyWith(lastError: const NetworkFailure()));
  return;
}
if (previous.status == IndexStatus.stale) {
  state = AsyncData(previous.copyWith(lastError: const NetworkFailure()));
  return;
}
state = AsyncData(previous.copyWith(
  status: IndexStatus.failed,
  lastError: const NetworkFailure(),
));
```

Add a test: `refresh + offline + ready → status stays ready, lastError set`.

### C4 — Three new use-case files are dead code
**Files:** `lib/features/pokemon/domain/usecases/refresh_index.dart`, `list_generations.dart`, `get_catalogue_bounds.dart` (+ `.g.dart` siblings)

```
$ grep -rn "refreshIndexProvider\|listGenerationsProvider\|getCatalogueBoundsProvider" lib/
(no results)
```

None of the three use cases is consumed anywhere in `lib/`. The presentation layer reads `pokemonRepositoryProvider` directly (via the coordinators) and `indexCoordinatorProvider`'s state. These files add codegen output, test files, and surface area without earning their keep.

This is a direct YAGNI violation. Either:
- **Delete all three** (and their tests) — the coordinators already do the work. This is the simpler path and removes ~6 files including codegen.
- **Wire them**: route `IndexCoordinator.refresh()`'s repository call through `RefreshIndexProvider`; route the Generations sheet's id list through `ListGenerationsProvider`; route the Filters NumberRange bounds through `GetCatalogueBoundsProvider`. This would honour the architecture per the plan diagram (presentation → domain → data) and remove the layer violations noted in I3 below.

Either is acceptable; **shipping them unused is not**. Pick before merge.

---

## Important — Should Fix

### I1 — Pre-existing broken test left in place: `Clear pops` in FiltersSheet
**File:** `test/features/pokemon/presentation/widgets/sheets/filters_sheet_test.dart:203-220`

The FiltersSheet's button has been labeled `Reset` since commit `26e6286` (the previous commit on this branch). The test still does `await tester.tap(find.text('Clear'))` and so will fail. The PR docstring at lines 37-40 explicitly mentions "Reset / Apply" — the author is aware of the label. This was not introduced by this PR, but the PR touches this test file extensively and would have been the right time to fix it.

**Fix:** rename `find.text('Clear')` → `find.text('Reset')` and rename the test description. Or delete it (the "applying with no selection pops with a null value" test already covers the equivalent semantics).

### I2 — `_FiltersSheetState.build()` mutates `_numberRange` without `setState`
**File:** `lib/features/pokemon/presentation/widgets/sheets/filters_sheet.dart:128-141, 152`

`_maybeRebaseRange` is called from `build()` and mutates `_numberRange = RangeValues(...)` directly. While this happens to render correctly because `build()` returns immediately afterwards, mutating widget state from `build()` is a Flutter anti-pattern and will produce subtle bugs if a future caller does anything else after the rebase (e.g. fires an `onChanged` based on the new range).

**Fix:** move the rebase logic into `didChangeDependencies()` or use a `ref.listen` on `indexCoordinatorProvider` so the rebase is an effect, not a side-effect of building. The current code "works by accident" and a junior reviewer would copy this pattern elsewhere.

### I3 — Coordinators in `presentation/` import from `data/repositories/`
**Files:** `lib/features/pokemon/presentation/coordinators/index_coordinator.dart:7`, `backfill_coordinator.dart:8`, `generation_sample.dart:3`

All three new coordinators import `data/repositories/pokemon_repository_impl.dart` to reach `pokemonRepositoryProvider`. This is a presentation → data direct dependency that bypasses the domain layer. (The pattern was established by the existing use cases — see I3 follow-up — so this isn't a new regression, but it's a regression of architectural discipline.)

The root cause is that the `pokemonRepository` Riverpod provider is colocated with `PokemonRepositoryImpl` rather than with the abstract `PokemonRepository` interface in `domain/repositories/`. **Fix root cause once**: move the `@riverpod PokemonRepository pokemonRepository(Ref ref)` provider into a small `domain/repositories/pokemon_repository_provider.dart` and have the new coordinators import that. Cleaner and one-line per file.

### I4 — `BackfillCoordinator._drain` reads `listMissingSummaryIds()` unbounded once at start
**File:** `lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart:92`

`missingAtStart` reads every missing id (no `limit`) just to compute `total - missing.length` for the initial hydrated baseline. On a fresh install this loads ~1300 ids into a Dart list only to take `.length`. The DAO already has `readIndexBounds().totalCount`; pair it with a small count helper instead of returning the full id list.

**Fix sketch:** add `Future<int> countMissingSummaries()` to the DAO + local data source, then `baseline = total - await repo.countMissingSummaries()`. Trivial query, no allocation.

### I5 — `BackfillCoordinator._hydrateOne` can over-count `hydrated`
**File:** `lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart:128-131`

If a non-backfill code path (e.g., a list pagination call or a skeleton tap) hydrates the same id while the backfill is mid-chunk, the backfill's `Ok` resolution still increments `state.hydrated`. The id was already a summary row; the chunk's `listMissingSummaryIds` snapshot is stale by that point.

This will manifest as a Filters sheet header reading `Filtering across 1027 of 1025 Pokémon` for a moment. Minor cosmetic, but the easier fix is to derive `hydrated` from a count query at chunk boundaries rather than incrementing per call:

```dart
state = state.copyWith(hydrated: total - await repo.countMissingSummaries());
```

This also solves I4.

### I6 — `GenerationSampleSeed` is `keepAlive: true`, persisting across navigations
**File:** `lib/features/pokemon/presentation/coordinators/generation_sample.dart:18`

The seed lives forever. On every sheet open, `initState` calls `reshuffle()` via a post-frame callback. The 1-second throttle gates rapid re-opens. Fine for the happy path, but it means the seed survives across, say, the user closing the sheet, navigating to a detail screen, coming back, and opening the sheet again — the seed will reshuffle (throttle has expired) but it persists in memory indefinitely.

This is harmless but the `keepAlive` is unnecessary: a per-sheet `Random()` instance or a `@riverpod` (autoDispose) seed reset on sheet open would be simpler and equivalent. Either justify `keepAlive` in a doc comment or drop it.

### I7 — No widget test for the GenerationsSheet random-trio reshuffle
**File:** `test/features/pokemon/presentation/widgets/sheets/generations_sheet_test.dart`

The plan's Quality Gates list: "Widget test for Generations sheet reshuffle on close-and-reopen." The test file does not exercise reshuffle. It only covers tile selection and dismiss. Given the throttle logic, the post-frame callback dance, and the keepAlive seed, this is one of the higher-risk surfaces and has no test.

**Fix:** open the sheet, close, advance the clock past 1 second, reopen, and assert the rendered sprite ids differ from the first open (mock the `listGenerationMembers` to return a deterministic large set and seed the throttle's clock-source if needed).

### I8 — No test for `generation_sample.dart` (`GenerationSampleSeed.reshuffle` throttle)
**File:** `lib/features/pokemon/presentation/coordinators/generation_sample.dart`

No tests in `test/features/pokemon/presentation/coordinators/` for the throttle, the seed update, or the fallback path when index isn't ready. The throttle uses `DateTime.now()` directly, making it harder to test — consider parameterizing the clock for testability (matches the pattern in `PokemonRepositoryImpl`).

### I9 — `findPokemon` index path: silent fallback to summaries on empty index
**File:** `lib/features/pokemon/data/repositories/pokemon_repository_impl.dart:194-202`

When `indexRows.isEmpty`, the code falls back to `_local.querySummaries(...)`. This conflates two distinct situations:
1. The index hasn't loaded yet (search "garchomp" returns empty index rows; we want to fall through to whatever's hydrated).
2. The index *is* loaded and "garchomp" genuinely doesn't match.

In case (2), falling through to `querySummaries` runs an extra unnecessary query. Acceptable for correctness (both return the same empty list, just with one extra DB roundtrip), but the comment claims "Either the index hasn't loaded yet OR the search returned nothing" — the latter case shouldn't be conflated.

**Fix:** check `readIndexBounds() != null` (index is loaded) before deciding to fall through; if loaded, an empty result is the real answer.

### I10 — `findPokemon` index path swallows all errors as `CacheFailure`
**File:** `lib/features/pokemon/data/repositories/pokemon_repository_impl.dart:217-219`

```dart
} on Object {
  return const Err(CacheFailure());
}
```

`on Object` will catch programmer errors (`TypeError`, `RangeError`) and surface them as a user-facing cache failure. The summary-fallback path at lines 337-340 has the same shape but it's catching legitimate JSON decode failures from `pokemonFromRow`. Here the operations are mostly Drift reads (which throw `Exception`, not `Object`) — `on Exception` would be safer and let actual programmer bugs surface during testing.

---

## Minor — Nice to Improve

### M1 — `_FailingDetailWriteLocal` test fake is 90 lines of pass-through delegation
**File:** `test/features/pokemon/data/repositories/pokemon_repository_impl_test.dart:41-128`

Every method of `PokemonLocalDataSource` is implemented as `_inner.x()`. This is exactly what mocktail's `noSuchMethod` fallback is designed to do, or what a Dart 3 mixin could collapse. The class exists to override one method (`upsertDetail`). Consider a `_DelegatingLocal` mixin that forwards everything to `_inner`, then a thin `extends _DelegatingLocal` overriding only `upsertDetail`. Cuts ~80 lines.

### M2 — Test stubbing for backfill flow uses a fragile double-mock pattern
**File:** `test/features/pokemon/presentation/coordinators/backfill_coordinator_test.dart:96-108, 127-141, 198-212`

Three tests do this:

```dart
var firstCall = true;
when(() => repository.listMissingSummaryIds(limit: any(named: 'limit')))
    .thenAnswer((_) async {
  if (firstCall) { firstCall = false; return [1,2,3]; }
  return <int>[];
});
when(repository.listMissingSummaryIds).thenAnswer((_) async => [1,2,3]);
```

The second `when` always shadows the same method group, so the `firstCall` toggle on the first stub is largely cosmetic — and the parameter overload makes the intent murky. Mocktail supports `thenReturn` / `thenAnswerInOrder`-style sequencing via separate `when` calls per invocation; or extract a tiny `class _MissingIdsFifo` that pops queues. Either is clearer than the current pattern.

### M3 — `IndexFallbacks.numberRangeBounds` ceiling of 898 is justified in the comment but worth a test
**File:** `lib/features/pokemon/presentation/coordinators/index_fallbacks.dart:42`

The comment says "898 was the catalogue ceiling at the time the slider shipped (Gen I–VIII); we keep it as the offline floor rather than bumping it to today's 1025 so we never claim coverage we can't deliver offline." Good reasoning, but if a future contributor "fixes" 898 to 1025 they'd silently break the offline contract. A 2-line test (`expect(IndexFallbacks.numberRangeBounds.max, 898, reason: ...)`) would pin this.

### M4 — `BackfillCoordinator._chunkSize = 200`, `_indexUpsertBatchSize = 200` — duplicate magic
**Files:** `backfill_coordinator.dart:42`, `pokemon_dao.dart:31`

Two unrelated batch knobs both set to 200, in separate files, with separate justifying comments. They are conceptually different (one is an HTTP-paced drain, the other is a DB-write transaction). Acceptable as-is. If you ever tune one, leave a `// not related to _indexUpsertBatchSize` note in each comment to prevent a future contributor from yoking them.

### M5 — `_SkeletonPokemonCard` duplicates a chunk of `core.PokemonCard`'s positional layout
**File:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart:78-160`

The skeleton card hand-rolls the `Positioned` rectangles and the `Stack` rather than reusing the existing layout primitives from `core.PokemonCard`. This is fine if `core.PokemonCard` is genuinely "tinted-by-type only" but the comment at line 60 says "Same dimensions as `core.PokemonCard` so the list never reflows" — that's a brittle invariant. Consider exposing a `core.PokemonCard.skeleton({required id, required name, required imageUrl, …})` named constructor so a future width tweak updates both at once.

### M6 — `pokemon_dao.dart:281-293` `listMissingSummaryIds` filter via `isNotInQuery`
**File:** `lib/features/pokemon/data/datasources/pokemon_dao.dart:281-293`

The comment defends the choice of subquery over LEFT JOIN. Reasonable. But for very large indices, Drift's `isNotInQuery` materializes the subquery — at 1300 ids it's fine; at 100k it would matter. Acceptable today; flag for a `NOT EXISTS`-style raw SQL custom query if the PokéAPI ever crosses ~10k catalogue entries.

### M7 — `BackfillCoordinator.start()` does not unblock when index transitions ready→stale via TTL
**File:** `lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart:80-85`

`_drain` reads `indexCoordinatorProvider.future` once. If during the drain the index transitions from `ready` to `stale` (TTL crossing — unlikely in a single session given 30-day TTL but possible after a long suspend on mobile), the drain proceeds against a stale view. Acceptable in practice. Worth a one-line `ref.listen(indexCoordinatorProvider, …)` to halt on `failed`, if you want defensive symmetry.

---

## Suggestions

### S1 — Naming: `IndexCoordinator` and `BackfillCoordinator` could be `IndexController` / `BackfillController`
Riverpod's idiomatic noun for an `AsyncNotifier` subclass is "Controller" or "Notifier." "Coordinator" suggests a higher-level orchestrator. Minor. Whichever you pick, be consistent — currently only these two exist with the "Coordinator" suffix.

### S2 — Docstring on `PokemonRepository.refreshIndex` could note the single-flight contract
**File:** `lib/features/pokemon/domain/repositories/pokemon_repository.dart:54-57`

The contract that single-flight coalescing happens in the coordinator (not the repository) is asymmetric with `IndexCoordinator`'s "single-flight" contract. Adding "the repository does NOT deduplicate concurrent calls — that is the coordinator's responsibility" prevents a future caller from reaching past the coordinator and tripping a thundering herd.

### S3 — `BackfillProgress.isComplete` uses `total! > 0` to guard `total != null` — could collapse
**File:** `lib/features/pokemon/presentation/coordinators/backfill_progress.dart:34`

```dart
bool get isComplete => total != null && total! > 0 && hydrated >= total!;
```

After the first null-check, Dart's flow analysis promotes `total` for the remaining checks. The `!` operator twice is harmless but visually noisy; a local capture (`final t = total;`) or `case (final total?)` pattern would read more naturally.

### S4 — `BackfillCoordinator` and `IndexCoordinator` redefine an identical `_isOnline()` helper
Both coordinators have a private `_isOnline()` that reads `connectivityProvider`. Extract to a shared `bool _isOnline(Ref ref)` helper in `connectivity_provider.dart` (or as an extension on `Connectivity`).

### S5 — `officialArtworkUrl` is in `lib/core/pokemon/` — consider `lib/core/network/sprite_urls.dart` or similar
The function is a network-URL builder, not a domain concept. Pokémon-specific, sure, but the URL convention is closer to a service concern. Subjective.

---

## Simplicity Assessment

- **Lines that could be removed:** ~150 if C4 is resolved by deletion (`refresh_index.dart`, `list_generations.dart`, `get_catalogue_bounds.dart`, their `.g.dart` files, their tests).
- **Unnecessary abstractions:** The three unused use cases (C4).
- **YAGNI violations:** The three unused use cases (C4). The duplicated `_isOnline` helpers (S4).
- **Complexity verdict:** **Minor tweaks needed** — the architecture is right-sized for the problem, but the unused use cases and the `_FailingDetailWriteLocal` boilerplate add weight that earns nothing.

---

## Testing Assessment

| Area | Status |
| --- | --- |
| Migration (`app_database_migration_test.dart`) | Complete — v1→v3 and v2→v3 paths both covered |
| DAO new methods (`pokemon_dao_test.dart`) | Strong — search, bounds, generation listing, missing summaries, watch stream, chunking |
| Repository new methods (`pokemon_repository_impl_test.dart`) | Complete — readIndexState idle/ready/stale, refreshIndex success/failure/offline, findPokemon index-aware with skeleton/hydrated/filter-fallback |
| Index mapper (`index_mapper_test.dart`) | Complete — happy path, broken url skip, accent normalization |
| Domain use cases | Complete (but the use cases themselves are dead code — see C4) |
| `IndexCoordinator` (`index_coordinator_test.dart`) | Strong — build, idle/online → ready, single-flight, no-op when ready, offline + no cache → failed, stale offline keeps serving, refresh force-fire. **Missing:** `refresh + offline + ready` (covers C3). |
| `BackfillCoordinator` (`backfill_coordinator_test.dart`) | Strong — index-not-ready gate, full drain, 404 evict + total decrement, halt after 5 errors, error counter reset, offline pause. |
| ViewModel (`pokemon_list_view_model_test.dart`) | Pre-existing strong; new test added for catalogue-coverage kickoff stubs. |
| **`_SkeletonPokemonCard` widget** | **MISSING — see C2.** |
| **`GenerationsSheet` reshuffle** | **MISSING — see I7.** |
| **`generation_sample.dart` providers** | **MISSING — see I8.** |
| Filters sheet (`filters_sheet_test.dart`) | Adequate for ready-state; pre-existing `Clear`-tap test is broken (I1); idle-state covered. |
| Generations sheet (`generations_sheet_test.dart`) | Broken — see C1. |
| Screen integration | Adequate — sheet openers covered, with `_catalogueCoverageStubs` helper for the kickoff side-effect. |

**Test quality:** Where present, the tests are excellent — they assert against state transitions and observable outputs rather than implementation details. The `_FailingDetailWriteLocal` fake demonstrates the right level of fidelity for a partial-failure scenario. The gaps (skeleton, reshuffle, sample, C3) are the only major issues.
