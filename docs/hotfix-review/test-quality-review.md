# Test Quality Review — fix/tests hotfix

**Branch:** `fix/tests`
**Reviewer:** Test Quality Agent (Claude Sonnet 4.6)
**Date:** 2026-05-28
**Scope:** Unstaged changes only (13 test files + 2 production files + 6 PNG goldens)

---

## Test Run Summary

- **Test suite:** All tests pass (very_good_cli test runner, full project).
- **Coverage:** 75.1% lines hit (3337 / 4441), excluding `*.g.dart` and `*.freezed.dart`.
- **Golden tolerance:** 1% pixel diff threshold (configured in `test/flutter_test_config.dart`).

---

## Coverage Summary

No new untested files introduced by the hotfix. The two production changes (`state_view.dart`, `sort_sheet.dart`) are exercised by existing golden and widget tests. Coverage metric is unchanged by this PR.

---

## Finding 1 — Golden regeneration targeted the wrong (non-canonical) directories [IMPORTANT]

**Files changed:**
- `test/core/ui/goldens/empty_filter_widget.png` (non-canonical)
- `test/core/ui/goldens/empty_generation_widget.png` (non-canonical)
- `test/core/ui/goldens/empty_search_widget.png` (non-canonical)
- `test/core/ui/goldens/generic_error_widget.png` (non-canonical)
- `test/core/ui/goldens/offline_error_widget.png` (non-canonical)
- `test/features/pokemon/presentation/widgets/goldens/sort_sheet.png` (non-canonical)

**Problem:** The golden image files regenerated in this hotfix live in directories that no test reads from. The actual test files resolve `matchesGoldenFile('goldens/...')` relative to their own source file location:

| Test file location | Canonical golden dir |
|---|---|
| `test/core/ui/states/*_test.dart` | `test/core/ui/states/goldens/` |
| `test/features/pokemon/presentation/widgets/sheets/sort_sheet_test.dart` | `test/features/pokemon/presentation/widgets/sheets/goldens/` |

The changed files are in `test/core/ui/goldens/` and `test/features/pokemon/presentation/widgets/goldens/` — mirror directories created in commit `a2a3dc5` that duplicate golden assets but are not referenced by any test. Regenerating them has no effect on whether the test suite passes or fails.

**Why tests still pass:** The `StateView` layout change (`Center` → `LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)`) is visually neutral at the `400×400` test surface. `ConstrainedBox` with `minHeight: constraints.maxHeight` combined with `mainAxisAlignment: MainAxisAlignment.center` produces the same pixel output as `Center` when the content fits. The canonical goldens in `test/core/ui/states/goldens/` are therefore still valid — they happen to match the new layout because both produce the same rendering.

For `sort_sheet.png`: the 3 px gap reduction (20→17) across three gaps = 9 px shift in a 1000 px surface = 0.9% pixel diff, which is below the 1% tolerance threshold. The canonical golden in `test/features/pokemon/presentation/widgets/sheets/goldens/sort_sheet.png` passes without regeneration.

**Risk:** The non-canonical directory is a persistent source of confusion. A developer running `flutter test --update-goldens` locally may regenerate into the wrong directory again, producing a false impression that goldens are up-to-date when the canonical files are stale.

**Recommendation:** The six updated non-canonical PNGs should **not** be staged for this commit. The canonical goldens in `test/core/ui/states/goldens/` and `test/features/pokemon/presentation/widgets/sheets/goldens/` are already correct. Separately, consider adding a comment or README in the mirror directories explaining that they are unused, or pruning them entirely.

---

## Finding 2 — `EmptyGenerationWidget` assertions under-specify the body content [IMPORTANT]

**Files:** `test/core/ui/states/empty_generation_widget_test.dart`

**'renders the generic message when no label is given':**
```dart
expect(find.textContaining('this generation'), findsOneWidget);
```
The production body is `'Pokémon for this generation are still being fetched. Refresh to load the missing entries.'`. The assertion only checks that the two-word phrase `'this generation'` is present somewhere in the widget tree. This would pass if the body were changed to anything containing those words (e.g., `'Error loading this generation.'`). The key behavioral invariant — that the fallback label appears inside a sentence about loading Pokémon — is not pinned.

**'embeds the supplied generation label in the message':**
```dart
expect(find.textContaining('Gen 3'), findsOneWidget);
```
This only verifies the label token appears somewhere. The intent is "label is interpolated into the body copy." A body like `'Gen 3 error occurred'` would pass. The unique part that proves interpolation is that `generationLabel` replaces `'this generation'` — neither the replacement nor the surrounding sentence is asserted.

