# Test Quality Review — T-29 Part 1 E2E Tests & Coverage Gate

**Date:** 2026-05-29
**Scope:** `integration_test/app_test.dart`, `integration_test/helpers/`, `test_driver/integration_test.dart`, `.github/workflows/ci.yaml`
**Plan reference:** `docs/plan/2026-05-28-feat-quality-and-release-plan.md` §5

---

## Coverage Summary

- Test run: Cannot run locally (broken environment — reviewed by static analysis)
- Coverage: 94.8% hand-written post-exclusion (per plan §2.1 baseline)
- Files with tests: Full unit/widget pyramid exists; E2E pyramid top is the subject of this review
- Missing test files: None for the E2E scope under review

---

## E2E Harness Design Quality

### Determinism — Overall verdict: PASS with two conditions to monitor

**What the harness gets right:**

The three leaf I/O providers overridden (`appDatabaseProvider`, `dioProvider`, `connectivityProvider`) are exactly the right boundary. Everything above the data layer — remote data source, repository, use cases, coordinators, view models, router — runs unmodified. This is a genuine integration test, not a widget test dressed up as E2E.

The backfill override (`backfillCoordinatorProvider.overrideWith(_NoopBackfillCoordinator.new)`) is correct and necessary. Without it, `BackfillCoordinator._drain()` would fire 48 sequential-chunked `hydrateSummary` calls via the fake Dio, each completing near-instantly but still scheduling microtasks. This creates a bounded but non-trivial async queue that races `pumpAndSettle` in the pagination test. The stub correctly eliminates this.

The `_NoopBackfillCoordinator extends BackfillCoordinator` pattern is the right override approach for a `keepAlive: true` notifier.

Viewport pinning (`tester.view.devicePixelRatio = 1`, `physicalSize = 420×1000`) with matching `addTearDown` resets is correct and ensures the single-column `ListView` path (not the `GridView`) is exercised, which is what the `PageStorageKey('pokemon-list')` finder depends on.

**Condition 1 — `IndexCoordinator` is not overridden and runs the real index fetch against the fake:**

`PokemonListViewModel.build()` fires `unawaited(_kickoffCatalogueCoverage())`, which calls `indexCoordinatorProvider.notifier.loadIfNeeded()`. The `IndexCoordinator` is not stubbed, so it calls `repository.refreshIndex()`, which calls `remote.fetchIndex(limit: 100000)`. This is a `GET /pokemon?limit=100000` — no `offset` query parameter. The `FakePokeApi.respond()` routes it correctly: `offset == null` falls into the `_listResponse(start:1, end:total=48)` branch. The fake returns 48 fake pokemon. This works, but it means the harness is doing more network-equivalent work than strictly necessary. No functional risk for the current tests; note it as technical debt if a future test needs to control the index separately.

**Condition 2 — `FakePokeApi` has no handler for `GET /evolution-chain/{id}`:**

The `FakePokeApi.respond()` router handles: `pokemon-species`, `type`, `pokemon/{id}`, `pokemon/{id}/encounters`, and the `pokemon` list/index. The `evolution-chain` path falls through to the default `ResponseBody.fromString('', 404)`.

For the two current tests this is not a problem:

- In UC-02/06 the detail screen opens, `pokemonDetailViewModelProvider(1).build()` composes the detail via `_composeDetail(1)` (which calls `fetchPokemon`, `fetchSpecies`, 18 type relations, `fetchEncounters` — all handled). The `EvolutionTab` lives in a `TabBarView` at index 2; `DefaultTabController` starts at index 0 (About). `TabBarView` in Flutter builds tabs lazily, so the `EvolutionTab` is not constructed during `pumpAndSettle`. The `pokemonEvolutionProvider` is never triggered. Safe.
- The pagination test never opens the detail screen.

**However:** if a T-31 test navigates to the Evolution tab, the `evolution-chain` 404 will throw `NotFoundFailure` from `pokemonEvolutionProvider`, and the Evolution tab will render its error state. This is a gap to fill in T-31 when the evolution-chain E2E is added. The `FakePokeApi` needs an `evolution-chain/{id}` handler at that point.

