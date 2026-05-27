---
date: 2026-05-27
branch: feature/presentation-part2
reviewer: test-quality-review-agent
---

# Test Quality Review — PR2 (presentation-part2)

## Coverage Summary

- **Test run**: Pass (all 49 new tests + existing suite green)
- **VM coverage**: 97.6% (122/125 lines) — 3 lines uncovered
- **Screen coverage**: 68.7% (79/115 lines) — 36 lines uncovered
- **FiltersSheet coverage**: 94.3% (100/106 lines) — 6 lines uncovered
- **SortSheet coverage**: 100%
- **GenerationsSheet coverage**: 100%
- **PokemonCard adapter coverage**: 100%
- **Missing test files**: None. Every file added in PR2 has a corresponding test file.

---

## Plan AC Coverage Mapping

| AC | Status |
|---|---|
| deep-link smoke green | Covered (`app_boot_test.dart`, `pokemon_list_screen_test.dart:146`) |
| `_composeFilter()` unit test | Covered (`pokemon_list_view_model_test.dart:534`) |
| `AsyncLoading.copyWithPrevious` preserves UI inputs (blocker 1) | Covered (`pokemon_list_view_model_test.dart:279`) |
| Discovery-refresh: `getPokemonList` THEN `findPokemon` (blocker 2) | Covered (`pokemon_list_view_model_test.dart:449`) |
| Scroll-position preservation on stream emission (blocker 3) | Covered (`pokemon_list_screen_test.dart:178`) |
| 5-rapid-flip leak test (blocker 7) | Covered (`pokemon_list_view_model_test.dart:485`) |
| Debounce coalesces rapid search | Covered (`pokemon_list_view_model_test.dart:256`) |
| TE-04 empty search rendered | Covered (`pokemon_list_screen_test.dart:155`) |
| TE-05 empty filter rendered | **Partially covered** — see Blocker 1 |
| Pull-to-refresh browse | Covered at VM level (`pokemon_list_view_model_test.dart:412`) |
| Pull-to-refresh discovery | Covered at VM level (`pokemon_list_view_model_test.dart:449`) |
| Stream emission replaces items + resyncs offset | Covered (`pokemon_list_view_model_test.dart:205`) |
| TE-11 image placeholder | Covered in `core/ui/components/pokemon_card_test.dart` (correct level) |

---

## Blockers

### Blocker 1 — TE-05 empty-filter path not tested at screen level
**File**: `test/features/pokemon/presentation/pages/pokemon_list_screen_test.dart`

The plan AC explicitly lists "TE-05 (empty filter) rendered" as a PR2 deliverable
(`docs/plan/2026-05-26-feat-presentation-layer-plan.md:666`). The TE-04 path (empty
search) has a widget test. The TE-05 path (`_EmptyBlock._message()` returning
`'No Pokémon match the current filters.'` when `query` is empty but `filter != null`)
does not. The two messages differ and are selected by a conditional, so TE-04's
test does not cover TE-05.

The missing case: pump the screen with a filter active and `findPokemon` returning
`Ok(<Pokemon>[])`, confirm `find.text('No Pokémon match the current filters.')`
appears. A single `testWidgets` covers this in under 20 lines.

---

### Blocker 2 — Discovery refresh `findPokemon` failure path is dead code in tests
**File**: `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`  
**VM lines**: 171–173 (confirmed uncovered by `lcov`)

`refresh()` in discovery mode has two `findPokemon` outcome branches
(`pokemon_list_view_model.dart:160`):

- `Ok` — sets `refreshError` to the page-level failure (if any), tested.
- `Err` — sets `refreshError` to the find failure, **not tested**.

The discovery-refresh test (`pokemon_list_view_model_test.dart:449`) only exercises
the `Ok` path. If `findPokemon` returns `Err` during a discovery refresh, the VM
sets `refreshError` from the find failure (not the page failure). That branch is
live code, already shipped, and completely unverified. The plan blocker 2 AC tests
call order only; it does not touch the failure branch.

Add a `test` that:
1. Enters discovery mode.
2. Stubs `findPokemon` to return `Err(CacheFailure())`.
3. Calls `refresh()`.
4. Asserts `state.refreshError` is a `CacheFailure` and `state.isRefreshing` is `false`.