**Contrast with other state widgets:** `EmptyFilterWidget` uses `find.textContaining('No Pokémon match the current filters.')` — the entire first sentence — which is specific enough to catch any substantial body rewrite. `EmptySearchWidget` uses `find.textContaining('"zzzz"')` — this pins quotation marks around the query, which is the minimal invariant for "query rendered verbatim with quoting."

**Recommendation:** Tighten the two `EmptyGenerationWidget` assertions to pin at least the clause that proves the label was interpolated:
```dart
// 'renders generic message'
expect(find.textContaining('Pokémon for this generation are still being fetched'), findsOneWidget);

// 'embeds the supplied generation label'
expect(find.textContaining('Pokémon for Gen 3 are still being fetched'), findsOneWidget);
```
These still survive copy tweaks to the trailing clause (`'Refresh to load...'`) while actually testing that the label was interpolated into the right sentence slot.

---

## Finding 3 — `textContaining` change for `EmptyFilterWidget` is correct but the comment misstates the reason [SUGGESTION]

**File:** `test/core/ui/states/empty_filter_widget_test.dart`, line 17–21

The comment says:
> "Body opens with the canonical 'no matches' sentence — we assert on the lead-in so copy tweaks past the first sentence don't break us."

This framing implies `textContaining` is a deliberate loosening for future-proofing. The actual reason is different and more important: `find.text('No Pokémon match the current filters.')` was **already broken** with the multi-sentence body string. The `Text` widget in `StateView` renders `'No Pokémon match the current filters. Tweak the selection or reset to start over.'` as a single string, so `find.text(firstSentenceOnly)` finds no widget. The switch to `textContaining` is a correctness fix, not an intentional loosening.

The comment should say: "The Text widget renders the entire multi-sentence body as one string, so `find.text()` with the first sentence alone finds nothing — `textContaining` is needed to match the substring."

This is a comment accuracy issue only; the assertion logic is correct.

---

## Finding 4 — `EmptySearchWidget` body assertion is narrower than the test name implies [SUGGESTION]

**File:** `test/core/ui/states/empty_search_widget_test.dart`

**Test name:** `'renders the query verbatim in the message'`

**Assertion:**
```dart
expect(find.textContaining('"zzzz"'), findsOneWidget);
```

The test name claims to verify the query is rendered "verbatim," but the assertion only checks that the quoted form `"zzzz"` appears somewhere. It doesn't verify that the quoting itself is correct — e.g. `'Result for zzzz found'` (no quotes) would fail, but `'something "zzzz" error'` would pass. The test DOES effectively pin that the query is quoted, which is the design intent, but the test name over-promises. Consider renaming to `'embeds the quoted query in the message body'`.

This is cosmetic; the assertion is sufficient to catch a regression where the query is dropped from the body entirely.

---

## Finding 5 — drag-to-dismiss substitution loses one behavior: barrier-tap vs programmatic pop [IMPORTANT]

**Files:** `test/features/pokemon/presentation/widgets/sheets/sort_sheet_test.dart`, `generations_sheet_test.dart`, `filters_sheet_test.dart`

**Pattern:**
```dart
// Before
await tester.tapAt(const Offset(10, 10));
// After
Navigator.of(tester.element(find.byType(SortSheet))).pop();
```

**What is retained:** Both approaches result in `showModalBottomSheet` returning `null` (no pop value). The contract verified — "dismissing without selecting returns null" — is preserved.

**What is lost:** The original `tester.tapAt(Offset(10, 10))` was testing that tapping **outside the sheet content** dismisses it. This exercises the modal barrier's `barrierDismissible` flag. The replacement pops the route programmatically, bypassing the barrier hit-test chain entirely. If `barrierDismissible` were accidentally set to `false`, the original test would fail (tap has no effect); the replacement test would still pass.

**Severity assessment:** This is a real coverage gap, but it is not introduced by the hotfix — the original `tapAt` was already broken (hanging) in `isScrollControlled: true` sheets, meaning that behavior was unverifiable before this fix too. The hotfix trades a hanging test for a passing-but-narrower one.

**Recommendation:** Add a separate, narrow test that asserts `barrierDismissible: true` by inspecting the `ModalBottomSheetRoute` instance after opening the sheet, or by checking the `AppBottomSheet` / `showModalBottomSheet` call site. This can be a standalone unit-level check rather than a widget interaction test:

```dart
// Example: verify the route is dismissible
testWidgets('sheet is barrier-dismissible', (tester) async {
  await _openSheet(tester);
  final route = ModalRoute.of(tester.element(find.byType(SortSheet)));
  expect(route?.barrierDismissible, isTrue);
});
```

This restores coverage of the lost property without fighting the flutter_test shimmer/barrier interaction.

