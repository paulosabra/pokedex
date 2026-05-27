---
title: "Test Quality Review — Presentation Layer PR1 (feature/presentation-part1)"
date: 2026-05-26
branch: feature/presentation-part1
reviewer: Test Quality Review Agent (VGV)
plan: docs/plan/2026-05-26-feat-presentation-layer-plan.md
scope: T-18 Design System + generationId domain revision
---

## Test Quality Review

### Coverage Summary

- **Test run:** Pass — all suites green
- **Overall coverage (all files, including generated):** 64.8% (1565/2414 lines)
- **PR1 hand-written scope coverage** (`lib/core/ui/components/*.dart`, `pokemon_filter.dart`, `pokemon_dao.dart`, `find_pokemon.dart`, excluding `*.g.dart`/`*.freezed.dart`): **98.4% (183/186 lines)**
- **Files with tests:** All 6 DS components, updated DAO, updated filter entity, and updated use-case test are present. The import boundary static guard is present. No missing test files within PR1 scope.

**Coverage gap — 3 uncovered lines in PR1 scope:**

| File | Lines | Branch |
|---|---|---|
| `lib/core/ui/components/pokemon_card.dart` | 120, 121, 123 | `_CardImage.build` — the `CachedNetworkImage(...)` constructor call and `errorWidget` callback |

All three missed lines are in the `_CardImage` widget's network-image branch (the `imageUrl.isEmpty` guard at line 119 returns early for the empty-URL path, which is well-tested; the non-empty path at lines 120–123 is never reached by any test). Details under the PokemonCard quality section below.

**Context on the 64.8% overall figure:** The low headline number is dominated by Drift-generated table DSL (`app_database.g.dart`: 294/932 lines; `app_database.dart` column definitions: 4/39 lines), the codegen provider stubs (`.g.dart` for each use case/provider), and the placeholder screen stubs not in PR1 scope. Hand-written non-generated code outside PR1 scope continues at the level established by the domain epic. The ≥80% gate applies per-slice to new production code; the PR1 hand-written scope clears at 98.4%.

---

### Domain Revision Test Quality

#### `test/features/pokemon/domain/entities/pokemon_filter_test.dart`

**Result:** Pass with one suggestion.

- **Defaults test:** asserts `types`, `weaknesses`, `height`, and `generationId` all hold their defaults (`{}`, `{}`, `null`, `null`). The comment explains the DAO depends on these defaults to detect "no filter active" — appropriate linking of the test to its purpose. Meaningful, not tautological.
- **copyWith test:** seeds a filter with `types: {grass}` and `generationId: 1`, applies `copyWith(generationId: 2)`, then asserts both `reGen.generationId == 2` and `reGen.types == {grass}`. This correctly verifies independent field mutation and that unrelated fields survive a `copyWith`.

**Suggestion — missing null-clear case:** The `copyWith` test covers overriding `generationId` from a non-null value to another non-null value (1 → 2). It does not test `copyWith(generationId: null)` to verify the field can be cleared back to null. In Freezed 3.x the `freezed` sentinel mechanism handles this, but a test asserting the clear path matters when the VM's `_composeFilter()` needs to stop filtering by generation after the user deselects all generations. This would be exercised indirectly by the DAO test, but an explicit entity-level assertion documents the contract at the right level. **Severity: Suggestion.**

---

#### `test/features/pokemon/data/datasources/pokemon_dao_test.dart`

**Result:** Pass — the generationId additions are thorough and well-structured.

- **Three new test cases in the `filters` group:**
  - `by generationId returns only Pokémon from that generation` — covers gen-1 match (4 rows), gen-2 match (1 row), and gen-5 empty result (no rows). Tests the positive case, the singleton match, and the zero-result edge case in a single test. Readable because the setUp data makes the expected IDs self-evident.
  - `generationId intersects with types + height` — verifies the new WHERE clause composes correctly with the existing type and height predicates. Uses a concrete fixture that separates chikorita (gen 2 grass short) from bulbasaur (gen 1 grass short) to make the assertion load-bearing. This is the integration case that would catch a misplaced OR/AND in the query builder.
  - `a zero-result intersection returns empty, not an error` (pre-existing but relevant) — confirms zero-result intersections of any combined filter do not throw.

