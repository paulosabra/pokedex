# Architecture Review — PR2 (presentation-part2)

**Branch**: `feature/presentation-part2` → `epic/presentation-layer`
**Scope reviewed**: `lib/features/pokemon/presentation/{state,view_models,pages,widgets}` plus the
PR1 import-boundary contract.
**Reference**: `docs/plan/2026-05-26-feat-presentation-layer-plan.md` (PR2 section + Architecture Notes).

## Verdict

**Architecture is clean. Ready to merge from an architectural standpoint.**

Layer boundaries hold. MVVM contract is followed verbatim against Tech Spec §5.2. State management
matches every resolved blocker in the plan (AsyncLoading.copyWithPrevious on the discovery flip;
ref.onDispose registered first with timer + stream teardown; UI inputs preserved across mode flips).
Dependency direction is one-way (presentation → domain only). One small architectural deviation
from the plan (ConsumerStatefulWidget instead of ConsumerWidget) is well-justified and worth
codifying.

## Layer Separation

Scanned every PR2 source file for cross-layer imports:

```
lib/features/pokemon/presentation/{state,view_models,pages,widgets}/**.dart
```

- Presentation → Data: **0 violations**. No file under
  `lib/features/pokemon/presentation/` imports `package:pokedex/features/pokemon/data/...`.
- Presentation → Domain: clean. Only entities (`pokemon`, `pokemon_filter`, `sort_criteria`) and
  use case providers (`get_pokemon_list`, `find_pokemon`, `watch_pokemon_list`) are imported.
- Presentation → Core: only `core/error/{failure,result}`, `core/pokemon/pokemon_type_id`, and
  `core/ui/components/*`. These are the cross-cutting modules the plan explicitly carves out
  (`core/pokemon/` for the type id; `core/ui/` for DS components).
- Presentation → App: only theme tokens (`app/theme/{app_colors,app_typography,pokemon_type_theme}`).
  Acceptable per Tech Spec §10 (theme lives at app scope).