---

## UC-02/06: Search → Detail Flow

### File: `integration_test/app_test.dart` lines 28–58

**Flow correctness:**

The flow exercises the full real graph end-to-end:

1. `pumpApp` → `PokedexApp` boots → `PokemonListViewModel.build()` → `getPokemonList(limit:24, offset:0)` → fake Dio → 24 pokemon hydrated into the in-memory DB → real `PokemonCard` widgets rendered.
2. `enterText('bulba')` → `search('bulba')` → `state.query = 'bulba'` (synchronous UI update).
3. `pump(350ms)` → 300ms debounce fires → `_applyMode()` → `_enterDiscovery()`.
4. `_enterDiscovery()` calls `findPokemon(query:'bulba')` → `repository.findPokemon` → queries in-memory DB → finds id=1 (`bulbasaur`) → returns `[Pokemon(id:1)]`.
5. `pumpAndSettle()` → state becomes `AsyncData([bulbasaur])` → list shows only `#001`.
6. `tap(PokemonCard.first)` → `context.push('/pokemon/1')` → router creates `PokemonDetailScreen(id:1)`.
7. `pumpAndSettle()` → `pokemonDetailViewModelProvider(1)` → `_composeDetail(1)` → all endpoints handled by fake → `AboutTab` rendered.

This is a genuine full-stack integration test. No layer is mocked; the assertions verify observable UI output.

**Assertion quality:**

| Line | Assertion | Assessment |
|---|---|---|
| 34 | `find.byType(PokemonCard), findsWidgets` | Weak — verifies list is non-empty; acceptable for E2E entry condition |
| 35 | `cardNumber(1), findsOneWidget` | Strong — specific dex number present |
| 44 | `cardNumber(1), findsOneWidget` | Strong — search preserved the match |
| 45 | `cardNumber(2), findsNothing` | Strong — negative, proves filtering works |
| 54 | `detail.id, 1` | Acceptable — verifies routing delivered correct id, but is a constructor-arg read |
| 57 | `find.byType(AboutTab), findsOneWidget` | Strong — proves the loaded state rendered (not loading/error) |

**No tautological assertions. No assertions on mocks.** The `AboutTab` finder is particularly well-chosen: `AboutTab` is only in the widget tree when `PokemonDetailScreen._Loaded` is rendered, which only happens when `pokemonDetailViewModelProvider` emits `AsyncData`. A loading shimmer or error state both suppress it. This is behavior verification, not implementation mirroring.

**One improvement opportunity:** `findsWidgets` on line 34 is the only weak assertion. A stronger form (`findsNWidgets(24)`) would verify the full first page loaded, but for E2E this level of precision is acceptable and the plan does not require it.

**Shimmer / `pumpAndSettle` hang risk analysis:**

The initial `pumpApp().pumpAndSettle()` calls `pumpAndSettle` while `_SkeletonList` + `AppShimmer` may briefly be in the tree (the VM is in `AsyncLoading` before `_loadFirstPage()` resolves). `AppShimmer` wraps `Shimmer.fromColors`, which uses a repeating `AnimationController`. A repeating animation schedules frames indefinitely; `pumpAndSettle` only settles when no frames are pending.

**Mitigation:** `FakePokeApi` processes requests synchronously (the `_FakePokeApiAdapter.fetch` async method returns immediately without any `await` yielding back to the event loop). This means `_loadFirstPage()` resolves in the first microtask batch after the first `pump()` call. By the time the shimmer's second animation frame is scheduled, `AsyncData` has replaced `AsyncLoading`, the `_SkeletonList` is removed from the tree, and the animation controller is disposed. The shimmer never completes a full cycle. In practice this works — but it is a load-bearing assumption: if the fake were made to yield (e.g., by adding `await Future.microtask(() {})` before the response), `pumpAndSettle` would hang.

**Risk level:** Low with current synchronous fake; the assumption is implicit rather than documented.

---

## UC-01: Pagination Flow

### File: `integration_test/app_test.dart` lines 61–79

**Flow correctness:**