- **setUp seeding:** The `filters` group setUp adds `chikorita` at `id: 152` with `generationId: 2`, distinguishable from the gen-1 defaults. This is the minimal addition needed and avoids contaminating the other test groups.

- **No over-verification:** Tests assert output IDs (`List<int>` from `.map((r) => r.id)`), not SQL internals. Correct behavior-level testing against a real in-memory Drift database.

- **One note — generation default assumption:** The summary builder helper defaults `generationId = 1`. This means the `sort`, `search`, and `height bucket boundary` test groups all seed gen-1 data without explicitly declaring it. If the default were changed, those groups' behavior would shift. This is a latent coupling rather than an active bug; it is pre-existing and unrelated to the PR1 additions. Not flagged as a defect.

---

#### `test/features/pokemon/domain/usecases/find_pokemon_test.dart`

**Result:** Pass with one minor note.

- **Test 1 (forwards verbatim):** passes concrete `sort`, `query: 'bulba'`, and `filter` values; verifies `same(matches)` identity; then uses `verify` with the exact concrete values. The `verify` is justified here because the test's stated purpose is "forwards verbatim" — the concrete-argument `verify` directly tests the forwarding claim, which is not fully observable from the return value alone (the use case could have discarded the query and returned a cached result). The design choice is defensible.

- **Test 2 (generationId + types filter):** exercises a `PokemonFilter(types: {grass}, generationId: 2)` via the use case. This is the PR1 domain revision test case called out in the plan. The test confirms the use case passes the composed filter through to the repository unchanged.

  **Minor note — verify is incomplete in test 2:** The `verify` block at line 94–99 specifies `sort` and `filter` but omits `query`. In mocktail, an unspecified named argument in a `verify()` call acts as a wildcard, matching any value (including non-null values). The actual call passes `query: null` (omitted at the call site), but the verify would also pass if the use case had inadvertently passed `query: 'stale_value'`. Adding `query: null` explicitly to the verify call would make the forwarding contract airtight. The test is not wrong — the stub is wired with `query: any(named: 'query')` and the result identity assertion implies the stub fired — but the verify understates what it is checking. **Severity: Suggestion.**

- **Test 3 (Err propagation):** calls with `sort` only (all defaults), stubs a `CacheFailure`, and asserts `isA<CacheFailure>`. Correct minimal test for the error path.

---

### UI Component Test Quality

#### `test/core/ui/components/pokemon_card_test.dart`

**Result:** Pass with one important gap.

**What is well-covered:**
- `#NNN` formatting (zero-padded id), name capitalization, primary badge rendering — one parametric test.
- Dual-type: secondary badge renders when `secondaryType` is provided.
- Single-type: secondary badge absent when `secondaryType` is omitted.
- Broken-image placeholder: `Icons.broken_image` found when `imageUrl` is empty (default).
- `onTap` callback fires correctly; synchronous, no `pumpAndSettle` needed. Correct.
- Goldens: `single_type` (fire/charmander), `dual_type` (grass+poison/bulbasaur), `placeholder` (electric/pikachu).

**Important gap — `CachedNetworkImage` path (lines 120–121, 123) is never exercised:**

The `_CardImage.build` method has two branches:
1. `imageUrl.isEmpty` → return `_ImagePlaceholder()` — well tested.
2. `imageUrl` non-empty → return `CachedNetworkImage(...)` with `errorWidget` fallback — **zero coverage**.