---

## Fixes

### Fix 1 — `isNotNull` assertion on `filter` is weaker than it should be
**File**: `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart:306`

```dart
expect(async.value!.filter, isNotNull);
```

This confirms the filter field is set during the `AsyncLoading` phase but does not
verify it equals the specific filter the test applied
(`PokemonFilter(types: {PokemonTypeId.fire})`). If `copyWithPrevious` accidentally
preserved a stale filter from a previous test frame, `isNotNull` would still pass.
Replace with the concrete value:

```dart
expect(async.value!.filter, const PokemonFilter(types: {PokemonTypeId.fire}));
```

---

### Fix 2 — Weaknesses toggle path (`_toggleWeakness`) is never exercised
**File**: `test/features/pokemon/presentation/widgets/sheets/filters_sheet_test.dart`  
**Sheet lines**: 52–58 (confirmed uncovered by `lcov`)

All filter-sheet tests tap the **Types** section or the **Heights** section. The
Weaknesses `_TypeChipGrid` is rendered and the section header is asserted
(`findsOneWidget`), but no test selects a weakness type. If `_toggleWeakness` were
deleted or its logic inverted, all sheet tests would still pass.

Add one case: tap a weakness type, apply, and assert `result.weaknesses` is non-empty
with the expected type. This can replace or extend the existing "selecting types"
test with a weaknesses variant.

---

### Fix 3 — Scroll-position test accesses controller through widget tree inspection
**File**: `test/features/pokemon/presentation/pages/pokemon_list_screen_test.dart:185–189`

```dart
final scrollable = tester.widget<GridView>(find.byType(GridView));
final controller = scrollable.controller;
```

This reads the `ScrollController` from the `GridView`'s `controller` property via
the widget tree. It works because `_PokemonGrid` is wired to receive the same
`_scrollController` instance, but it couples the test to the widget's internal prop
rather than to the observable output (scroll offset). The `expect` on `pixels` is
the right behavioral assertion — the approach to obtain the controller is the
brittle part. If the implementation ever wraps `GridView` in an intermediate widget
or renames the controller field, this lookup silently yields the wrong object.

Prefer capturing a reference to the `ScrollController` through a test seam: inject
it as a parameter to `_pumpScreen`, pass it into the `ProviderScope` override, or
use `find.byKey(const PageStorageKey<String>('pokemon-list-grid'))` with
`tester.scrollController(...)` to retrieve it. The current approach does not
constitute a real bug today, but it is the most fragile assertion in the PR.

---

### Fix 4 — Sort golden uses the default (all-unchecked) state
**File**: `test/features/pokemon/presentation/widgets/sheets/sort_sheet_test.dart:98–104`

The golden is captured with `initial: SortCriteria.numberAsc`. This renders the
sheet with the first radio checked and the others unchecked — the same visual state
as any default rendering. A golden at a non-default selection (e.g., `nameAsc` or
`nameDesc`) would catch regressions in the selected-state styling (bold label,
checked icon color). The existing "initial option is rendered as selected" test
verifies selection logic but the golden does not capture the visual distinction.
Add a second golden at `initial: SortCriteria.nameAsc`.

---

## Suggestions

### Suggest 1 — `isRefreshing` in-flight state is never asserted
**File**: `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`

Both refresh tests confirm `isRefreshing == false` after the call returns. Neither
test observes `isRefreshing == true` while the refresh is in flight. The
`copyWithPrevious`/`AsyncLoading` test for `applyFilter` demonstrates the right
technique (hang the use case with a `Completer`, assert mid-flight state). Applying
the same pattern to `refresh()` would verify the `state.isRefreshing = true` line
and give confidence that the UI's `RefreshIndicator` receives the correct signal.

---

### Suggest 2 — `selectGeneration(null)` → browse path is not standalone-tested
**File**: `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`

The discovery-to-browse return path is tested only via `applyFilter(null)`. The
`selectGeneration(null)` clear path goes through the same `_applyMode()` code but
there is no test that enters discovery via `selectGeneration(2)`, then clears with
`selectGeneration(null)`, and asserts `isDiscovery == false` + `cacheController.hasListener == true`.
This mirrors the existing "discovery → browse resubscribes the stream" test and
adds one more axis of confidence cheaply.