The 12-drag loop drives the `ScrollController` to `maxScrollExtent`, which triggers `_onScroll` → `loadMore()` → `getPokemonList(limit:24, offset:24)` → fake returns ids 25–48 → hydrated → appended to `state.items`. Continued scrolling brings `#048` into the list's build window.

**Scroll arithmetic is correct:**

- 24 items × ~145px/item (130px card + 15px separator) + 16px bottom padding ≈ 3,496px for page 1.
- 12 drags × 1,500px = 18,000px total — well past the expected ~6,992px for both pages combined.
- `ListView.separated` builds items lazily based on viewport. After the final drag + `pumpAndSettle`, the scroll position is at `maxScrollExtent` and item 48 is in (or just above) the viewport, within the list's cacheExtent build window. `find.text` searches the entire widget tree, so the widget must be built (but not necessarily visible). Sufficient scroll distance ensures it is.

**Timing correctness:**

`loadMore()` fires when `pos.pixels >= pos.maxScrollExtent` and `pos.maxScrollExtent > 0`. The first few drags scroll within page 1; `loadMore` fires when the bottom is reached. Since `FakePokeApi` is synchronous, `isLoadingMore` flips true then false within a single microtask batch. The `_FooterSpinner` (`AppShimmer` wrapping a `SkeletonBox`) is briefly in the tree during `loadMore`, but by the time `pumpAndSettle` is called, `isLoadingMore` is already false and the spinner is gone. Same shimmer-hang logic as above applies.

**One risk:** If `maxScrollExtent` is reached on, say, drag 3, and `loadMore` fires and completes within the same `pumpAndSettle` call, then drags 4–12 scroll within the merged 48-item list. This is the correct behavior. But if `loadMore` is called multiple times (e.g., once per pumpAndSettle after loading page 2 adds new items and extends `maxScrollExtent`), the ViewModel's `isLoadingMore || !hasMore` guard prevents double-loading. After page 2, `hasMore` is false (the fake's `_page` sets `next: null` when `end >= total`). No infinite pagination loop.

**Assertions:**

| Line | Assertion | Assessment |
|---|---|---|
| 65 | `cardNumber(1), findsOneWidget` | Strong — precondition |
| 67 | `cardNumber(48), findsNothing` | Strong — proves page 2 not pre-loaded |
| 78 | `cardNumber(48), findsOneWidget` | Strong — proves pagination fired and succeeded |

These are the right assertions for a pagination test: before/after, specific items, no magic numbers (48 matches `E2EHarness(total: 48)` which is in scope). Correct.

---

## Coverage Gate

### File: `.github/workflows/ci.yaml` lines 63–69

**Implementation:**

```bash
sudo apt-get install -y lcov
lcov --remove coverage/lcov.info \
  '*.g.dart' '*.freezed.dart' '*.drift.dart' '*.config.dart' \
  -o coverage/lcov.info --ignore-errors unused
awk -F: '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END{p=100*lh/lf; printf "coverage: %.1f%%\n",p; exit (p<80)}' coverage/lcov.info
```

**Correct aspects:**

- 4 globs match the plan's §5.2 specification exactly (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`, `*.config.dart`). The plan correctly explains why `*.mocks.dart` is omitted (mocktail generates nothing).
- `--ignore-errors unused` suppresses warnings for forward-safety globs (`*.drift.dart`, `*.config.dart`) that match nothing today.
- `lcov --remove` with `glob` matching operates on the filename component — `'*.g.dart'` matches `lib/app/router/app_router.g.dart` regardless of path. Correct.
- The awk script accumulates `LF` (total instrumented lines) and `LH` (lines hit) across all files, computes the ratio, prints it, and `exit (p<80)` returns exit code 1 (failure) when p < 80 and exit code 0 (success) when p >= 80. Correct.
- `flutter test --coverage` runs before the gate; `lcov --remove` modifies `coverage/lcov.info` in-place; the gate reads the same file. Correct step ordering.
- `very_good test --min-coverage` is NOT used. Correct — it re-runs the suite and measures unfiltered coverage, defeating the exclusion.

**One edge-case risk:**