No test ever supplies a non-empty `imageUrl`. As a result:
- The `CachedNetworkImage` widget path is never reached.
- The `errorWidget: (_, _, _) => const _ImagePlaceholder()` callback is never invoked.
- If `CachedNetworkImage` were replaced with a `Text('broken')`, no functional test would fail.

The plan's TE-11 acceptance criterion states: "broken-image placeholder shown on cards with missing/failing image." The "failing image" half (errorWidget callback) is untested.

In widget tests, `CachedNetworkImage` attempts to resolve URLs through Flutter's test HTTP client. The standard fix is to inject a `FakeNetworkImageProvider` or override the HTTP client in test setUp to return a 404, then assert that `Icons.broken_image` appears. Alternatively, passing a well-known test image (e.g., a 1×1 transparent PNG encoded as a `data:` URI) via a custom `CacheManager` would test the success path.

**Severity: Important.** The errorWidget callback is a production code path that handles the real-world case of a missing sprite URL. The TE-11 PRD requirement explicitly calls this out. The current placeholder golden (electric/pikachu) does not substitute for this test because it exercises the `isEmpty` guard, not the network-error path.

**Minor note — placeholder golden naming:**  
`pokemon_card_placeholder.png` uses pikachu/electric with an empty `imageUrl`. The golden captures the empty-URL placeholder rendering, but it is visually indistinguishable in intent from `pokemon_card_single_type.png` — both show a single-type card with the `broken_image` icon. The "placeholder" label implies it is specifically testing the broken-image state, but since no non-empty `imageUrl` golden exists, the distinction is between type-color (fire vs electric), not image-state (placeholder vs loaded). If a future golden is added for the loaded-image state, the current naming will be clearer in contrast. Not a defect; noted for future PR authors.

---

#### `test/core/ui/components/type_badge_test.dart`

**Result:** Pass — strongest test file in the set.

- **Label rendering:** asserts `find.text('Grass')` for the grass type. Correct.
- **Color assertion:** resolves the `DecoratedBox` descendant of `TypeBadge` and reads its `BoxDecoration.color`, comparing it to `PokemonTypeTheme.styleOf(PokemonTypeId.fire).color`. This is a genuine behavior assertion — it would fail if `TypeBadge` used `.backgroundColor` instead of `.color`, or if the wrong type's color was applied. The finder (`find.descendant(of: find.byType(TypeBadge), matching: find.byType(DecoratedBox))`) is robust: there is exactly one `DecoratedBox` inside `TypeBadge`'s widget tree.
- **18-type iteration:** pumps a new widget tree for each `PokemonTypeId.values` entry and asserts the expected title-cased label. This is the correct exhaustive-variation pattern. Each `pumpWidget` call replaces the tree entirely, so no inter-iteration state leakage is possible. No `pumpAndSettle` is needed between pumps for a synchronous, stateless widget. Sound.
- **Size scaling:** captures `getSize` before and after switching to `TypeBadgeSize.medium` and asserts both height and width grow. Correct behavioral assertion.
- **Goldens:** grass/fire/water small (3 representative type colors) + grass medium (captures padding/font change). The 3-color selection exercises visually distinct badge tints. Justified.

**Suggestion — color assertion uses fire not grass:** The `applies the PokemonTypeTheme color` test pumps a fire badge but labels its test description generically. The test body is correct; the mismatch between the described scope ("the PokemonTypeTheme color") and the specific type chosen (fire) is a cosmetic inconsistency, not a functional issue. The test would be clearer if it described the chosen type: `'applies the fire PokemonTypeTheme color to the background'`. **Severity: Suggestion.**

---

#### `test/core/ui/components/stat_bar_test.dart`

**Result:** Pass — golden count is justified.