---

## Finding 6 — Eevee `findsNWidgets(8)` is correct but loses the "root is unique" property [SUGGESTION]

**File:** `test/features/pokemon/presentation/widgets/detail/evolution_tab_test.dart`, line 84

**Assertion:**
```dart
expect(find.text('Eevee'), findsNWidgets(8));
```

**Analysis of the flattened layout:** `EvolutionTab._flattenPairs` walks the tree depth-first and emits one `(parent, child)` pair per edge. For Eevee with 8 leaf children and no recursion, this produces 8 pairs, each with Eevee as the parent stage. Each pair renders one `_EvolutionRow` with one `_StageCard` on the left showing "Eevee." The result: Eevee's name appears exactly 8 times. The assertion is arithmetically correct.

**What it tests:** `findsNWidgets(8)` proves all 8 branches were mounted. Each `findsOneWidget` below (Vaporeon, Jolteon, ..., Sylveon) proves each child was mounted exactly once.

**What it does NOT test:** The original intent of `findsOneWidget` was that Eevee is rendered exactly once as the root. That invariant (root-is-unique) is now inverted into "root-repeats-once-per-branch," which is the correct behavior of the new flattened layout. The test correctly documents the new behavior.

**Loss:** There is no assertion that Eevee does NOT appear as a child (i.e., in the right-side position of any row). Since all 8 children are unique (Vaporeon through Sylveon), and those are asserted with `findsOneWidget`, the right-side column has no Eevee widget. So the loss is theoretical — but if the fixture were changed to add a circular reference, the test would not catch it explicitly.

**Verdict:** The assertion is correct for the documented behavior. The comment accurately describes the layout. No action required, but optionally adding `expect(find.text('Eevee'), findsNWidgets(8))` plus a comment noting this counts parent-slot occurrences only (as has been done) is sufficient documentation.

---

## Finding 7 — `ensureVisible` before second height/weight tap is redundant [SUGGESTION]

**File:** `test/features/pokemon/presentation/widgets/sheets/filters_sheet_test.dart`, lines 167–170

```dart
await tester.ensureVisible(find.byKey(const Key('height-short')));
await tester.tap(find.byKey(const Key('height-short')));
await tester.pumpAndSettle();
await tester.ensureVisible(find.byKey(const Key('height-short'))); // redundant
await tester.tap(find.byKey(const Key('height-short')));
```

After the first `ensureVisible` + `tap` + `pumpAndSettle`, the widget is already on-screen and remains so (no layout shift occurs after a single toggle). The second `ensureVisible` is a no-op. Same pattern appears for `weight-light`. This does not affect correctness but adds unnecessary calls. It may also mislead a reader into thinking the widget scrolls off-screen after the first tap.

---

## Finding 8 — Rationale comment accuracy review

**`state_view.dart` comment (line 58–64):** Accurately describes the `LayoutBuilder` pattern and the overflow scenario on constrained surfaces. Correct.

**`sort_sheet.dart` `_buttonGap` comment (line 28–34):** Accurately describes the gap calculation and the `SingleChildScrollView` trade-off. Correct.

**Sort/Generations/Filters sheet barrier-tap comments:** All three use similar wording: "Simulates the user dismissing the sheet without picking an option." Accurate. The note about `tester.tapAt` hanging under `isScrollControlled: true` is a known flutter_test behavior. Correct.

**`filters_sheet_test.dart` Reset comment (lines 225–227):** "Reset wipes the form state but leaves the sheet open" — verified against `_FiltersSheetState._reset()` which calls `setState(() => _loadFrom(null, bounds))` with no `Navigator.pop`. Accurate.

**`pokemon_list_screen_test.dart` shimmer comment (lines 471–474):** States "two manual frames are enough to mount the modal route." The actual code calls `await tester.pump()` then `await tester.pump(const Duration(milliseconds: 300))`. The second call advances by 300 ms, which is multiple frames at 60fps — not "two frames." The comment should say "manual pump of 300 ms" rather than "two manual frames." Minor inaccuracy.

**`_catalogueCoverageStubs()` comment in `pokemon_list_screen_test.dart` (lines 52–55):** "Return a `ready` index so any sheet opened during the test (Filters, Generations) renders its live components instead of the shimmer placeholder." Accurate — `IndexStatus.ready` causes `indexCoordinatorProvider` to resolve immediately with the ready state, so `_NumberRangeSlider` renders the live `RangeSlider` rather than `AppShimmer`.

---

## Finding 9 — Provider stub correctness for `app_boot_test` and responsive screen tests [PASS]

