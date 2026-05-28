---
date: 2026-05-27
reviewer: architecture-agent
branch: feature/presentation-part4
plan: docs/plan/2026-05-27-feat-full-database-coverage-plan.md
scope: uncommitted diff (data + domain + presentation), excludes pokemon_detail_screen.dart (separate commit d715513)
---

# Architecture Review — Full Database Coverage

## Verdict

**Architecture is fundamentally sound and ready to merge with one important callout
to acknowledge before PR.** Layer separation between presentation and data is
preserved everywhere a sheet, view-model, or use case is involved. The
`PokemonIndex` table + DAO + repository extension respects the cache-as-data-source
boundary; the three new use cases match the existing one-method-pass-through
convention. `IndexCoordinator` and `BackfillCoordinator` are correctly modeled
as orchestration providers and the single-flight + connectivity-aware semantics
are implemented as documented in the plan.

The one architectural call worth naming explicitly: the coordinators live under
`presentation/coordinators/` and reach for `pokemonRepositoryProvider`
(the data-layer DI binding) instead of going through use cases. This is a deliberate
extension of an existing, project-wide pattern — the use case providers
themselves all import `data/repositories/pokemon_repository_impl.dart` for the
same DI symbol — but it is the first time the **presentation** layer (not just
the domain layer) names that import. I detail the trade-off below; net-net I
think it is the right call for this feature, but it does deserve a one-line
plan annotation so the next reviewer doesn't read it as drift.

## Findings Summary

| # | Severity | Title |
|---|----------|-------|
| F-1 | Suggest | Coordinators reach `pokemonRepositoryProvider` directly — codify the deviation, or wrap each call in a use case |
| F-2 | Suggest | `_runFetch(force:)` parameter is dead — either honor it or drop it |
| F-3 | Note    | `index_mapper.skeletonFromIndexRow` returns a domain entity with a presentation-level sentinel (`types.isEmpty`) — works, but worth tying down |
| F-4 | Note    | `pokemon_card.dart` infers skeleton-ness from `pokemon.types.isEmpty` — consistent with F-3; consolidate where the convention lives |
| F-5 | Note    | `BackfillCoordinator._connectivitySub` schedules `start()` synchronously inside `build()` — verify no double-fire race on hot rebuild |

No blockers. No layer violations of the project's stated architecture diagram.

## 1. Layer Separation

The plan's diagram is:

```
PRESENTATION (PokemonListViewModel + sheets + coordinators)
  ↓
DOMAIN (PokemonRepository interface + use cases + IndexState entity)
  ↓
DATA (PokemonRepositoryImpl + PokemonDao + Retrofit + mappers)
```

### Layer-by-layer trace

#### Data layer (`lib/features/pokemon/data/`, `lib/core/database/`)
Files in scope:
- `lib/core/database/app_database.dart` — adds `PokemonIndex` table + v2→v3
  migration. Imports: `drift`, `drift_flutter`, `riverpod_annotation` only. Clean.
- `lib/core/database/cache_policy.dart` — adds `kPokemonIndexTtl`. No imports.
  Clean.
- `lib/features/pokemon/data/datasources/pokemon_dao.dart` — adds 7 index-aware
  DAO methods. Imports: `drift`, `core/database/app_database.dart`,
  `data/datasources/pokemon_local_data_source.dart`,
  `data/summary_encoding.dart`, `domain/entities/pokemon_filter.dart`,
  `domain/entities/sort_criteria.dart`. The two domain imports are entity-only
  (no domain logic) — same shape as before. Clean.
- `lib/features/pokemon/data/datasources/pokemon_local_data_source.dart` — adds
  7 abstract methods + the `PokemonIndexBounds` typedef. Only imports
  `core/database/app_database.dart` and domain entities. Clean.
- `lib/features/pokemon/data/datasources/pokemon_remote_data_source.dart` — adds
  `fetchIndex({required int limit})`. Imports unchanged. Clean.
- `lib/features/pokemon/data/services/poke_api_service.dart` — adds Retrofit
  `getPokemonIndex(@Query('limit') int limit)`. Clean.