- **Label and value rendering:** asserts both `find.text('HP')` and `find.text('50')`. Correct.
- **Fraction calculation:** asserts `fraction.widthFactor` is `closeTo(128 / 255, 1e-9)`. Correct use of `closeTo` to handle floating-point arithmetic. There is exactly one `FractionallySizedBox` in `StatBar`'s widget tree, so `tester.widget<FractionallySizedBox>` is unambiguous.
- **Clamping above max:** value 999, max 255 → asserts `widthFactor == 1.0`. Tests the clamp upper bound.
- **Clamping below zero:** value -10 → asserts `widthFactor == 0.0`. Tests the clamp lower bound.
- **Goldens (0, 50, 100, 255):** the question asks whether these four goldens are distinct enough to justify all four. They are:
  - `stat_bar_0.png` → 0% fill (bar background only, no colored segment visible)
  - `stat_bar_50.png` → 50/255 ≈ 19.6% fill
  - `stat_bar_100.png` → 100/255 ≈ 39.2% fill
  - `stat_bar_255.png` → 100% fill (full colored bar)
  
  The four values map to four visually distinct rendering states: empty, low, medium, and full. The 0 and 255 extremes are required by the clamping acceptance criteria. The 50 and 100 intermediate values are useful because they verify the proportional rendering at sub-scale levels. Four goldens for a bar widget with continuous variation is reasonable. No reduction recommended.

---

#### `test/core/ui/components/section_header_test.dart`

**Result:** Pass with one minor gap.

- **Title-only test:** asserts `find.text('Types')` is found. Correct.
- **With-trailing test:** taps the `TextButton('Clear')` and asserts the counter increments. Correct behavioral assertion — verifies the trailing widget is wired and interactive, not just rendered.
- **Golden:** title + trailing together. Matches the plan's "one golden" spec.

**Minor gap — title-only test does not assert trailing widget is absent:**

The test named `'renders only the title when no trailing is provided'` only asserts that the title is present. It does not assert that no trailing widget exists (e.g., `expect(find.byType(TextButton), findsNothing)`). If the `SectionHeader` implementation accidentally rendered a default `Text('')` or empty `SizedBox` in the trailing slot unconditionally, this test would still pass. The Dart spread operator for nullable trailing (`?trailing` in `Row.children`) correctly handles null, but a future regression could add an unconditional child here. Adding a `findsNothing` assertion for `find.byType(TextButton)` or similar would close this gap. **Severity: Suggestion.**

---

#### `test/core/ui/components/search_field_test.dart`

**Result:** Pass.

- **Hint text:** asserts `find.text('Search Pokémon')` when the field is empty. Correct.
- **onChanged:** collects into a `List<String>` and asserts `contains('pika')` after `enterText`. Using `contains` rather than `equals(['p', 'pi', 'pik', 'pika'])` is intentional — the test verifies the callback fires with the final value, not every intermediate keystroke. Reasonable for a stateless field that delegates to `TextField`.
- **Controller binding:** creates a `TextEditingController`, adds `addTearDown(controller.dispose)` (correct resource management), pumps with the controller, enters text, and asserts `controller.text == 'mew'`. Correct.
- **onSubmitted:** uses `receiveAction(TextInputAction.done)` to simulate keyboard submit. Asserts the submitted value. Correct.
- **Goldens:** empty and filled states. The filled golden uses a pre-populated controller rather than `enterText`, which avoids test-input cursor artifacts in the pixel comparison.

**Note — `autofocus` parameter is untested:** `SearchField` has an `autofocus` parameter (default `false`) that is wired to `TextField.autofocus`. No test covers the `autofocus: true` path. In a widget test, `autofocus` is observable via `FocusManager.instance.primaryFocus` or `tester.testTextInput.isVisible`. This is a minor omission for a low-risk default-false parameter. **Severity: Suggestion.**

---

#### `test/core/ui/components/app_bottom_sheet_test.dart`

**Result:** Pass.

