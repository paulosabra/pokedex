# PR4 — Architecture Review

**Scope:** `feature/presentation-part4` — error/empty state widgets + responsive layout primitives; rewires list + detail screens.
**Reviewer:** Architecture Review Agent (VGV layered architecture lens)
**Verdict:** Ready to merge — 0 critical, 1 important, 2 suggestions.

The architecture work in PR4 is clean. The new error/empty widgets honor the `core/ui` → `app/theme` boundary that the project has used since PR1, and they take no Riverpod dependencies (pure presentational, as the plan required). The responsive primitives sit where the plan placed them with the right justification. The one structural concern worth surfacing is `MasterDetailScaffold`'s direct instantiation of `PokemonListScreen` from inside the detail screen — it works today, but it pins `lib/app/layout/` to feature presentation code and quietly nullifies the "app shell composes" framing that justified the location in the first place.

---

## 1. Layer Separation

### `lib/core/ui/states/*.dart` — no feature imports

All six widgets:

| File                                                  | Imports (non-Flutter)                   | Verdict |
| ----------------------------------------------------- | --------------------------------------- | ------- |
| `lib/core/ui/states/empty_filter_widget.dart`         | `app/theme/app_colors`, `app/theme/app_typography` | Clean |
| `lib/core/ui/states/empty_generation_widget.dart`     | same                                    | Clean |
| `lib/core/ui/states/empty_search_widget.dart`         | same                                    | Clean |
| `lib/core/ui/states/generic_error_widget.dart`        | same                                    | Clean |
| `lib/core/ui/states/offline_error_widget.dart`        | same                                    | Clean |
| `lib/core/ui/states/stale_cache_banner.dart`          | same                                    | Clean |

**None of the six widgets reach into `lib/features/`** — the rule the user flagged is honored. No Riverpod, no domain entities, no use cases. Every dependency is data passed via constructor parameters and callbacks emitted on user actions. This is exactly the contract the plan stated ("All widgets are pure presentational: take data via ctor params, surface `onRetry` callbacks. No Riverpod imports." — plan §"Files added — error/empty widgets").

A grep across `lib/core/` for feature imports returns nothing:

```
$ grep -rn "import 'package:pokedex/features" lib/core/
(no matches)
```

The `core → app/theme` direction (`AppColors`, `AppTypography`) is pre-existing project-wide (PR1 established it for `core/ui/components/`) and is consistent with how the project frames `app/theme/` as design tokens rather than app shell composition. Not a PR4 issue.

### `lib/app/layout/*.dart` — no feature imports

| File                                          | Imports                                                              | Verdict |
| --------------------------------------------- | -------------------------------------------------------------------- | ------- |
| `lib/app/layout/breakpoints.dart`             | `flutter/widgets` only                                               | Clean |
| `lib/app/layout/responsive_layout.dart`       | `flutter/material`, `app/layout/breakpoints`                         | Clean |
| `lib/app/layout/master_detail_scaffold.dart`  | `flutter/material`, `app/layout/breakpoints`, `app/theme/app_colors` | Clean |

`MasterDetailScaffold` does **not** import `PokemonListScreen` directly. It accepts a `WidgetBuilder masterBuilder` and lets the caller decide what to mount. This is the correct shape for an app-shell primitive — it stays feature-agnostic. The structural dependency lives in `pokemon_detail_screen.dart`, not the scaffold itself (see §3 below).

### Cross-layer scan (whole repo)

```
$ grep -rn "import 'package:pokedex/features" lib/core/   → 0 matches
$ grep -rn "import 'package:pokedex/features" lib/app/    → app_router.dart (composition root) + height_weight_theme.dart (PR2-era)
$ grep -rn "import 'package:pokedex/features/pokemon/data" lib/features/pokemon/presentation/ → 0 matches
```

Presentation never reaches into `data/` directly. The only place that imports `features/pokemon/data/` from outside `data/` is the domain ring (use cases pulling `pokemonRepositoryProvider` from `repositories/pokemon_repository_impl.dart`) — a known, pre-existing project pattern that the foundation epic settled on (provider co-location with implementation). Not a PR4 issue.

**Violations introduced by PR4: 0.**

---

## 2. State Management Correctness

PR4 doesn't introduce new ViewModels. It rewires two existing screens against PR2/PR3 ViewModels (`pokemonListViewModelProvider`, `pokemonDetailViewModelProvider`) and consumes the new error/empty widgets.

### `PokemonListScreen` (`lib/features/pokemon/presentation/pages/pokemon_list_screen.dart`)

