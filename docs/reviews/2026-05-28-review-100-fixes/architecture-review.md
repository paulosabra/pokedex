# Architecture Review — review-100 fixes (2026-05-28)

Branch: `epic/presentation-layer`  
Base: `develop`  
Scope: unstaged working-tree diff (5-fix sweep for code-review-100 findings)

---

## Summary

This sweep consists of five targeted bug fixes: two state-reset corrections in
the ViewModel, one per-drain error-budget reset in the BackfillCoordinator, one
scroll-guard guard in the list screen, and a `context.go → context.push`
navigation correction in two widgets. The changes are entirely within the
`presentation/` layer (coordinators, view models, pages, widgets). No new
dependencies are introduced and no layer boundaries are crossed beyond the
pre-existing acknowledged deviation (`BackfillCoordinator` importing
`pokemonRepositoryProvider` from `data/`).

Bug fixes of this nature typically do not introduce architectural issues, and
four of the five fixes reviewed here are architecturally clean. One issue was
found: the `context.go → context.push` fix in `pokemon_card.dart` was applied
only to the skeleton card branch, leaving the hydrated card branch using
`context.go`, creating inconsistent navigation semantics between two code paths
that are supposed to behave identically.

---

## Critical

_None._

---

## Important

### I-1 — Incomplete `context.go → context.push` fix in `pokemon_card.dart`

**File:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart`  
**Lines:** 42 (fixed) vs. 53 (unchanged)

The diff changed only the `_SkeletonPokemonCard` branch's `onTap` from
`context.go` to `context.push`. The `core.PokemonCard` branch immediately below
(line 53) still uses `context.go`:

```dart
// Skeleton branch — FIXED
onTap: () => context.push('/pokemon/${pokemon.id}'),   // line 42

// Hydrated branch — STILL USES context.go
onTap: () => context.go('/pokemon/${pokemon.id}'),     // line 53
```

`context.go` replaces the entire navigation stack, discarding the back-stack and
preventing the user from returning to the list. This is the exact behavior the
fix was intended to correct. The two branches render the same tap target (a list
card) and must share identical navigation semantics. As the skeleton card
upgrades to a hydrated card mid-session (once backfill completes), the user
would encounter differing back-button behavior depending on which render cycle
produced the card they tapped — a subtle but real regression.

**Recommended action:** Change line 53 to `context.push`:

```dart
onTap: () => context.push('/pokemon/${pokemon.id}'),
```

The companion test added in `pokemon_card_test.dart` targets the skeleton path
only (via `_skeleton`). A second test for the hydrated card variant should be
added to prevent this from silently regressing again.

---

## Suggest

### S-1 — `_enterBrowse` intermediate state is observable

**File:** `lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`  
**Lines:** 314–322

The fix correctly restores `hasMore: true` before calling
`_subscribeBrowseStream`, so the `loadMore` guard is unblocked in the race
window between `_enterBrowse` returning and the stream's first event. The
intermediate `AsyncData(current.copyWith(hasMore: true))` emission is observable
to any widget watching the provider in that microtask window.

This is architecturally sound — the stream listener immediately overwrites this
state, the test coverage confirms the intended contract, and any widget reacting
to `hasMore` alone (without also checking `isDiscovery`) would have been
broken before this fix too. No action is required; noting for awareness.

---

## Approved

The following four fixes are architecturally correct with no concerns:

**Fix 1 — `refresh()` resets `isLoadingMore` on all paths**  
`lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`  
Adds `isLoadingMore: false` to every `copyWith` call inside `refresh()` (both
discovery and browse, both `Ok` and `Err` branches). State is fully owned by the
ViewModel; all mutations go through `copyWith` on the Freezed state record.
Immutability contract preserved. Single source of truth maintained.

**Fix 2 — `_enterBrowse` restores `hasMore: true` before stream subscription**  
`lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`  
Restores the browse-mode invariant that discovery teardown violated. The mutation
is a `copyWith` on the existing `AsyncData` value — no new state shape, no
leaked internal fields.

**Fix 3 — `BackfillCoordinator._drain()` resets `_consecutiveErrors` at drain start**  
`lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart`  
`_consecutiveErrors` is a private field of the coordinator; the reset is an
internal bookkeeping correction that does not alter the coordinator's public
`BackfillProgress` state model or its provider interface. The error budget
remains session-scoped from the halt-check perspective (`isHaltedThisSession` is
not reset) and per-drain from the accumulation perspective — a semantically
correct tightening of the spec comment "session error budget". No layer
boundaries affected.

**Fix 4 — `_onScroll` guard against `maxScrollExtent == 0`**  
`lib/features/pokemon/presentation/pages/pokemon_list_screen.dart`  
A presentation-only scroll guard. The condition `pos.maxScrollExtent > 0 &&
pos.pixels >= pos.maxScrollExtent` is evaluated in the scroll listener, which
lives entirely in the view layer. The ViewModel's `loadMore()` already has its
own `isLoadingMore || !hasMore || isDiscovery` guard as a second line of
defence; this fix prevents the spurious call from ever reaching the ViewModel
in the first place. Correct separation of concerns.

**Fix 5 (partial) — `context.go → context.push` in `evolution_tab.dart`**  
`lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart`  
The `_StageCard.build` `onTap` is now `context.push`. Navigation intent
(`push` vs `go`) is a presentation-layer concern; no layer boundary is crossed.
The fix is complete for this file.

---

_Reviewed by architecture-review agent — 2026-05-28_