- **Title and content:** asserts both `find.text('Filters')` and `find.text('content')`. Correct.
- **Primary action absent:** asserts `find.byType(ElevatedButton)` → `findsNothing`. Correct negative assertion — would catch an unconditional button render.
- **Primary action present:** taps "Apply" and asserts the `tapped` flag is true. Correct behavioral test for the optional CTA.
- **Trailing in header:** taps "Clear" and asserts the `cleared` flag is true. Correct behavioral test for `titleTrailing`.
- **Golden:** full configuration (title + trailing + primary action + content). Single golden per plan spec.

---

### Static Guard Test Quality

#### `test/core/ui/import_boundary_test.dart`

**Result:** Pass with one structural note.

The test scans `lib/core/ui/**` for any `import` line containing `package:pokedex/features/` and fails the build if any are found. This is the correct approach for enforcing the layer boundary as a CI gate rather than a lint convention that rots silently.

**Structural note — relative `Directory` path assumes CWD is project root:**

```dart
final root = Directory('lib/core/ui');
```

This path is relative to the process working directory at test execution time. The `flutter test` runner and the VGV CLI test runner both set `CWD` to the project root before executing tests, so this works in practice. However, if the test is ever run via a tool that sets a different `CWD` (e.g., a custom IDE runner or a nested build script), `root.existsSync()` would return `false` and the test would fail with the `reason:` message rather than catching import violations. The assertion `expect(root.existsSync(), isTrue)` acts as a safety net for this case, which is good. Using an absolute path via `path.join(Directory.current.path, 'lib/core/ui')` or the `Platform.script` approach would make the test CWD-independent. **Severity: Suggestion** (works correctly in all current CI and local configurations; risk is latent).

---

### Anti-Patterns Found

**1. `pokemon_card_test.dart` — CachedNetworkImage branch is entirely dead in tests**

- **Location:** `_CardImage.build`, lines 120–121, 123 (`test/core/ui/components/pokemon_card_test.dart` — all tests use `imageUrl: ''` default)
- **Issue:** The production `errorWidget` callback (`(_, _, _) => const _ImagePlaceholder()`) is never reached. The plan's TE-11 "failing image" criterion is unmet. If the `errorWidget` callback were deleted, no test would fail.
- **Fix:** Add a test that supplies a non-empty `imageUrl` (e.g., a `data:image/png;base64,...` URI or a mocked `ImageProvider`) and simulates an image-load failure, then asserts `find.byIcon(Icons.broken_image)`. The existing `renders the broken-image placeholder when imageUrl is empty` test remains for the empty-URL case; the new test covers the network-error case.

**2. `find_pokemon_test.dart:94` — verify in test 2 omits `query` argument, acting as a wildcard**

- **Location:** test `'forwards a filter combining generationId with types'`, the `verify()` block at line 94–99
- **Issue:** `verify(() => repository.findPokemon(sort: ..., filter: filter))` does not specify `query:`. In mocktail, an unspecified named parameter in a `verify()` call matches any value. The actual call at line 88–91 passes no `query` (defaults to `null`), but the `verify` would pass even if the use case had forwarded `query: 'some_stale_query'`. The purpose of the test is to confirm verbatim forwarding; the omitted `query: null` weakens that contract.
- **Fix:** Add `query: null` explicitly to the `verify` block. The when-stub already uses `query: any(named: 'query')` which is unaffected by this change.

---

### Golden Bloat Assessment

**Question: Are the 4 `stat_bar` goldens (0/50/100/255) all justified?**

Yes. The four values map to four qualitatively distinct visual states: empty (0%), low-fill (~20%), mid-fill (~39%), and full (100%). The extremes directly correspond to the clamping tests. The intermediate values ensure the fractional rendering logic produces visible fills at intermediate scales. For a proportional bar component where the fill width is the primary visual output, four goldens is appropriate and not excessive.

**TypeBadge: 4 goldens (grass/fire/water small + grass medium) — justified.** Three representative type colors verify that different hues render correctly; the medium size golden captures the padding/font-size variant. No bloat.

**PokemonCard: 3 goldens (single/dual/placeholder) — minor naming concern but no bloat.** See the naming note in the PokemonCard section.