- `lib/features/pokemon/data/repositories/pokemon_repository_impl.dart` — adds
  `readIndexState`, `refreshIndex`, `listGenerationMembers`, `listMissingSummaryIds`,
  `evictIndexEntry`, `hydrateSummary`, and the index-aware branch in
  `findPokemon`. New import: `index_state.dart` (domain entity) and
  `index_mapper.dart`. The 404-eviction inside `getPokemonDetail` (lines 134-141)
  uses the same `_local` it already had — no new dependency. Clean.
- `lib/features/pokemon/data/mappers/index_mapper.dart` — new file.
  Imports `drift`, `core/database/app_database.dart`,
  `core/pokemon/official_artwork_url.dart`, `data/dtos/pokemon_list_response_dto.dart`,
  `data/mappers/generation_ranges.dart`, `data/summary_encoding.dart`,
  `domain/entities/pokemon.dart`. The domain import is for `Pokemon` (returning
  a skeleton entity from `skeletonFromIndexRow`). Clean — data layer composes a
  domain entity from a cache row, the standard direction.

**Data layer is clean. No reverse imports.**

#### Domain layer (`lib/features/pokemon/domain/`)
- `lib/features/pokemon/domain/entities/index_state.dart` — new entity.
  Imports `freezed_annotation` and `core/error/failure.dart`. Clean.
- `lib/features/pokemon/domain/repositories/pokemon_repository.dart` — adds
  6 interface methods (`readIndexState`, `refreshIndex`,
  `listGenerationMembers`, `listMissingSummaryIds`, `evictIndexEntry`,
  `hydrateSummary`). Imports: `core/error/result.dart`, domain entities
  (including the new `index_state.dart`). Clean.
- `lib/features/pokemon/domain/usecases/refresh_index.dart`,
  `list_generations.dart`, `get_catalogue_bounds.dart` — three new use cases.