If `lf == 0` (all files are stripped by the globs, leaving no lines), the awk division produces NaN or a floating-point exception depending on awk implementation, and `exit (p<80)` has undefined behavior. This cannot happen with the current codebase (hand-written code is not covered by the 4 globs), but is worth noting for robustness. A defensive `END{if(lf==0){print "ERROR: no lines found"; exit 1}}` guard would make the failure mode explicit. **This is a suggestion, not a blocking issue.**

**E2E separation is correct:**

The `e2e` job is a separate job with no `--coverage` flag on `flutter drive`. `lcov.info` is never written or modified by the E2E job. The coverage gate only measures unit + widget tests. This satisfies the plan's §5.4 requirement.

---

## CI Structure

### File: `.github/workflows/ci.yaml`

**`--enforce-lockfile`:** Both the `build` and `e2e` jobs use `flutter pub get --enforce-lockfile`. Correct — ensures the locked graph (including the analyzer-9 codegen pins in `pubspec.lock`) is the graph under test. A silent re-resolve would not fail the build step but could break codegen; `--enforce-lockfile` surfaces it immediately.

**`dart run build_runner build` in both jobs:** Both jobs regenerate code from scratch (generated files are git-ignored). This correctly validates that the codegen builder graph instantiates on a clean clone.

**`flutter-version: 3.44.0` pinned in both jobs:** Both jobs pin the exact same Flutter version. Correct — golden stability, deterministic builds. Consistent with the plan §5.4 requirement to keep jobs in sync.

**Missing `needs: build` on the `e2e` job:**

The `e2e` job runs in parallel with the `build` job — there is no `needs: build` dependency. This means:

1. E2E can pass even if unit tests fail.
2. E2E can pass even if the coverage gate fails.
3. The PR's required status checks must include BOTH jobs to enforce the full gate.

The plan §5.4 says "separate job (or a step strictly after the coverage gate)" but does not require a `needs` dependency. The plan's acceptance criteria §5.5 says "E2E runs in a separate job" without a sequential dependency requirement. So this is **within spec** but is a process risk: if only `build` is listed as a required PR status check, a broken unit test suite would not block merge. This depends on the repository's branch protection configuration, which is outside the scope of this file. Flagged as an important observation.

**ChromeDriver startup race:**

```yaml
- name: Start ChromeDriver
  run: chromedriver --port=4444 &

- name: Run E2E (headless Chrome)
  run: |
    flutter drive \
      --driver=test_driver/integration_test.dart \
      ...
```

`chromedriver` is started with `&` (background) and `flutter drive` is invoked in the next step with no readiness check, `sleep`, or retry. `flutter drive` with `--browser-name chrome` connects to ChromeDriver on the default port 4444 at startup. If ChromeDriver has not bound to the port yet, `flutter drive` fails with a connection-refused error.

This is a common pattern in many CI setups, and ChromeDriver typically starts in under 200ms on GitHub's `ubuntu-latest` runners. In practice it usually works. However, it is not guaranteed — especially under runner load. A `sleep 2` or a polling loop (`until nc -z localhost 4444; do sleep 0.1; done`) would eliminate the race entirely. **Risk: low but real. Flagged as important.**

---

## `test_driver/integration_test.dart`

```dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
```

This is the exact standard 2-line entrypoint specified by the Flutter integration_test package. No custom logic added. Correct.

---

## Anti-Patterns Audit

| Location | Anti-Pattern | Assessment |
|---|---|---|
| — | Tautological assertions | None found |
| — | Mock the class under test | The harness overrides leaf providers (database, Dio, connectivity); nothing above is mocked |
| — | Implementation mirroring | None found — tests observe UI behavior, not provider state |
| — | No assertions | Both test bodies have meaningful assertions |
| — | Hardcoded magic values without context | `total: 48` is in the `E2EHarness` constructor default and `cardNumber(48)` correctly refers to the harness's catalogue size |
| — | Missing async waiting | Not present — `pumpAndSettle` follows every interaction |
| `app_test.dart:34` | `findsWidgets` is weak | Minor — acceptable for an initial-state check; not a false-confidence risk |

No anti-patterns found that create false confidence or mask bugs.

---