All three stub sites (`app_boot_test.dart`, `pokemon_list_screen_responsive_test.dart`, `pokemon_detail_screen_responsive_test.dart`) provide:
- `pokemonRepositoryProvider`: `IndexStatus.ready`, `listGenerationMembers → []`, no `listMissingSummaryIds` stub needed because connectivity is `none`.
- `connectivityProvider`: `ConnectivityResult.none` + empty `onConnectivityChanged` stream.

**Verification of non-interference with test outcomes:**
- `IndexStatus.ready` + `loadIfNeeded()`: returns immediately (no re-fetch), no shimmer rendered.
- `ConnectivityResult.none`: `BackfillCoordinator._isOnline()` returns false → `_drain()` returns before calling `listMissingSummaryIds`. No DB access.
- `listGenerationMembers → []`: `generationSample()` returns empty list. Generations sheet sample area renders nothing. No test asserts on sprite content in these files.
- The stubs prevent the Drift Timer leak without influencing the assertions being made (routing, theming, screen identity by `id`).

**Verdict: correct and sufficient.**

---

## Finding 10 — `filters_sheet_test.dart` connectivity stub is wifi but harmless [SUGGESTION]

**File:** `test/features/pokemon/presentation/widgets/sheets/filters_sheet_test.dart`, line 61

```dart
when(connectivity.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.wifi]);
```

In the other stubs (`app_boot_test`, `list_screen_test`, both responsive tests), the connectivity stub returns `ConnectivityResult.none`, which ensures `_isOnline()` returns false and `BackfillCoordinator._drain()` exits before calling `listMissingSummaryIds`.

In `filters_sheet_test`, the stub returns `wifi`. However, `BackfillCoordinator.start()` is never called in these tests (only `PokemonListViewModel._kickoffCatalogueCoverage()` calls it, and no view model is mounted by the sheet-only harness). So `_drain()` never runs and `listMissingSummaryIds` is never called. The wifi stub is harmless.

The inconsistency could mislead: a future test that mounts a view model inside the filters harness would have a live-looking connectivity stub that triggers the drain, which would then call `listMissingSummaryIds` — not stubbed on `_FakeRepository.noSuchMethod` (throws `UnsupportedError`). This would produce a loud failure rather than a silent pass, which is acceptable, but the inconsistency is worth documenting.

**Recommendation:** Change `ConnectivityResult.wifi` to `ConnectivityResult.none` in `filters_sheet_test._openSheet` for consistency with all other catalogue-coverage stubs.

---

## Anti-Patterns Found

None. No tautological assertions, no implementation mirroring, no empty-expectation tests, no over-verification with `verify` chains.

---

## Summary Table

| # | File | Severity | Finding |
|---|---|---|---|
| 1 | `test/core/ui/goldens/` + `widgets/goldens/` PNGs | **IMPORTANT** | 6 PNGs regenerated in non-canonical dirs no test reads; canonical goldens are already correct |
| 2 | `empty_generation_widget_test.dart` | **IMPORTANT** | Substring assertions too narrow; full interpolation sentence not pinned |
| 3 | `empty_filter_widget_test.dart` | Suggestion | Comment misstates reason for `textContaining` (correctness fix, not future-proofing) |
| 4 | `empty_search_widget_test.dart` | Suggestion | Test name over-promises; assertion is acceptable but rename improves clarity |
| 5 | `sort_sheet_test`, `generations_sheet_test`, `filters_sheet_test` | **IMPORTANT** | `barrierDismissible` behavior no longer covered; suggest separate route-inspection test |
| 6 | `evolution_tab_test.dart` | Suggestion | `findsNWidgets(8)` correct; root-uniqueness not asserted but layout makes it implicit |
| 7 | `filters_sheet_test.dart` | Suggestion | Second `ensureVisible` before re-tap is redundant and slightly misleading |
| 8 | Multiple | Suggestion | Comment "two manual frames" should say "manual pump of 300 ms" |
| 9 | `app_boot_test`, responsive tests | **PASS** | Provider stubs are correct and non-interfering |
| 10 | `filters_sheet_test.dart` | Suggestion | Connectivity stub returns `wifi` inconsistently; harmless but could surprise future editors |

---

## Verdict

**Fix 2 issues before merging; 1 issue to note on the backlog.**

- **IMPORTANT (3):** Two must be addressed before merge: Finding 1 (do not stage the 6 non-canonical PNG updates) and Finding 2 (tighten `EmptyGenerationWidget` body assertions). Finding 5 (lost `barrierDismissible` coverage) can be tracked as a follow-up backlog item rather than a blocking fix, since the original test was already broken before this hotfix.
- **Suggestions (5):** Findings 3, 4, 6, 7, 8, 10 are non-blocking cosmetic and consistency improvements.
