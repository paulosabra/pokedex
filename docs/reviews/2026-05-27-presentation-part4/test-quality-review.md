---
date: 2026-05-27
type: review
scope: test-quality
pr: feature/presentation-part4
reviewer: test-quality-review-agent
---

# Test Quality Review — PR4: Errors + Responsive

## Coverage Summary

- **Test run**: Pass (all suites green, `very_good_cli` MCP runner)
- **Coverage**: All 11 new/modified test files present and compiling
- **Files with tests**: 11/11 scoped files covered
- **Missing test files**: none for declared scope

---

## State Widget Test Quality

### `offline_error_widget_test.dart` — Pass with minor issue

3 behavior tests + 1 golden.

**Positive**: callback tap test is crisp (counter assertion); override-message path covered; golden pinned at DPR-neutral size.

**Issue (Important)**: The "renders message and Retry button" test asserts the icon and button label but **never asserts the default message body text**. The production default is `"You're offline and no Pokémon are cached. Check your connection and try again."`. If that copy regresses to an empty string or is accidentally removed, the test stays green.

Fix: add `expect(find.textContaining("You're offline"), findsOneWidget)` to the first test case.

**Issue (Suggestion)**: The `retryLabel` override parameter (`retryLabel: 'Back'`) is exercised by the detail screen's integration path but has no unit-level test in this file. The widget accepts `retryLabel` as a first-class constructor parameter — a test asserting the custom label appears on the button documents the contract and prevents future parameter renaming from silently breaking the screen.

---

### `stale_cache_banner_test.dart` — Pass

2 behavior tests + 1 golden. Default message text IS asserted (`"You're offline — showing saved data."`). Override message covered. Golden sized at 400×60 (compact banner shape). No issues.

---

### `empty_search_widget_test.dart` — Pass

3 behavior tests + 1 golden. Query embedded in message text asserted verbatim. Null-`onClear` path (CTA absent) tested. Callback fires tested. Golden uses a realistic `mewthree` query. No issues.

---

### `empty_filter_widget_test.dart` — Pass

3 behavior tests + 1 golden. Canonical message text asserted. Null-`onClear` path tested. Callback fires tested. No issues.

---

### `empty_generation_widget_test.dart` — Pass

3 behavior tests + 1 golden. Generic ("this generation") message and labelled ("Gen 3") message both asserted. Retry callback tested. Golden uses a realistic `Gen 1` label. No issues.

---

### `generic_error_widget_test.dart` — Pass with minor issue

3 behavior tests + 1 golden.

**Positive**: default message, override message, and callback all tested.

**Issue (Suggestion)**: Same as `offline_error_widget_test.dart` — the `retryLabel` override is not unit-tested here, even though the detail screen renders `GenericErrorWidget(retryLabel: 'Back', ...)`. Covered by integration path but the widget's own contract test is incomplete.

---

## Layout Test Quality

### `breakpoints_test.dart` — Pass

5 tests across `fromWidth` (599, 600, 1023, 1024, 2000) + 1 widget test for `Breakpoint.of`. All boundary edges covered correctly (inclusive thresholds at 600 and 1024 explicitly verified). The 0-width and negative-width edge cases are not tested, but these are defensive and the spec does not require them. No issues.

---

### `responsive_layout_test.dart` — Pass with one coverage gap

6 tests: gridColumns for all 3 breakpoints, compact→sheet, medium→dialog, blocker-8 invocation-time sampling.

**Issue (Important)**: The `showSheetOrDialog` tests cover **compact** (shows BottomSheet) and **medium** (shows dialog). The blocker-8 invocation-time test uses an _existing_ sheet by resizing from compact to expanded — it does not independently verify that **expanded viewport on first invocation** opens a dialog. If the implementation branched on `Breakpoint.medium` equality instead of `!= Breakpoint.compact`, this set of tests would still pass. A dedicated test at width ≥ 1024 that opens the modal and asserts `BottomSheet` is absent would close this gap.

Fix: add a `testWidgets('renders a dialog on expanded viewports', ...)` case with `_setLogicalSize(tester, const Size(1300, 800))`.

---

### `master_detail_scaffold_test.dart` — Pass with one omission

3 behavior tests: compact renders child-only, medium renders child-only, expanded renders both panels in a `Row`.

**Issue (Suggestion)**: The plan's PR4 test surface table calls for a golden test for the master-detail layout. No golden is present in this file, and no `goldens/` directory exists under `test/app/layout/`. The responsive integration golden (`detail_screen_expanded.png`) partially captures the two-panel result, but a dedicated `MasterDetailScaffold` golden with known content would catch regressions to the panel sizing (the 40/60 flex split) independently of the full screen.