## Recommendations

### Critical (must fix before merge)

None.

### Important (should fix)

**1. Add ChromeDriver readiness check before `flutter drive`**

Replace:
```yaml
- name: Start ChromeDriver
  run: chromedriver --port=4444 &
```
with:
```yaml
- name: Start ChromeDriver
  run: |
    chromedriver --port=4444 &
    until nc -z localhost 4444; do sleep 0.1; done
```
Eliminates the startup race condition at negligible CI cost. Standard practice.

**2. Add `evolution-chain/{id}` handler to `FakePokeApi`**

The T-31 plan adds an Evolution-tab deep-link E2E test. When `EvolutionTab` is built, `pokemonEvolutionProvider` fires `getEvolutionChain(id)`, which calls `fetchEvolutionChain(chainId)`. The species response already includes `evolution_chain.url: '.../evolution-chain/$id/'`, so the chain id is correctly parsed. Add a handler to `FakePokeApi.respond()`:

```dart
if (segments.contains('evolution-chain')) {
  return _json(_evolutionChain(int.parse(segments.last)));
}
```

With a minimal `_evolutionChain(int id)` that returns a valid `EvolutionChainDto` (a single-stage chain is sufficient for deterministic tests). Without this, T-31's deep-link E2E will see the Evolution tab in error state, which may or may not be the intended test scenario.

**3. Add `needs: build` to the `e2e` job (or document the branch protection requirement)**

If both `build` and `e2e` are required status checks in the repository's branch protection rules, the parallel execution is correct. If only one is required, the other could fail silently. Adding `needs: build` makes the dependency explicit in the workflow file and ensures E2E only runs after the unit test suite and coverage gate pass. Given the plan's ordering guarantees (E2E tests the same graph the gate measures), sequential execution is semantically appropriate.

### Suggestions (quality improvements)

**4. Document the synchronous-fake / shimmer-settle assumption**

The `pumpApp` comment mentions "each flow settles in a few seconds (dominated on web only by the one-time `sqlite3.wasm` load)" but does not document that the `pumpAndSettle` reliance on no-hang shimmer is load-bearing on the fake's synchronous response. Add a brief inline comment:

```dart
// NOTE: FakePokeApi is synchronous — loadFirstPage() resolves in the first
// microtask batch, so the AppShimmer in _SkeletonList is replaced before
// pumpAndSettle has a chance to loop on the repeating AnimationController.
// If the fake is ever made to yield (even one microtask), add explicit
// pump() calls here instead of relying on pumpAndSettle.
await tester.pumpAndSettle();
```

**5. Add a division-by-zero guard to the awk coverage check**

```bash
awk -F: '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END{if(lf==0){print "ERROR: no LF lines after exclusion"; exit 1} p=100*lh/lf; printf "coverage: %.1f%%\n",p; exit (p<80)}' coverage/lcov.info
```

Defensive; fires only if all files are excluded by the globs (impossible today, but makes the failure mode explicit).

**6. Tighten `findsWidgets` to `findsNWidgets(24)` on initial page check**

```dart
// Before
expect(find.byType(adapter.PokemonCard), findsWidgets);
// After
expect(find.byType(adapter.PokemonCard), findsNWidgets(24));
```

Verifies that a full first page (not just one card) was loaded. Matches the `total: 48` / page-size-24 contract visible in `PokemonListViewModel._pageSize = 24`.

---

## Verdict

The T-29 E2E implementation is well-constructed. The harness correctly isolates the three leaf I/O boundaries without mocking any of the domain or presentation logic, giving the tests genuine integration depth. The coverage gate implementation is correct and matches the plan's specification. The two test flows verify meaningful end-to-end behaviors with appropriate assertions.

**Fix 2 important issues before merging** (ChromeDriver race condition and `needs:build` dependency / branch-protection documentation). The `evolution-chain` gap in `FakePokeApi` is not blocking for the current tests but should be addressed in T-31 before adding the Evolution-tab flow.

All tests pass the quality bar on correctness. No anti-patterns, no tautological assertions, no implementation mirroring.

**Ready to merge after resolving the 2 important issues.**
