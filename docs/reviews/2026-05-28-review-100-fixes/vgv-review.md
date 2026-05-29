# VGV Engineering Review — review-100 fixes (2026-05-28)

Scope: unstaged working-tree diff only (`git diff`).
Branch: `epic/presentation-layer`.
Standards applied: layer separation (presentation never imports data), Riverpod
conventions, naming, state management correctness, dependency direction,
simplicity, test coverage.

---

## Critical

### Fix #5 is half-applied: hydrated `PokemonCard` still calls `context.go`

**File:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart`, line 53

The diff fixes the skeleton branch (`_SkeletonPokemonCard`, line 42) from
`context.go` to `context.push`, but leaves the non-skeleton (`core.PokemonCard`)
branch unchanged:

```dart
// line 53 — unchanged by the diff, should be context.push
onTap: () => context.go('/pokemon/${pokemon.id}'),
```

Every hydrated card tap replaces the navigation stack, so pressing system-back
on a detail screen closes the app (or goes nowhere) rather than returning to the
list. This is the same root bug as #5 and it affects the overwhelmingly common
path (almost all cards in the list are hydrated once backfill runs).

The new test in `pokemon_card_test.dart` covers `_skeleton` only; the existing
hydrated-card tap test (`'tap navigates to /pokemon/<id>'`) checks only the
destination URL, not `canPop()`, so CI stays green while the bug is present.

**Action:** Change line 53 to `context.push('/pokemon/${pokemon.id}')`.
Add a `canPop` assertion (mirroring the skeleton test) to the existing
hydrated-card tap test group.

---

## Important

### `_enterBrowse` unconditionally restores `hasMore: true`

**File:** `lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`, line 320

```dart
state = AsyncData(current.copyWith(hasMore: true));
```

The restore is unconditional: if the user reached the final browse page
(`hasMore: false`), briefly entered discovery (e.g., typed then immediately
cleared), and returned to browse, `hasMore` is reset to `true`. The next
`_subscribeBrowseStream` emit will not correct it (the stream listener only
touches `items` and `offset`), so `loadMore` will fire an extra fetch that
returns an empty page and sets `hasMore: false` again — a redundant network
round-trip.

The fix is low-risk and this is not a regression introduced by this diff (the
field was always `true` at construction), but the explicit set makes the
invariant visible and the edge case reachable.

**Action:** Carry the prior `hasMore` unless the prior mode was definitely
discovery with no previously fetched page, or alternatively let the browse
stream's first emission overwrite whatever `loadMore` fetches. A safe one-liner:

```dart
// Only restore if we're actually coming out of discovery's `hasMore: false`
if (!current.hasMore) {
  state = AsyncData(current.copyWith(hasMore: true));
}
```

No new test needed if the fix is applied, but a regression test for the
"full-catalogue → discovery → back to browse does not re-fetch last page" path
would make the invariant explicit.

---

## Suggest

### Backfill test: named-param `when` stub is dead code

**File:** `test/features/pokemon/presentation/coordinators/backfill_coordinator_test.dart`, lines 238–251 and 267–278

Each drain setup registers two stubs for `listMissingSummaryIds`: one with
`limit: any(named: 'limit')` and one with no args. The no-arg form (lines
249–251, 278) overwrites the named-param form for the zero-arg callsite in
`_drain()`. The `firstCall`-toggling stub in the named-param form is never
exercised because `_drain()` calls `listMissingSummaryIds(limit: _chunkSize)`
for the chunk and `listMissingSummaryIds()` for the opening count — two
different call signatures that mocktail resolves to separate stubs. The test
still proves the bug (the no-arg stub drives the opening-count path) but the
named-param stubs with the `firstCall` flag are unreachable.

**Action:** Remove the named-param `when` stubs (lines 238–248 and 267–276).
The no-arg stubs are sufficient. If the `limit:` callsite needs distinct
behavior in a future test, stub it explicitly and document why.

### `pokemon_list_screen.dart` comment over-explains the guard

**File:** `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart`, lines 76–77

The two-line comment is accurate but verbose for an audience familiar with
`ScrollPosition`. A single clause is enough.

**Action (optional):** Trim to:
```dart
// Guard: skip when the list fits in the viewport (maxScrollExtent == 0).
if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent) {
```

Not a blocker; keep the current form if the team prefers it.

---

## Approved

The following changes are correct, minimal, and consistent with VGV conventions.
No concerns.

- **`pokemon_list_view_model.dart` — `isLoadingMore: false` in all four refresh
  branches.** Fixes the state leak cleanly without introducing a helper or a new
  state field. All four affected `copyWith` call-sites are updated; the Err and
  Ok paths are symmetric.

- **`pokemon_list_view_model.dart` — `_enterBrowse` sets `hasMore: true` before
  `_subscribeBrowseStream`.** Correct placement: the race window between
  `_applyMode` returning to browse and the stream emitting its first event is
  real, and the one-liner is the smallest possible fix. The comment explains the
  precondition clearly.

- **`backfill_coordinator.dart` — `_consecutiveErrors = 0` at drain start.**
  Placed correctly: after the connectivity gate (so a short-circuit does not
  reset the budget) and before the first repository call. No new parameter,
  no callback, no lifecycle bloat.

- **`pokemon_list_screen.dart` — `maxScrollExtent > 0` guard.** The condition
  is the minimal fix for the spurious `loadMore` on layout. The inline comment
  explains *why* the guard is needed (not just what it does), which is the right
  level of documentation for a non-obvious `ScrollPosition` edge case.

- **`evolution_tab.dart` — `context.go → context.push`.** One-site, minimal.
  The accompanying test uses `router.canPop()` — the sharpest possible
  observable for push-vs-go semantics.

- **Test: `pokemon_list_view_model_test.dart` — `isLoadingMore` reset (Ok and
  Err paths).** Two separate tests with `Completer`-based in-flight hangs cover
  both branches without shared state. Structure and naming are clear.

- **Test: `pokemon_list_view_model_test.dart` — discovery→browse `hasMore`
  race window.** Three-phase test (enter discovery → return to browse → attempt
  `loadMore`) directly exercises the race window. Mock interactions confirm that
  a page fetch is actually issued, not just that `hasMore` is `true`.

- **Test: `pokemon_list_screen_test.dart` — `maxScrollExtent == 0` guard.**
  Uses `verify(...).called(1)` + `verifyNever(...)` — no custom matchers, no
  harness additions. Minimum viable test for the fix.

- **Test: `evolution_tab_test.dart` — back-stack preservation.** Inline router
  construction avoids shared state. `router.canPop()` is the precise contract
  assertion. The `await tester.pump()` (not `pumpAndSettle`) is correct — back-
  stack state is synchronous.

- **Test: `pokemon_card_test.dart` — skeleton back-stack preservation.** Mirrors
  `evolution_tab_test.dart` structure. Covers the skeleton branch correctly.

---

## Summary

**One Critical:** Fix #5 (`context.go → context.push`) was applied only to the
skeleton branch of `PokemonCard`; the hydrated branch at line 53 still calls
`context.go`. This is the dominant code path and the existing test does not
catch it. Must be corrected before merge.

**One Important:** `_enterBrowse` restores `hasMore: true` unconditionally,
which can trigger a redundant last-page fetch after a browse→discovery→browse
round-trip on a fully-loaded catalogue. This is not a regression from this diff
but the explicit set makes the latent edge visible. Recommend a conditional
guard.

**Two Suggests:** dead-code `when` stubs in the backfill test, and an overly
verbose scroll-guard comment — both optional cleanups.

Everything else is clean. The four production fixes are minimal, correctly
placed, and consistent with the existing state-management style. Test coverage
for the new behavior is thorough for the addressed sites.