**Issue (Suggestion)**: The `masterFlex` / `childFlex` constructor parameters have no tests — neither a behavioral assertion that the master panel is narrower than the child panel, nor a test covering non-default flex values. Low priority because the screen golden indirectly validates the split.

---

## Screen Test Quality

### `pokemon_list_screen_test.dart` (modified) — Pass with two gaps

11 tests in 2 groups: screen states + sheet openers.

**Positive**:
- TE-01 (`OfflineErrorWidget` on `NetworkFailure`) — covered.
- TE-03/06/07/09 (`GenericErrorWidget` on `ServerFailure`) — covered.
- RN-15 (`EmptyGenerationWidget` when `generationId` set + empty results) — covered.
- TE-02 (stale cache banner over visible cards) — covered AND asserts `PokemonCard` still present. This satisfies focus area 2 directly.
- TE-04 / TE-05 (empty search and empty filter) — covered from PR2 baseline.
- blocker-3 scroll preservation — covered.
- Sheet openers wired to correct sheet types — covered.
- Sort-dispatch `verify()` at line 409 — justified: the only observable behavioral signal is that `findPokemon` is called with the correct `SortCriteria`. The sort state change is not directly visible without scrolling to confirm re-rendered items, so the mock-interaction verify is the least-brittle option here.

**Issue (Important — gap in `_EmptyState` branch coverage)**: The `_EmptyState._filterIsEffectivelyEmpty` helper gates the `EmptyGenerationWidget` vs `EmptyFilterWidget` choice. There are **two untested sub-branches**:

1. `generationId != null` AND an **active type/weakness filter** is also set → `_filterIsEffectivelyEmpty` returns `false` → falls through to `EmptyFilterWidget`. The existing generation test clears the filter (uses the factory default), so this path is never exercised in tests.
2. The **defensive fallback** `GenericErrorWidget` at line 311–315 in `_Body` (`state == null` after the loading and error guards) is impossible to reach from the normal Riverpod state machine but exists for `PRD §8.1` compliance. It is untested by any test. Given it is a PRD §8.1 defensive guard rather than a normal code path, this is acceptable to leave untested, but it is worth documenting.

Fix for gap 1: add a test that sets both `selectGeneration(2)` and `applyFilter(PokemonFilter(types: {PokemonTypeId.fire}))` with a zero-result `findPokemon`, then asserts `EmptyFilterWidget` (not `EmptyGenerationWidget`).

**Issue (Suggestion)**: The `CacheFailure` branch in `_Body` is not directly tested. Production code maps `CacheFailure` to `OfflineErrorWidget` (same as `NetworkFailure`). One focused test covering `Err(CacheFailure())` → `OfflineErrorWidget` would make the sealed-class exhaustion explicit.

---

### `pokemon_list_screen_responsive_test.dart` — Pass with assertion depth gap

3 golden tests: compact (400 px), medium (800 px), expanded (1200 px).

**Positive**: DPR pinned to 1 in `_pumpAt`, so physical pixels = logical pixels. The comment in the file explicitly explains this, which is good practice.

**Issue (Important — column count not asserted structurally)**: The medium and expanded tests assert `find.byType(GridView)` but do NOT assert the column count (`crossAxisCount`). A golden image captures the visual result, but goldens can be regenerated accidentally with `--update-goldens`. A structural assertion like:

```dart
final grid = tester.widget<GridView>(find.byType(GridView));
final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
expect(delegate.crossAxisCount, 2); // medium
```

would catch a `gridColumns()` regression that the golden comparison might miss on a partial rebaseline. The compact test asserts `ListView` (no grid), which is a meaningful structural assertion.

**Issue (Suggestion)**: The `_pumpAt` helper does not mock `FindPokemon`, causing the mock to be unconfigured. The current implementation does not exercise the discovery path, so this is harmless. However, if the screen changes to call `findPokemon` on initial load, these tests will throw `MissingStubError`. Adding a no-op stub is defensive hygiene.

---

### `pokemon_detail_screen_responsive_test.dart` — Pass with DPR inconsistency note

2 golden tests: compact (400 px, detail alone) and expanded (1300 px, master+detail).

**Positive**: DPR pinned to 1 via `tester.view.physicalSize` + `tester.view.devicePixelRatio = 1`. Goldens exist for both breakpoints. The expanded test proves `PokemonListScreen` mounts in the master panel, which is a behavioral assertion on top of the golden.