| Check                                | Finding |
| ------------------------------------ | ------- |
| Intent-only dispatch to ViewModel    | ✅ Every interaction (`_openFilters`, `_openSort`, `_openGenerations`, `_clearSearch`, `_clearFilter`, `_refresh`, scroll-driven `loadMore`, `search`) goes through `ref.read(pokemonListViewModelProvider.notifier).<intent>(…)`. No `ref.read(repositoryProvider)` or use-case calls from the View. |
| Business logic in the View?          | ⚠️ One small bit lives in the View: `_EmptyState._filterIsEffectivelyEmpty(PokemonFilter?)` (lines 456–462). It introspects domain-entity fields to pick which empty widget to render. The View *should* know "this filter is empty"; the question is whether the View or the State should report it. See §6 (Suggestions). |
| Direct data/repository reach         | ✅ No imports from `features/pokemon/data/`. The View only imports domain entities (`PokemonFilter`, `SortCriteria`), presentation state, the VM provider, and core/ui/app primitives. |
| AsyncValue handling                  | ✅ The `_Body` widget correctly handles `AsyncLoading.copyWithPrevious(AsyncError)` (lines 292–304), distinguishes initial-load skeleton from refresh error, and routes through the right error widget per failure type (`NetworkFailure` / `CacheFailure` → `OfflineErrorWidget`, else `GenericErrorWidget`). |
| Side-effect lifecycle                | ✅ `ScrollController` + `TextEditingController` are owned by the State and disposed in `dispose()`. `loadMore` is wrapped in `unawaited` (line 72) which is the right Riverpod idiom for fire-and-forget intents. |
| Mounted guards on async              | ✅ All async modal flows (`_openFilters`, `_openSort`, `_openGenerations`) check `mounted` before dispatching the resulting intent. |

### `PokemonDetailScreen` (`lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart`)

| Check                                | Finding |
| ------------------------------------ | ------- |
| Intent-only dispatch                 | ✅ The screen only `ref.watch`es `pokemonDetailViewModelProvider(id)` — there are no intents on this screen by design. |
| Business logic in the View?          | ✅ The only "logic" is a defensive fallback when `types.isEmpty → PokemonTypeId.normal` (line 67). That's a pure UI fallback for render-time safety, not domain logic. |
| Error classification in the View     | ✅ Same `NetworkFailure | CacheFailure` switch as the list (line 237). Pre-existing pattern from PR3; PR4 only swaps the rendering target to the new shared widgets. |

### New widgets in `lib/core/ui/states/`

| Check                | Finding |
| -------------------- | ------- |
| Any local state?     | ✅ All six are `StatelessWidget`. Zero internal state — they receive labels, callbacks, and optional copy via constructor parameters. |
| Storage of secrets, IDs, controllers, timers, etc. | ✅ None. |

**State-management verdict:** Correct. No new state is introduced; the rewired screens stay strictly View → ViewModel → use case.

---

## 3. Dependency Direction — `MasterDetailScaffold` placement

This is the one structural concern. The plan placed the responsive trio under `lib/app/layout/` rather than `lib/core/ui/layout/` with this justification (plan lines 826–831):

> The location follows Tech Spec §9.1's framing of responsiveness as an app-level concern (the breakpoints govern how the whole app composes, not a reusable UI primitive). If at PR4 plan time the trio is purely presentational and feature-agnostic, consider moving to `lib/core/ui/layout/` — but `lib/app/` is the default since the scaffold wires routes.

The implementation honors the framing for two of the three files:

- `breakpoints.dart` — feature-agnostic constants & enum. Could live in `lib/core/`; sits in `lib/app/` because it's the entry point of the responsive contract.
- `responsive_layout.dart` — feature-agnostic helpers (`gridColumns`, `showSheetOrDialog`). Same call.
- `master_detail_scaffold.dart` — **also feature-agnostic by its own signature** (takes a `WidgetBuilder masterBuilder`, no feature imports).

But the **consumer site does the feature wiring inside the feature**:

```dart
// lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:14, 48–51
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';
…
return MasterDetailScaffold(
  masterBuilder: (_) => const PokemonListScreen(),
  child: body,
);
```

This is what creates the structural dependency the reviewer asked about — **but it lives in the feature, not in `lib/app/layout/`**. The scaffold itself is clean. The detail screen importing the list screen is an *intra-feature* import (both under `features/pokemon/presentation/pages/`), not a layer violation.

That said, the consequence the plan's justification was guarding against — "the scaffold wires routes" — has *not* actually happened: the router was deliberately left untouched (plan §"Files modified — PR4" / acceptance criteria). The detail screen instantiates `PokemonListScreen` as a widget, not as a route, so the master-detail composition runs *outside* the router. This works, but it has three structural side effects worth surfacing:

1. **The master-detail composition is duplicated** at every screen that wants to participate. Today only the detail screen wraps in `MasterDetailScaffold`; if a future feature wants the same behavior, it would have to repeat the wrapping and hardcode its own master panel.
2. **`PokemonListScreen` is instantiated twice on expanded** — once at `/pokemon/:id` (as the master via `MasterDetailScaffold`) and conceptually once on the `/` route. Riverpod providers are shared, so the data is consistent, but you pay double widget cost for the header/search field/scroll controller. Pre-existing concern noted in the plan as "wrap approach"; not introduced by PR4 architecture, but worth a perf eye if the expanded layout becomes load-bearing.
3. **The justification for `lib/app/layout/` ("scaffold wires routes") is now technically false.** It doesn't wire routes; it wraps a widget. By the plan's own decision criterion ("If at PR4 plan time the trio is purely presentational and feature-agnostic, consider moving to `lib/core/ui/layout/`"), the right home is arguably `lib/core/ui/layout/`. This is the **important** finding below.

**Dependency direction within `lib/app/layout/`:** clean. None of the three files reach into `features/`. The scaffold's API is symmetric — it takes a `Widget child` and a `WidgetBuilder masterBuilder`. Pure composition primitive.

---

## 4. Package / Folder Structure

PR4 adds two new folders:

### `lib/core/ui/states/`

- ✅ Single clear responsibility: presentational error/empty state widgets.
- ✅ Six files, all stateless, all stylistically consistent (centered Icon + message + optional CTA).
- ✅ All consume `app/theme/` tokens (consistent with the established `core/ui/components/` pattern from PR1).
- ✅ Matches the plan's enumerated file list exactly.
- ✅ No grab-bag — every widget maps to a specific TE/RN code documented in the dartdoc.
- ✅ Test mirror exists at `test/core/ui/states/`.

### `lib/app/layout/`

- ✅ Single clear responsibility: viewport-driven layout primitives.
- ✅ Three files, all the plan called for.
- ✅ Tests at `test/app/layout/`.
- ⚠️ Naming: `Breakpoints` is `abstract final class … _();` (a static container) sitting next to a `Breakpoint` enum. The dual naming is fine but slightly easy to mistype — the enum is the API consumers use, and the abstract class only holds two numeric thresholds. Could collapse into the enum file or rename to `BreakpointThresholds` if a future readership trips on it. Suggestion only.
- ⚠️ See §3 for the placement debate.

**No new packages**; PR4 doesn't restructure the lib root. No spurious dependencies added to `pubspec.yaml` (plan said "no changes expected" — confirmed).

---

## 5. Findings

### Critical (must fix before merge)

None.

### Important (should address — file an issue if deferring)

**A.** `master_detail_scaffold.dart` placement vs. its actual coupling. The plan placed it under `lib/app/layout/` on the assumption that it would "wire routes." It doesn't — it composes widgets at the feature boundary, and the consuming feature (`pokemon_detail_screen.dart`) is what imports `PokemonListScreen` directly to satisfy `masterBuilder`. Two options:

  - **Option 1 (minimum-change):** keep `MasterDetailScaffold` at `lib/app/layout/` and document in its dartdoc that "this scaffold is screen-composable; the master panel is a caller responsibility, not wired through the router." This makes the current placement explicit rather than implicit.
  - **Option 2 (move):** relocate `master_detail_scaffold.dart` (and arguably the whole trio) to `lib/core/ui/layout/`, since none of the three actually depends on `app/`-specific concerns (router, app shell). `lib/app/theme/` and `lib/app/router/` are the legit app-shell residents; layout primitives that take builders are more honestly "shared UI." The plan explicitly green-lit this move as the conditional alternative.

Either is defensible; what's not defensible is leaving the justification text ("the scaffold wires routes") in the plan when the implementation doesn't. Pick one, write a one-line ADR or in-file comment, and move on.

### Suggestions (nice-to-have)

**B.** `_EmptyState._filterIsEffectivelyEmpty` (`pokemon_list_screen.dart:456–462`) inspects `PokemonFilter`'s internal fields to decide which empty widget to show. A cleaner home is either (i) a getter on `PokemonFilter` itself (`bool get isEmpty`) so the View asks the domain object rather than introspecting it, or (ii) a flag on `PokemonListState` (`bool get hasEffectiveFilter`). Neither is a layer violation — domain entities can carry self-describing predicates — but it would let the View read declaratively. Low priority; the current code is correct and well-commented.

**C.** Consider whether `Breakpoint.of(context)` should rely on `MediaQuery.sizeOf(context)` vs the upcoming Flutter `SystemMouseCursors.maybeOf`-style "size-aware" inheritance. Not a layer issue, just future-proofing.

---

## 6. Verdict

**Architecture: clean — ready to merge.**

- 0 layer-separation violations.
- 0 dependency-direction violations.
- 0 new state-management concerns.
- 1 important call: tighten the rationale (or location) of `master_detail_scaffold.dart` so the plan's justification matches the implementation.
- 2 suggestions: domain-helper for `filterIsEmpty`, minor naming around `Breakpoints` vs `Breakpoint`.

The error/empty widget package is exactly what the plan promised — pure presentational, no Riverpod, no feature reach. The responsive primitives have a clean API. The detail-screen → list-screen import is intra-feature and unavoidable given the wrap approach the plan committed to (router rewrite was correctly deferred).