Each of the new use cases imports
`features/pokemon/data/repositories/pokemon_repository_impl.dart` to wire the
`pokemonRepositoryProvider`. **This is the long-standing project convention**
(documented in PR2's architecture review as a "Note") and predates this feature
— `get_pokemon_list.dart:2`, `get_pokemon_detail.dart:2`,
`get_evolution_chain.dart:2`, `find_pokemon.dart:2`, `watch_pokemon_list.dart:1`
all do the same. Not a fresh violation; the new use cases conform. The
real-world fix would be to relocate `@riverpod PokemonRepository pokemonRepository`
to `lib/app/` as a composition root (so domain can depend on its own provider
file and the data-impl file stays domain-free); deferred per the convention
already in place.

**Domain layer respects its boundary with the same caveat as the rest of the
codebase. No new violation.**

#### Presentation layer (`lib/features/pokemon/presentation/`)
- `view_models/pokemon_list_view_model.dart` — imports only `core/error/`,
  `domain/entities/`, `domain/usecases/`, `presentation/coordinators/`,
  `presentation/state/`, `riverpod`. **No data imports.** Clean.
- `widgets/pokemon_card.dart` — imports `app/theme/`, `core/ui/components/`,
  `domain/entities/pokemon.dart`. No data imports. Clean.
- `widgets/sheets/filters_sheet.dart` — imports `app/theme/`, `core/pokemon/`,
  `core/ui/components/`, `domain/entities/`, `presentation/coordinators/`.
  No data imports. Clean.
- `widgets/sheets/generations_sheet.dart` — imports `app/theme/`,
  `core/pokemon/official_artwork_url.dart`, `core/ui/components/`,
  `domain/entities/index_state.dart`, `presentation/coordinators/`.
  No data imports. Clean.

But:

- `coordinators/index_coordinator.dart` (line 7) → imports
  `features/pokemon/data/repositories/pokemon_repository_impl.dart`.
- `coordinators/backfill_coordinator.dart` (line 8) → same.
- `coordinators/generation_sample.dart` (line 3) → same.

These three coordinators sit under `presentation/coordinators/` and import
the data layer's `pokemonRepositoryProvider` symbol. By the diagram, the
presentation layer should only reach the domain layer — and that's exactly the
contract the view-model upholds. The coordinators bypass it.

See F-1 below for the full trade-off discussion.

**Layer-violation count (strict reading of the diagram): 3 files.**
**Layer-violation count (project convention, where any provider that names a
repository-implementation file's provider symbol counts as "wiring DI"): 0.**

I am reporting it as a "Suggest", not a "Blocker", on those grounds.

## 2. State Management Correctness

### `IndexCoordinator` (`lib/features/pokemon/presentation/coordinators/index_coordinator.dart`)

| Check | Result |
|-------|--------|
| Naming | `IndexCoordinator` — descriptive, matches plan. Good. |
| `@Riverpod(keepAlive: true)` | Intentional per task brief; `keepAlive` is correct so a sheet open/close doesn't refetch ~200 KB. Good. |
| State immutability | `IndexState` is a Freezed class with `copyWith`. Good. |
| Business logic location | State-machine transitions live in the coordinator; the repository owns I/O. Correct separation. |
| Single-flight enforcement | `_inFlight` Future guard at lines 51 and 71. Both `loadIfNeeded` and `refresh` share the same guard, so a `refresh()` that lands during a `loadIfNeeded()` correctly joins the in-flight Future. **Single-flight is enforced; covered by `index_coordinator_test.dart:73` ("loadIfNeeded is single-flight (concurrent calls coalesce)").** Good. |
| Disposal | None needed (no streams or timers owned by this provider). Good. |
| Concurrent error handling | Caller wraps `_runFetch` in try/finally that always clears `_inFlight`. Good. |
| State transition fidelity to plan | I traced every transition row in the plan's table against `_runFetch` — all eight match. (`idle+online→loading→ready`, `idle+offline→failed`, `stale+offline→stale` keep-cache, `ready+offline-refresh→stale-with-error`, etc.) |

**One smell — F-2 below: `_runFetch({bool force = false})` parameter is unused.**
The `force` parameter is set by `refresh()` (line 73) but never read inside
`_runFetch` (only mentioned in a comment at line 118). Today `refresh()`
effectively forces because the freshness check it would otherwise gate on lives
in `loadIfNeeded` (lines 53-57), not in `_runFetch`. So the parameter is
declared-only. Easy fix.

### `BackfillCoordinator` (`lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart`)

| Check | Result |
|-------|--------|
| Naming | Good. |
| `@Riverpod(keepAlive: true)` | Intentional; progress survives sheet open/close. Good. |
| State immutability | `BackfillProgress` is Freezed. Good. |
| Single-flight | `_draining` Future guard at lines 49, 69. Good. |
| Concurrency bounds | `_concurrent = kIsWeb ? 4 : 8` (line 37), per plan. `_chunkSize = 200` (line 42). Good. |
| Error budget | `_consecutiveErrors >= _maxConsecutiveErrors` halts the session with `isHaltedThisSession = true` (lines 100-105). 404s explicitly excluded from the counter (line 142 — error path is `_consecutiveErrors += 1` only for non-`NotFoundFailure`). Good. |
| Disposal | `ref.onDispose(() => _connectivitySub?.cancel());` (line 62). Good. |
| Reconnect resume | `onConnectivityChanged` listener fires `start()` when online again (line 60). `start()` is idempotent via the `_draining` guard. Good. |
| State scoping | All mutations of `state` are inside the notifier's own methods; no external mutation. Good. |

**One subtle smell — F-5 below**: `build()` synchronously creates the
connectivity subscription before returning the seed state. If a fast hot
restart in dev causes `build()` to run while the previous instance's `start()`
is still draining, both could be alive briefly. In practice `keepAlive: true`
plus `ref.onDispose` covers this on a clean restart, but there is no test
asserting the listener is set up exactly once. Minor — would be one more test
case (`backfill_coordinator_test.dart` has 6 tests today).

### `GenerationSampleSeed` and `generationSample` (`generation_sample.dart`)

| Check | Result |
|-------|--------|
| Naming | Good. |
| `keepAlive: true` on the seed | Good (seed is intentional across re-opens; reshuffle only on explicit call). |
| Per-second throttle | Implemented (lines 28-31). Good. |
| The `generationSample` function provider depends on the seed AND on `indexCoordinatorProvider.future` — both correct dependencies. | Good. |

The provider imports `pokemonRepositoryProvider` (line 3) which is the same
coordinator-level layer-crossing already flagged in F-1.

### `PokemonListViewModel` (delta only)

The only change in scope is the `unawaited(_kickoffCatalogueCoverage())` call
in `build()` (line 59) and the helper `_kickoffCatalogueCoverage` (lines 63-69).

- `_kickoffCatalogueCoverage` awaits the index `loadIfNeeded`, then
  `unawaited`s the backfill `start`. This matches the plan's
  "Sequencing — first launch, online" diagram: index loads after page-0,
  backfill starts after index.
- It is fired from `build()` via `unawaited` — does not block the first
  AsyncData emit, so the cold-start latency AC ("≤ baseline + 100ms") is
  preserved.
- Disposal — `ref.onDispose` is set first (line 49) and the in-flight
  `_kickoffCatalogueCoverage` Future is `unawaited`. If the VM is disposed
  while `loadIfNeeded` is in flight, the coordinator's Future continues
  (it's a `keepAlive: true` provider on a different lifetime). Correct.

The VM still depends only on use case providers + coordinator providers.
**It does not import the data layer.** Clean.

## 3. Dependency Direction

Concrete dependency graph for the feature (presentation→…→data direction only):

```
PokemonListScreen (ConsumerWidget)
   ↓ ref.watch
pokemonListViewModelProvider
   ↓ ref.read
   ├─ getPokemonListProvider   ─→ pokemonRepositoryProvider
   ├─ findPokemonProvider      ─→ pokemonRepositoryProvider
   ├─ watchPokemonListProvider ─→ pokemonRepositoryProvider
   ├─ indexCoordinatorProvider ─→ pokemonRepositoryProvider   ← coordinator
   └─ backfillCoordinatorProvider ─→ pokemonRepositoryProvider ← coordinator

FiltersSheet (ConsumerStatefulWidget)
   ↓ ref.watch
   ├─ indexCoordinatorProvider     ─→ pokemonRepositoryProvider
   └─ backfillCoordinatorProvider  ─→ pokemonRepositoryProvider

GenerationsSheet (ConsumerStatefulWidget)
   ↓ ref.watch
   ├─ indexCoordinatorProvider                              (no DI bypass)
   ├─ generationSampleProvider(genId) ─→ pokemonRepositoryProvider ← coordinator
   └─ generationSampleSeedProvider                          (no DI bypass)
```

- No reverse edges. No cycles.
- `pokemonRepositoryProvider` is reached from two sides: (a) the use case
  providers in `domain/usecases/` and (b) the three coordinator providers in
  `presentation/coordinators/`. The (a) path is the pre-existing convention;
  the (b) path is new in this feature and is what F-1 is about.

`PokemonListViewModel`, the sheets, and the cards never directly name
`pokemonRepositoryProvider` or any `data/` symbol. The coordinator-to-data
edge is the only one crossing the presentation/data line.

## 4. Package Structure

Single-package Flutter app; the per-folder analog:

- `lib/core/database/` — `app_database.dart` extended with one table + a v3
  migration that's purely additive (`m.createTable(pokemonIndex)`); existing
  data untouched. `cache_policy.dart` adds one constant. Coherent.
- `lib/core/pokemon/` — new file `official_artwork_url.dart`. The plan
  promises "one shared source" for the sprite URL; the sheet and the
  index mapper both consume it. Good consolidation; no longer duplicated
  inline as `generations_sheet.dart:206` had it before.
- `lib/features/pokemon/data/mappers/` — new file `index_mapper.dart` with
  `indexFromResponse` (DTO→Companion) and `skeletonFromIndexRow`
  (Row→Pokemon-with-empty-types). Co-located with peer mappers.
- `lib/features/pokemon/data/datasources/` — DAO + LocalDataSource extended in
  place; no new files. Good (avoids fragmenting per-method).
- `lib/features/pokemon/domain/entities/` — new file `index_state.dart`.
  Entity + enum + the `idle()` factory. Single responsibility.
- `lib/features/pokemon/domain/usecases/` — three new files, one per use case
  (`refresh_index.dart`, `list_generations.dart`, `get_catalogue_bounds.dart`).
  Each is a thin pass-through; the file-per-use-case convention is the same as
  the existing five. Good.
- `lib/features/pokemon/presentation/coordinators/` — NEW directory with five
  files: `index_coordinator.dart`, `backfill_coordinator.dart`,
  `backfill_progress.dart`, `generation_sample.dart`, `index_fallbacks.dart`.
  This is a new architectural slot — co-locating cross-sheet orchestration
  state outside both the VM and the individual sheets. Reasonable shape, but
  see F-1 for whether the slot itself should be reframed.

## Findings

### F-1 — Suggest: Coordinators reach `pokemonRepositoryProvider` directly. Codify the deviation in the plan or wrap each call in a use case.

`<lib/features/pokemon/presentation/coordinators/index_coordinator.dart:7>`
`<lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart:8>`
`<lib/features/pokemon/presentation/coordinators/generation_sample.dart:3>`

The plan's diagram puts the coordinators in the PRESENTATION layer and shows
them reading the domain's `findPokemon` / `listGenerations` / `bounds`. In the
shipped code, the three coordinators import
`features/pokemon/data/repositories/pokemon_repository_impl.dart` and call
`ref.read(pokemonRepositoryProvider)…` directly:

- `index_coordinator.dart:42` — `ref.read(pokemonRepositoryProvider).readIndexState()`
- `index_coordinator.dart:105` — `ref.read(pokemonRepositoryProvider).refreshIndex()`
- `backfill_coordinator.dart:88, 92, 111, 126, 136` — `repo.listMissingSummaryIds`,
  `repo.hydrateSummary`, `repo.evictIndexEntry`
- `generation_sample.dart:48` — `ref.read(pokemonRepositoryProvider).listGenerationMembers(generationId)`

These are repository methods that already have a domain interface declaration
in `pokemon_repository.dart`, so the runtime contract is fine. The grievance is
purely the **import path**: presentation now names a `data/repositories/*` file
as one of its providers' sources.

**Why this is not a hard violation**:

1. **Domain use cases already do the same thing.**
   `get_pokemon_list.dart:2`, `get_pokemon_detail.dart:2`, `find_pokemon.dart:2`,
   etc., import the same `pokemon_repository_impl.dart` file for the same DI
   binding. The previous architecture reviews
   (`docs/reviews/2026-05-27-presentation-part2/architecture-review.md:197-208`)
   parked this as a "long-standing layered-architecture observation" to be
   resolved if/when the project moves to a layered-monorepo. Presentation
   crossing the same line is not a new pattern; it's the same DI cost paid by a
   new caller.

2. **The coordinators have no logical use case that would not be a pass-through.**
   `IndexCoordinator.refresh()` would call `RefreshIndexUseCase()`, which is
   itself a one-line pass-through to `_repository.refreshIndex()`
   (`refresh_index.dart:21`). The use case adds zero behavior on top of the
   repository method. Likewise `listGenerationMembers` and
   `listMissingSummaryIds` are simple reads.

3. **The pattern is internally consistent.** All three coordinators do this; not
   a one-off lapse.

**Why it still deserves an explicit call-out**:

1. **The plan's diagram does not reflect what shipped.** The plan shows
   presentation reading "findPokemon / listGenerations / bounds" — those names
   are use case names. The shipped coordinators bypass the use cases.
2. **It widens the surface of `pokemon_repository_impl.dart` as a public
   import.** Every additional file that names it makes a future refactor (a real
   composition root in `lib/app/`) more invasive.
3. **It is the first time the boundary that the view-model and sheets carefully
   uphold is broken in this same feature.** The VM still goes through use
   cases. The sheets still go through coordinators (not directly to data).
   But the coordinators go straight to data. Adjacent layers, one rule each.

**Recommended action** (pick one):

- **(a) Codify the deviation.** Add one line to the plan's architecture
  diagram: "Coordinators inject `pokemonRepositoryProvider` directly — see
  PR2 architecture-review F-Note-1 for the project-wide DI-from-data
  convention; the coordinator inherits it." This is the cheapest, most honest
  fix. No code changes.
- **(b) Wrap each coordinator call in its own use case** (`ReadIndexState`,
  `RefreshIndexUseCase` already exists, `ListMissingSummaryIds`, `HydrateSummary`,
  `EvictIndexEntry`, `ListGenerationMembers` — three more). The four new ones
  would each be 5 lines, all pass-throughs. This restores the diagram but
  costs ~80 LoC of plumbing and adds four files for no behavior. The previous
  review parked the larger structural fix on the same trade-off.

I lean (a) for this PR. If/when the project does the broader composition-root
move, (b) becomes a search-and-replace.

### F-2 — Suggest: `IndexCoordinator._runFetch({bool force = false})` parameter is unused — remove or honor it.

`<lib/features/pokemon/presentation/coordinators/index_coordinator.dart:82, 118>`

`refresh()` (line 73) passes `force: true` to `_runFetch`. `_runFetch` never
reads `force`. The freshness check (`idle/stale/failed` gate) lives in
`loadIfNeeded` (lines 53-57), not in `_runFetch`, so today `refresh()`
effectively forces by sidestepping that gate. The `force` parameter is a no-op
documentation-only signal.

Two ways out:

- **Drop the parameter** (`_runFetch(IndexState previous)`). The behavior is
  preserved, and the comment at line 118 ("`force` ignores the freshness
  check…") gets clarified to say "by-passing the freshness check is the
  caller's responsibility — `loadIfNeeded` gates, `refresh` does not".
- **Honor the parameter** by moving the freshness gate into `_runFetch`, then
  `refresh()` opts out via `force: true`. That centralizes the check but adds
  a branch.

The dropping variant is simpler and matches the actual behavior.

### F-3 — Note: `index_mapper.skeletonFromIndexRow` returns a `Pokemon` entity with `types: []` as a presentation-layer sentinel.

`<lib/features/pokemon/data/mappers/index_mapper.dart:37-42>`
`<lib/features/pokemon/presentation/widgets/pokemon_card.dart:36-44>`

The data-layer mapper produces a domain entity whose `types.isEmpty` is the
implicit signal to the presentation layer that this row is a "skeleton" (no
detail hydrated yet). The convention is well-commented in the mapper, but:

- The domain entity has no `bool get isSkeleton` accessor — the convention is
  implemented twice, once at the producer and once at the consumer
  (`pokemon_card.dart:37`).
- A future consumer that reasonably assumes `types` is always populated could
  miss the convention.

This is a clarity nit, not a correctness bug. A `bool get isSkeleton => types.isEmpty;`
on the `Pokemon` entity (or a comment in `pokemon.dart` next to the `types`
field) would tie the convention to the entity itself. Optional.

### F-4 — Note: `pokemon_card.dart` branches on `pokemon.types.isEmpty`. Same convention as F-3.

`<lib/features/pokemon/presentation/widgets/pokemon_card.dart:36-44>`

Same observation as F-3, from the consumer side. If you adopt the `isSkeleton`
getter in F-3, the card uses it: `if (pokemon.isSkeleton) return _SkeletonPokemonCard(...)`.

### F-5 — Note: `BackfillCoordinator.build()` synchronously subscribes to connectivity. Verify there's no transient double-`start()` on rebuild.

`<lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart:55-63>`

`build()` (`keepAlive: true`) sets up `_connectivitySub` and the `ref.onDispose`
cancellation. If something invalidates the provider (manual `ref.invalidate`,
which the codebase doesn't do today but a future feature might), `build()`
re-runs and a fresh subscription is created. The old subscription is cancelled
on `onDispose`, but the ordering is:

1. Riverpod rebuilds the provider.
2. The old subscription's cancellation fires asynchronously via `onDispose`.
3. The new `build()` synchronously subscribes.

For a brief window, two subscriptions exist. Each will invoke `start()` on a
connectivity event, and `start()` is single-flight via `_draining`, so a
duplicate online tick is absorbed. **In practice this is safe.** Worth a unit
test that asserts the listener is set up exactly once per build, given the
plan's AC explicitly lists "resumes within 2s of reconnect" — a duplicate-fire
would still satisfy that AC but is the kind of thing that grows teeth later.

The 6 tests in `backfill_coordinator_test.dart` cover the success and 404
paths, the 429-halt budget, and the chunked drain shape. Add one more for
"build → invalidate → build does not double-fire `start()` on the next online
tick" if you want belt-and-braces.

## Cross-cutting checks

- **No widget reaches into the cache or DTO layer.** Verified by grep:
  `grep -rn "package:pokedex/features/pokemon/data" lib/features/pokemon/presentation/`
  returns only the three coordinator files. The sheets and the card import
  domain entities and presentation-only providers.
- **No data-layer file imports the presentation layer.** Verified by grep:
  `grep -rn "package:pokedex/features/pokemon/presentation" lib/features/pokemon/data/`
  returns nothing.
- **No core file imports a feature.** `lib/core/database/app_database.dart` and
  `lib/core/pokemon/official_artwork_url.dart` import only third-party and core
  symbols.
- **The drift schema bump (v2→v3) is additive and self-contained.** Migration
  test exists (`test/core/database/app_database_migration_test.dart`).
  Acceptance criterion "PokemonIndex empty afterward" is honored by the
  `createTable` (not `createTable + seed`) on line 167 of `app_database.dart`.

## Justification on the coordinator-layer question (the task brief asked for this)

> The coordinators sit in `presentation/coordinators/` but call repository
> methods directly via `pokemonRepositoryProvider`. Is this layering OK or
> should they go through use cases?

**My call: it is acceptable for this PR, with a single-line plan annotation.**

The argument for routing through use cases is that the **presentation** layer
(of which coordinators are now a part) should never import a `data/repositories/*`
file. That is a clean principle.

The argument against is fourfold:

1. **The project already pays this DI cost on the domain side.** Every existing
   use case imports `data/repositories/pokemon_repository_impl.dart` to wire
   `pokemonRepositoryProvider`. The architectural debt is the location of the
   provider declaration, not the number of files that consume it. Wrapping
   coordinator calls in three more pass-through use cases moves the import
   shape — it does not eliminate it.
2. **Coordinators are not the same kind of caller as the view-model or the
   sheets.** The VM and the sheets carry user-facing semantics (intents,
   selection state). Coordinators carry orchestration semantics — single-flight
   guards, error budgets, state machines, paced drain. They are closer in
   spirit to "infrastructure adapters that happen to live in `presentation/`"
   than to "UI widgets". Forcing each repository call through a one-line use
   case decorates that orchestration without enriching it.
3. **There is no behavior a use case would add.** Each candidate use case
   (`ReadIndexState`, `ListMissingSummaryIds`, `HydrateSummary`,
   `EvictIndexEntry`, `ListGenerationMembers`) would be `=> _repository.foo(args)`.
   Use cases earn their files when they compose multiple repository calls,
   add validation, or own a domain rule. None of these would.
4. **The existing tests prove the contract.** The coordinator tests mock
   `PokemonRepository` and verify behaviour against the interface — exactly
   the abstraction that would be tested if a use case wrapped the calls. The
   test surface does not improve with the wrapper.

The plan diagram is slightly idealized here. Annotate the diagram (one line)
to acknowledge "coordinators inject `pokemonRepositoryProvider` directly,
same DI convention as use cases" and the architecture document matches the
shipped code.

If the project later moves to a real composition root in `lib/app/`, all
callers (use cases + coordinators) switch in lockstep.

## Verdict (restated)

**Architecture is clean enough to merge.** No layer violations beyond the
pre-existing DI convention; the new coordinator slot inherits that convention
rather than introducing a new one. Single-flight, disposal, and state-machine
shape are all correct in the coordinators. Domain interface is the right shape,
six new methods are well-named, and the data-layer extensions are additive and
minimally invasive.

Two small suggestions worth picking up before PR (F-1 plan annotation, F-2
dead parameter); three notes worth keeping on the list (F-3/F-4 skeleton
convention, F-5 listener double-fire test).

Approving from the architecture seat.