**Issue (Important — inconsistency with `pokemon_detail_screen_test.dart`)**: The **non-responsive** `_pumpScreen` helper in `pokemon_detail_screen_test.dart` uses `tester.binding.setSurfaceSize(size)` without pinning DPR. `setSurfaceSize` sets physical pixels; at the test default DPR (documented in this repo as 3.0), a `setSurfaceSize(420, 1000)` call produces a **logical width of ~140 px**, not 420 px. The `MasterDetailScaffold` stays compact at 140 logical px so this does not trigger the two-panel layout, but any assertion that depends on the card fitting its intrinsic minimum width (commented concern in `pokemon_list_screen_test.dart` line 102–103) applies equally here.

The non-responsive detail tests do not exercise any breakpoint-sensitive UI so this is not currently a failing test — but the helper is inconsistent with the rest of the codebase. Future tests added to `pokemon_detail_screen_test.dart` that rely on a specific logical width will silently get a 3x-smaller viewport.

Fix: align `_pumpScreen` in `pokemon_detail_screen_test.dart` to use `tester.view.devicePixelRatio = 1` + `tester.view.physicalSize = size`, matching `_pumpAt` in the responsive companion.

---

## Anti-Patterns Found

None of the classic anti-patterns (tautological assertions, testing mocks, empty tests, no-assertion tests) were found. The `verify()` call at `pokemon_list_screen_test.dart:409` is justified behavioral verification, not over-verification, because the outcome of a correct `changeSort` dispatch is visible only through a secondary use-case call that the test correctly intercepts.

---

## Coverage Gap Summary Table

| File | Branch / Path | Status |
|------|---------------|--------|
| `pokemon_list_screen_test.dart` | `generationId != null` + active filter → `EmptyFilterWidget` | **Not tested** |
| `pokemon_list_screen_test.dart` | `CacheFailure` → `OfflineErrorWidget` | **Not tested** |
| `responsive_layout_test.dart` | Expanded breakpoint → dialog on first invocation | **Not tested** |
| `offline_error_widget_test.dart` | Default message body text | **Not tested** |
| `offline_error_widget_test.dart` / `generic_error_widget_test.dart` | `retryLabel` override | **Not tested** (integration path only) |
| `master_detail_scaffold_test.dart` | Golden for two-panel layout | **Not present** |
| `pokemon_list_screen_responsive_test.dart` | Structural column-count assertion (medium, expanded) | **Not tested** |
| `pokemon_detail_screen_test.dart` | `_pumpScreen` DPR not pinned | **Inconsistency** |

---

## Recommendations

1. **(Important — before merge)** Add the `generationId + active filter → EmptyFilterWidget` test to `pokemon_list_screen_test.dart`. This is a real, testable branch in `_EmptyState._filterIsEffectivelyEmpty` that is never exercised, meaning a regression there would ship silently.

2. **(Important — before merge)** Add a `renders a dialog on expanded viewports` test to `responsive_layout_test.dart` at width ≥ 1024, so the sheet/dialog contract is verified for all three breakpoints independently.

3. **(Important — before merge)** Add a structural `crossAxisCount` assertion in `pokemon_list_screen_responsive_test.dart` for the medium (2-column) and expanded (3-column) cases. The goldens alone are insufficient protection against a `gridColumns()` regression that gets hidden on a rebaseline.

4. **(Suggestion — can defer)** Pin `devicePixelRatio = 1` in `pokemon_detail_screen_test.dart`'s `_pumpScreen` helper for consistency with all other size-sensitive tests in the project.

5. **(Suggestion — can defer)** Add a `retryLabel` override test to `offline_error_widget_test.dart` and `generic_error_widget_test.dart` to fully document the constructor's public contract.

6. **(Suggestion — can defer)** Add `expect(find.textContaining("You're offline"), findsOneWidget)` to the "renders message" test in `offline_error_widget_test.dart` so the default copy is asserted.

7. **(Suggestion — can defer)** Add a golden under `test/app/layout/goldens/` in `master_detail_scaffold_test.dart` for the expanded two-panel state, as called for by the plan's PR4 test surface table.

---

## Verdict

**Fix 3 important issues before merging.**

The test surface is well-structured: VGV patterns are applied consistently (ProviderScope overrides, mocktail, DPR=1 pinning in responsive tests, behavioral assertions over implementation details), all six AC-required error/empty state widgets have widget tests, the stale-cache-banner-over-cards integration scenario is covered, and the RN-15 EmptyGenerationWidget path is exercised. The golden baseline exists for all screen breakpoints.

The three issues flagged as Important each represent a testable production branch or API contract that is currently invisible to CI: the `generationId+filter` disambiguation branch in `_EmptyState`, the `expanded` breakpoint dialog contract in `showSheetOrDialog`, and the absence of structural column-count assertions in the responsive list test. None are regressions of existing behavior, but all three would allow silent failures in future changes to the respective code paths.