---

### Suggest 3 — No screen-level test for sheet-opener icon buttons
**File**: `test/features/pokemon/presentation/pages/pokemon_list_screen_test.dart`

The three methods `_openFilters`, `_openSort`, and `_openGenerations` (screen lines
62–90) are entirely uncovered at the screen level. The sheets themselves are tested
in isolation, and the VM methods they ultimately call are tested, but the wiring
from icon-button tap → `showModalBottomSheet` → `applyFilter`/`changeSort`/`selectGeneration`
is never exercised end-to-end. A test tapping the Filters button (`find.byTooltip('Filters')`)
and asserting the `FiltersSheet` appears would cover this gap and would catch a future
button-callback regression that the VM and sheet tests in isolation cannot.

---

### Suggest 4 — No widget test for the `isLoadingMore` footer spinner
**File**: `test/features/pokemon/presentation/pages/pokemon_list_screen_test.dart`

`_PokemonGrid` appends a `CircularProgressIndicator` item when `state.isLoadingMore`
is `true` (screen lines 218, 231–233). This state is only verified at the VM level.
A one-case widget test seeding `isLoadingMore: true` and asserting
`find.byType(CircularProgressIndicator)` at the grid level would close the gap.

---

### Suggest 5 — `browse refresh sets refreshError` test does not verify items are preserved
**File**: `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart:431`

When a browse refresh fails, the spec (and implementation) intentionally keeps
`state.items` intact so the user sees stale data with an error banner rather than
a blank screen. The test asserts `refreshError` is a `NetworkFailure` but does not
assert `state.items.length == 24` (the pre-refresh page). Without this assertion, a
regression that blanks `items` on a failed refresh would not be caught.

---

## Notes

### Note 1 — VM tests use `Future.delayed` with real timers
All 21 VM tests use plain `test()` with `await Future<void>.delayed(_overDebounce)`
to advance the debounce timer. This works because Dart's `Timer` fires when the
event loop processes it, and `await Future.delayed()` in a plain async test yields
long enough for the timer to fire on the test runner's real event loop.
`FakeAsync`/`fake_async` would be more hermetic but the current pattern is
standard for simple debounce testing in Riverpod suites and is not a flakiness risk
in CI under normal load.

---

### Note 2 — `app_boot_test.dart` has an unstubbed `MockFindPokemon`
`_setupListMocks()` constructs a `_MockFindPokemon` and overrides
`findPokemonProvider` with it, but never stubs a `when()` response
(`app_boot_test.dart:51,83`). This is safe today because the first test renders
`PokemonListScreen` in browse mode, which never calls `findPokemon`. If a future
change to the screen's initial state triggers a discovery-mode entry, the test
would throw a `MissingStubError` immediately — which is the desired fail-fast
behavior. No action required, but worth knowing the stub is intentionally absent.

---

### Note 3 — Golden path in plan AC differs from actual path
`docs/plan/2026-05-26-feat-presentation-layer-plan.md:670` says goldens should be
"self-baselined under `test/features/pokemon/presentation/goldens/`". The three
sheet goldens live at `test/features/pokemon/presentation/widgets/sheets/goldens/`,
which is the natural co-location with the test files. The goldens are real (32 KB
for filters, 5–6 KB for sort and generations — full sheet renders at 420px width),
self-baselined, and will catch visual regressions. The path discrepancy is a plan
typo, not an implementation error.

---

## Verdict

**Fix 4 issues before merging.**

Two Blockers prevent the PR2 ACs from being fully satisfied:

1. TE-05 empty-filter message has no widget test despite being an explicit PR2 AC.
2. The discovery-refresh `findPokemon` failure path is untested live code (3 lines,
   confirmed by `lcov`).

Two Fixes address brittle assertions: a weaker-than-intended `isNotNull` in the
`copyWithPrevious` test, and the weaknesses toggle that is silently never executed.

The remaining findings (Fix 3/4, Suggests 1–5, Notes 1–3) are improvements that
can be applied during or after remediation without blocking merge. The core VM
behaviour — all 8 plan blockers, `_composeFilter()`, debounce coalescing, leak
safety, and scroll preservation — is well-tested and the pattern quality is high.