---

### Coverage Gaps Outside PR1 Scope (carry-over)

These gaps pre-date this PR and are noted for completeness:

| File | Coverage | Reason | Severity |
|---|---|---|---|
| `lib/core/network/connectivity_provider.dart` | 0% (0/2) | Always overridden before body executes in tests | Low |
| `lib/core/database/app_database.dart` | 10.3% (4/39) | Drift table column DSL; `_openConnection`; `appDatabase` provider body | Low |
| `lib/app/router/app_router.dart` | 66.7% (6/9) | Real provider body overridden in all tests | Low (carry-over from domain epic) |

The `routerProvider` keepAlive gap identified in the prior domain-layer review (`docs/reviews/test-quality-review.md`) remains unresolved. It is outside PR1 scope but persists into this PR.

---

### Recommendations

1. **(Important) Add a test for the `CachedNetworkImage` error path in `pokemon_card_test.dart`.** Supply a non-empty `imageUrl` and simulate a network failure so the `errorWidget` callback fires and `Icons.broken_image` appears. This closes TE-11's "failing image" criterion and covers lines 120–121, 123. Moving the `PR1 hand-written coverage` from 98.4% to 100%.

2. **(Suggestion) Add `query: null` to the `verify` block in `find_pokemon_test.dart` test 2.** Tightens the forwarding contract from "sort and filter were passed correctly" to "sort, query (null), and filter were all passed correctly."

3. **(Suggestion) Add `expect(find.byType(TextButton), findsNothing)` to the title-only test in `section_header_test.dart`.** The test name says "only the title" but only asserts the title is present; asserting that no interactive widget is present completes the contract.

4. **(Suggestion) Explicitly test `autofocus: true` in `search_field_test.dart`.** Verify that the field acquires focus after pump. Low priority for a default-false boolean, but closes the last untested parameter.

5. **(Suggestion) Add `copyWith(generationId: null)` to `pokemon_filter_test.dart`.** Confirms the Freezed sentinel mechanism correctly clears an optional int field back to null — the path the VM's `selectGeneration(null)` intent will exercise.

6. **(Suggestion) Use an absolute path in `import_boundary_test.dart`.** Replace `Directory('lib/core/ui')` with `Directory(path.join(Directory.current.path, 'lib/core/ui'))` or equivalent to make the test CWD-independent.

---

### Verdict

**Fix 1 issue before merging.**

The PR1 test surface is well-constructed. All six DS components have their own test file, the tests use `mocktail` and `flutter_test` conventions consistently, golden tests are co-located with parametric tests per the plan's requirement, the 18-type iteration pattern is sound, and the `import_boundary_test.dart` static guard closes the layer boundary in CI. Domain revision tests (`generationId` DAO branch, entity defaults/copyWith, use-case forwarding) are complete and meaningful.

The single issue to address before merge is the **`CachedNetworkImage` errorWidget path in `pokemon_card_test.dart`**. The plan's TE-11 acceptance criterion ("broken-image placeholder shown on cards with missing/failing image") is only half-satisfied — the empty-URL branch is covered but the network-error branch is not. Three production lines are uncovered, and a real regression (removing the `errorWidget:` argument from `CachedNetworkImage`) would not be caught by any test.

The remaining findings are suggestions that improve robustness and documentation but do not block the merge.

| Severity | Count | Items |
|---|---|---|
| Important | 1 | `pokemon_card_test.dart` — `CachedNetworkImage` errorWidget branch (lines 120–121, 123) never exercised; TE-11 "failing image" criterion unmet |
| Suggestion | 5 | `find_pokemon_test.dart`: verify omits `query: null`; `section_header_test.dart`: no `findsNothing` in title-only test; `search_field_test.dart`: `autofocus` untested; `pokemon_filter_test.dart`: no `copyWith(generationId: null)` test; `import_boundary_test.dart`: relative `Directory` path |