Core → Features check (PR1 boundary):
- `grep -rn "package:pokedex/features" lib/core/` returns **empty**.
- `test/core/ui/import_boundary_test.dart:8-37` will still pass — its rule is "lib/core/ui/** must
  not import package:pokedex/features/**", and PR2 added no files under `lib/core/ui/`.

## MVVM Contract (Tech Spec §5.2)

### `PokemonListState`
`lib/features/pokemon/presentation/state/pokemon_list_state.dart:15-43`

- Freezed with `@freezed abstract class` (the modern Freezed 3.x form). All fields immutable,
  defaulted.
- Single source of truth: `items`, `offset`, `hasMore`, `isLoadingMore`, `isRefreshing`, `query`,
  `filter`, `sort`, `generationId`, `refreshError`. Matches the Tech Spec §5.2 record sketch.
- `isDiscovery` is a derived getter (line 38–42) — correct call site for the mode predicate.
- One observation (Note, below): `refreshError` is the only error-channel field; loadMore errors
  are intentionally swallowed (`view_model:78-82`). The state shape would need a `loadMoreError`
  if PR4 ever needs to surface the pagination-failure banner.

### `PokemonListViewModel`
`lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`

- `@riverpod class PokemonListViewModel extends _$PokemonListViewModel` — generated as
  `AsyncNotifier<PokemonListState>` (`pokemon_list_view_model.g.dart:46`, `100`). Correct shape.
- `build()` returns `Future<PokemonListState>` (line 40). Correct.
- Intent methods (`loadMore`, `search`, `applyFilter`, `changeSort`, `selectGeneration`, `refresh`)
  return only `void` or `Future<void>`. Parameters are primitives or domain entities (`String`,
  `PokemonFilter?`, `SortCriteria`, `int?`). Zero `Ref`/`AsyncValue`/`ProviderSubscription`
  leaking through public surface. **Intent-signature constraint from the plan held.**
- State mutation uses `state = AsyncData(current.copyWith(...))` everywhere — no mutable field
  writes, no `state.value!.items.add(...)` shortcuts.

## State Management Correctness

### AsyncLoading on the discovery flip (resolved blocker 1)
`view_model.dart:240-269` — `_enterDiscovery`:

```dart
state = const AsyncLoading<PokemonListState>().copyWithPrevious(state);
```

The plan's stipulation (line 199–205 of the plan) is implemented verbatim. UI inputs
(`query`/`filter`/`sort`/`generationId`) survive the flip because `copyWithPrevious` retains
the previous `state.value`; only `items` reads as stale-while-loading via `async.isLoading`. The
same pattern repeats on the error path (`view_model.dart:266-268`) — that's a nice touch.

The `// ignore: invalid_use_of_internal_member` comment is the conventional way to call
`copyWithPrevious` in code; this is the canonical Riverpod escape hatch and is fine in a VM.

### Disposal — `ref.onDispose` registered first
`view_model.dart:42-47`:

```dart
ref.onDispose(() {
  _debounce?.cancel();
  _debounce = null;
  _streamSub?.cancel().ignore();
  _streamSub = null;
});
```

Registered **before** the first awaited operation (line 49). Exactly matches the plan's
"disposal first" requirement (plan line 503–508). Both fields are nulled out after cancel so a
later transition rebinding them is observable; `_streamSub` cancellation is `.ignore()`d, which
swallows the cancel-future error without a `try/catch` — correct idiom.

### Timer and stream lifecycle on transitions
- `_debounce` is cancelled and replaced on every `search()` call (`view_model.dart:97-98`).
- `_streamSub` is cancelled before every browse re-subscribe (`view_model.dart:212`) and on
  discovery entry (`view_model.dart:235-236`). No double-subscription path remains.
- Browse re-entry calls `_subscribeBrowseStream` (`view_model.dart:275`) which itself cancels
  the prior subscription first. Idempotent.

The plan's 5-rapid-flip leak test (plan line 242–246) should pass against this code — the
cancel-before-resubscribe invariant is enforced in three places.

## Dependency Direction

VM provider dependency graph (`pokemon_list_view_model.dart:62-63`, `137-139`, `151-153`,
`197-198`, `213`, `243-244`):

- `pokemonListViewModelProvider` depends on:
  - `getPokemonListProvider`
  - `findPokemonProvider`
  - `watchPokemonListProvider`
- It does **not** depend directly on `pokemonRepositoryProvider`. Repository access is
  encapsulated inside each use case provider — exactly the dependency direction the plan calls
  out ("VM depends only on use case providers, not on the repository directly").

No circular dependencies. Presentation depends on Domain. Domain (use case providers, not
reviewed here but inspected for context) compose `pokemonRepositoryProvider` from
`features/pokemon/data/...`; this PR doesn't change that wiring.

## Adapter Pattern — feature `PokemonCard`

`lib/features/pokemon/presentation/widgets/pokemon_card.dart:11-30`:

- Takes a `Pokemon` domain entity.
- Unpacks primitives (`id`, `name`, `imageUrl`, `types.first`, `types.length > 1 ? types[1] :
  null`).
- Calls `core.PokemonCard(...)` via the `as core` aliased import (line 3) — the adapter pattern
  the plan mandates (plan line 144–158, AC line 644: "Adapter import alias").
- Routes the tap via `context.go('/pokemon/${pokemon.id}')` — exactly the contract
  (plan line 157). Domain → DS boundary respected.

## Sheets — stateless to the caller

The three sheet widgets (`filters_sheet.dart`, `sort_sheet.dart`, `generations_sheet.dart`)
each:
- Receive their current selection as a constructor parameter.
- Manage local widget state (`_FiltersSheetState`, `_SortSheetState`, `_GenerationsSheetState`).
- Return the result via `Navigator.pop<T>(...)` — `PokemonFilter?`, `SortCriteria`, `int?`.
- Do NOT own Riverpod state or call `ref.read`/`ref.watch`. They cannot transition VM state;
  only the screen does that after the pop result.

Matches the plan (plan line 160–165: "Sheets do not own Riverpod state").

## Package Structure

This is a single-package Flutter app (not a monorepo) so the "package boundaries" rubric is
mostly N/A. The relevant analog — feature-folder boundaries — is honoured:

- `lib/features/pokemon/presentation/` is the only directory that imports
  `lib/features/pokemon/domain/`. Good.
- `lib/core/ui/` has no dependency on `lib/features/`. Good.
- `lib/app/theme/` has no dependency on `lib/features/`. Good (not in PR2 scope but verified
  while tracing imports).

## Findings

### Blocker
None.

### Fix
None.

### Suggest

1. **Plan-vs-impl mismatch: `ConsumerStatefulWidget` instead of `ConsumerWidget`.**
   `pokemon_list_screen.dart:22-30` declares `class PokemonListScreen extends
   ConsumerStatefulWidget`, but plan line 546 and §5.2 sketch (plan line 28) both specify
   `ConsumerWidget`.

   The deviation is well-justified — the screen owns a `ScrollController` (for `loadMore`
   threshold detection) and a `TextEditingController` (for the search field), both of which
   need `initState`/`dispose`. A pure `ConsumerWidget` could not own these without leaking
   them. This is the right call.

   **Suggested action**: update the plan's Architecture Notes to record the deviation, or
   add a comment on `PokemonListScreen` that says "intentionally Stateful because
   `ScrollController`/`TextEditingController` need a lifecycle." A reader doing plan
   compliance will otherwise flag this as drift.

2. **State shape has only one error channel.**
   `PokemonListState.refreshError` is the only `Failure?` field. `loadMore` failures are
   swallowed (`view_model.dart:78-82`) with a deliberate comment. That's a reasonable PR2
   choice (no UI for it yet), but if PR4 introduces a "more results couldn't load" banner,
   the state will need a `loadMoreError` field. Worth a TODO comment in
   `pokemon_list_state.dart` next to `refreshError` so PR4 doesn't lose track.

### Note

1. **Use case providers import the data layer.**
   `lib/features/pokemon/domain/usecases/get_pokemon_list.dart:2` imports
   `package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart`.
   That's how the `pokemonRepositoryProvider` is wired from data into domain in this
   project, and it predates PR2 (shipped in the domain epic). PR2 does not touch this and
   does not make it worse — the VM only depends on the use case providers, not the
   repository provider — but it is a long-standing layered-architecture observation worth
   flagging once and parking. If the project ever moves to a layered-monorepo (per the VGV
   skill `layered-architecture`), wiring the repository provider in an `app/`-scoped
   composition root would resolve this.

2. **`_composeFilter` correctly merges orthogonal axes.**
   `view_model.dart:280-284` builds a single `PokemonFilter` from the explicit filter +
   the orthogonal `generationId`. `PokemonFilter` carries `generationId`
   (`pokemon_filter.dart:29`), and `_composeFilter` calls `base.copyWith(generationId:
   state.generationId)`. The wire shape passed to `findPokemon` is a single filter, which
   is what the domain use case expects. Clean.

3. **App-boot test was updated correctly.**
   `test/app/app_boot_test.dart:50-66` adds use case provider overrides so the
   `PokemonListScreen` boots against mocked dependencies. The router still composes the
   same way. Deep-link smoke (line 97–114) is preserved.

## Architecture Verdict

Layer boundaries: clean (0 violations).
Dependency direction: one-way, no cycles, VM depends on use case providers only.
MVVM contract: followed verbatim (Freezed state, AsyncNotifier VM, void/Future<void> intents,
primitive parameters).
State management: AsyncLoading.copyWithPrevious + ref.onDispose-first + per-transition timer
and stream teardown — all four PR2 blockers resolved as specified.
Adapter pattern: feature `PokemonCard` is the canonical thin adapter (domain → primitives →
DS component → routing).

**Ready to merge from an architectural standpoint.** Suggestions are documentation-grade
clean-ups, not blocking.
