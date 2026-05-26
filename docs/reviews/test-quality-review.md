---
title: "Test Quality Review — Domain Layer (feature/domain-layer)"
date: 2026-05-26
branch: feature/domain-layer
reviewer: Test Quality Review Agent (VGV)
plan: docs/plan/2026-05-26-feat-domain-layer-plan.md
---

## Test Quality Review

### Coverage Summary

- **Test run:** Pass (all suites green)
- **Overall coverage (including generated files):** 63.0% (1450/2303 lines)
- **Hand-written files coverage (excluding `*.g.dart` / `*.freezed.dart`):** 93.0% (627/674 lines) — above the ≥80% gate
- **Files with tests:** All new domain-layer files have corresponding test files. No missing test files.

**Coverage breakdown for files below 100% (hand-written only):**

| File | Coverage | Gap | Severity |
|---|---|---|---|
| `lib/app/router/app_router.dart` | 0.0% (0/9) | All 9 executable lines — provider body always overridden in tests | Important |
| `lib/core/network/connectivity_provider.dart` | 0.0% (0/2) | Both lines — always overridden before executing | Low |
| `lib/core/database/app_database.dart` | 10.3% (4/39) | Table column DSL definitions; `_openConnection`; `appDatabase` provider body | Low |
| `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart` | 87.5% (7/8) | Line 20 — `context.go('/pokemon/1')` inside `onTap` | Low |

**Context on the 0% files:** Both `app_router.dart` and `connectivity_provider.dart` show 0% because every test that touches them overrides the provider before the body executes. The `app_router.dart` gap is the most consequential: a route-path typo in the real provider body (e.g., `/pokemon/:di` instead of `/pokemon/:id`) would not be caught. The plan requires `routerProvider` to appear in the `keepAlive` identity check — see the Important gap under the provider graph test. The `app_database.dart` low score is dominated by the Drift-generated table column DSL lines, which are not user logic. These gaps do not break the ≥80% gate.

---

### Repository Impl Test Quality — `findPokemon` block

**File:** `test/features/pokemon/data/repositories/pokemon_repository_impl_test.dart`

**Result:** Pass — parametric matrix is complete and meaningful.

- The five-case matrix (sort-only, query-only, filter-only, query+filter, corrupt-row) exercises the DAO's combined query against a real in-memory Drift database. Each assertion checks the output — entity ids in expected order — not the delegation call signature. This is correct behaviour-level testing.
- The corrupt-row case asserts `CacheFailure`, testing the repository's error-mapping contract rather than the DAO's exception type.
- The `watchCachedSummaries` block is preserved intact, including the corrupt-row drop test.
- The `setUp` for this group seeds two realistic Pokémon (bulbasaur grass+poison, charmander fire) using the real `upsertSummaries` DAO path, giving genuine SQL execution. No mocked query results.
- No `registerFallbackValue` is needed here: the repository test passes concrete values directly to the real DAO rather than using `any(named:)` matchers on `SortCriteria` or `PokemonFilter`. Correct.

**Minor finding (style):** The group header is named `'findPokemon / watch (cache-backed)'`, mixing two distinct concerns. The `watchCachedSummaries` tests live inside the same group but represent a separate method. Splitting into `'findPokemon (cache-backed)'` and `'watchCachedSummaries'` would make test output easier to scan. Not a correctness issue.

---

### Use Case Test Quality — 5 files

#### `get_pokemon_list_test.dart`

**Result:** Pass with one minor note.

- Two cases (Ok pass-through, Err pass-through) are appropriate for a pure delegate. The use case has no branching logic.
- The Ok test asserts both the return type (`isA<Ok<PokemonPage>>`) and value identity (`same(page)`) and verifies exact named arguments (`limit: 20, offset: 40`). Correct granularity for a delegate.
- The Err test unpacks the failure and checks its runtime type. Appropriate.
- No `setUpAll` / `registerFallbackValue` is needed for `int` parameters. Correct.
- **Minor note — over-verification:** The Ok test calls `verify(() => repository.getPokemonList(limit: 20, offset: 40)).called(1)`. For a pure delegate, the mock only returns the stubbed value when the `when(...)` matcher fires with the correct arguments; therefore the `same(page)` identity assertion already implies the method was called correctly. The `verify` adds no additional information and couples the test to the call signature rather than the behaviour. Per VGV guidelines: assert behaviour and output, not implementation. **Severity: Low.**

#### `find_pokemon_test.dart`

**Result:** Pass.

- `registerFallbackValue(SortCriteria.numberAsc)` is registered in `setUpAll`. `SortCriteria` is an enum used as a non-nullable named argument; mocktail requires a fallback value for `any(named:)` on non-nullable types. Correct.
- `PokemonFilter` is matched with `filter: any(named: 'filter')` and the parameter is nullable (`PokemonFilter?`). Mocktail does not require a fallback for nullable types. No `registerFallbackValue(PokemonFilter(...))` was added — correct YAGNI.
- The Ok test passes concrete `sort`, `query`, and `filter` values and verifies those exact values were forwarded via `verify`. Identity check (`same(matches)`) confirms no transformation.
- The Err test omits `query` and `filter`, exercising the all-null (default) path.

#### `get_pokemon_detail_test.dart`

**Result:** Pass with one minor note.

- Uses `_FakeDetail extends Fake implements PokemonDetail` as the return value. This is the correct mocktail idiom for a complex object used only for identity comparison — a `Fake` avoids implementing all interface members while providing a concrete instance for `same(detail)`.
- **Minor note — over-verification:** `verify(() => repository.getPokemonDetail(25)).called(1)` is the same over-verification pattern noted in `get_pokemon_list_test`. The `same(detail)` assertion already implies correct delegation. **Severity: Low.**
- No `registerFallbackValue` is needed for `int` parameters. Correct.

#### `get_evolution_chain_test.dart`

**Result:** Pass with one minor note.

- Same pattern as `get_pokemon_detail_test` — `_FakeChain` fake, `same(chain)` identity check.
- Both test cases use `id: 1`. No test exercises `id: 0` or a large id; for a pure delegate this is acceptable — the repository tests own the id-routing logic.
- The same over-verification note applies as above. **Severity: Low.**

#### `watch_pokemon_list_test.dart`

**Result:** Pass with one minor finding — the strongest of the five files overall.

- Four explicit test cases match the plan's stated requirements: initial emission propagation, subsequent emissions in order, filter forwarding, and static type contract.
- The static-type test uses `// ignore: omit_local_variable_types` plus `final Stream<List<Pokemon>> stream = useCase(...)` as a compile-time assertion. This is the correct technique — the assignment refuses to compile if the return type drifts to `Stream<Result<List<Pokemon>>>`.
- **Finding — tautological runtime assertion:** The line `expect(stream, isA<Stream<List<Pokemon>>>())` that follows the typed assignment is unreachable as a meaningful assertion. The compile-time constraint on the variable declaration already guarantees the runtime type. A test that would only fail at runtime (never at compile time) cannot provide additional safety here — if the assignment compiled, `isA<Stream<List<Pokemon>>>()` will always be true. This is a tautological assertion per VGV anti-pattern guidelines. **Severity: Low.** The comment above the typed assignment correctly explains the intent; the `expect` line should be removed.
- `registerFallbackValue(SortCriteria.numberAsc)` registered correctly; nullable `PokemonFilter?` needs no fallback. Correct.
- "Propagates subsequent emissions in order" uses `Stream.fromIterable(const [...])` + `.toList()` — a clean, synchronous-stream approach without unnecessary async scaffolding.
- The filter forwarding test drains the stream with `.drain<void>()` before calling `verify`, ensuring the stream is subscribed and the delegation fires. Correct sequencing.

---

### Boot Widget Test Quality — `app_boot_test.dart`

**Result:** Pass.

- Two tests covering the two routes: boot to `/` (list placeholder) and deep-link to `/pokemon/25` (detail placeholder).
- Both tests wrap `PokedexApp` in `ProviderScope` with `routerProvider.overrideWith(...)`. The override is required (as the plan notes) because the default `routerProvider` boots at `/` — without the override the deep-link test would land on the list, not the detail.
- The boot test asserts `MaterialApp.routerConfig` is not null, theme is not null, theme background colour matches `AppColors.backgroundWhite`, and `PokemonListScreen` is found in the widget tree. These are meaningful structural assertions, not tautologies.
- The deep-link test uses `pumpAndSettle()` to allow `GoRouter`'s asynchronous navigation to complete, then reads the `PokemonDetailScreen` widget and asserts `detail.id == 25`. This directly verifies the route parameter parsing (`int.parse(state.pathParameters['id']!)`). Correct and meaningful.
- The `_routerAt(String location)` helper avoids duplication and keeps both tests readable.

---

### Provider Graph Test Quality — `provider_graph_test.dart`

**Result:** Mostly Pass — the `keepAlive` identity test is genuine and meaningful. One important gap noted.

**What it does well:**

- The `keepAlive` contract test reads each resource-holding provider before invalidating a downstream consumer, then re-reads and asserts `identical(before, after)`. `identical` in Dart compares object references (not equality), so a failing assertion means the provider was disposed and reconstructed — the exact resource-leak scenario the plan identifies as medium-risk. This is substantively stronger than a non-null assertion and passes the "does it test what `dart analyze` cannot" bar.
- `connectivityProvider` is overridden with `_FakeConnectivity extends Fake implements Connectivity` — a `Fake` subclass with one method stubbed — avoiding real platform channel calls. `appDatabaseProvider` is overridden with an in-memory `AppDatabase.forTesting(NativeDatabase.memory())`. Both are the correct isolation approaches.
- The use-case type-assertion group uses `isA<T>()` on each provider result. This correctly catches the scenario where a provider body returns a mis-typed or mis-wired object — something `dart analyze` cannot detect because codegen providers return `Object` from the generated factory.
- `setUp`/`tearDown` correctly create and dispose both the `ProviderContainer` and the in-memory `AppDatabase`. No resource leaks in the test itself.

**Important gap — `routerProvider` is absent from the `keepAlive` contract test:**

The plan's acceptance criteria explicitly list all four `keepAlive: true` providers — `dioProvider`, `appDatabaseProvider`, `connectivityProvider`, and `routerProvider` — as subjects of the identity check. The test verifies the first three but omits `routerProvider`. This means that if `keepAlive: true` is accidentally removed from `app_router.dart`, no test will fail. The `routerProvider` holds navigation history and wires `ref.onDispose(router.dispose)` — losing `keepAlive` would reset the user's navigation state on every downstream rebuild, which is the exact leak class the plan's risk register names. **Severity: Important.**

The omission is partly understandable — constructing a real `GoRouter` in a `ProviderContainer` unit test requires either a widget environment (for route matching) or a carefully isolated router construction. A viable approach is to add `routerProvider` to the same `container` (which already has the in-memory overrides) by additionally overriding `pokemonLocalDataSourceProvider` and `pokemonRemoteDataSourceProvider` so the default `pokemonRepositoryProvider` can resolve, or more simply, by reading `routerProvider` before and after `container.invalidate(routerProvider)` itself (since `routerProvider` has no downstream dependents to trigger the invalidation another way, `container.invalidate` + `container.read` is sufficient). Alternatively, a separate `ProviderContainer` with `overrides: [routerProvider.overrideWith(...)]` could test that a supplied `keepAlive` provider survives invalidation of an unrelated downstream.

**Semantic note on `container.invalidate` + immediate `container.read`:**

The test calls `container.invalidate(pokemonRepositoryProvider)` then `container.read(pokemonRepositoryProvider)` in sequence. `invalidate` marks the provider stale; the immediately following `read` triggers disposal-and-rebuild of the invalidated provider. This sequence correctly exercises the `keepAlive` contract for upstreams because Riverpod disposes non-`keepAlive` upstream providers when their downstream is torn down. The sequencing is valid.

---

### Anti-Patterns Found

**1. `watch_pokemon_list_test.dart` — tautological runtime assertion following a compile-time type constraint**

- **Location:** static-type-contract test, final `expect` line.
- **Issue:** `expect(stream, isA<Stream<List<Pokemon>>>())` always passes whenever the preceding typed variable assignment `final Stream<List<Pokemon>> stream = useCase(...)` compiles. The assignment is the load-bearing assertion — it would refuse to compile if the use case returned `Stream<Result<List<Pokemon>>>`. The runtime `expect` adds no information and inflates the "test passes" signal without catching any real bug.
- **Fix:** Remove the `expect(stream, isA<Stream<List<Pokemon>>>())` line. Leave the typed assignment and the comment. The test comment already explains the intent clearly.

**2. `get_pokemon_list_test.dart`, `get_pokemon_detail_test.dart`, `get_evolution_chain_test.dart` — over-verification on pure delegates**

- **Location:** Ok-path test in each of the three files, the `verify(...).called(1)` line.
- **Issue:** For a pure delegate, the mock only returns the stubbed value when the `when(...)` matcher fires with the correct arguments. A successful return-value assertion (`same(...)` or `isA<Ok<...>>`) therefore already implies the method was called correctly. The subsequent `verify` re-asserts the same fact and couples the test to the delegation implementation detail rather than the observable behaviour. VGV guidelines: "verify behavior and output, not implementation details."
- **Fix:** Remove `verify(...).called(1)` from the Ok-path tests in all three files. Keep `verify` only when testing a side effect (caching, logging, telemetry) not observable through the return value. The Err-path tests correctly omit `verify` and serve as the reference pattern.
- **Note:** This is a style/brittleness finding. The tests are not wrong and will catch delegation bugs. The concern is coupling to the call signature.

---

### Missing Test Coverage (non-critical, deferred to UI epic)

- **`app/router/app_router.dart` (0% coverage):** The real `routerProvider` body — `GoRouter(routes: [...])` construction and `ref.onDispose(router.dispose)` — is never executed. A route-path typo in the real provider body would not be caught. The plan does not call for a test that exercises the real body directly; the gap is structural to the override-everywhere approach. Addressed in part by adding `routerProvider` to the provider graph `keepAlive` contract test (see Important gap above).

- **`pokemon_list_screen.dart` line 20 (87.5%):** The `onTap` callback is not exercised. A `tester.tap(find.byType(ListTile))` + `pumpAndSettle` + `expect(find.byType(PokemonDetailScreen), findsOneWidget)` in `app_boot_test.dart` would close it, but this is a placeholder screen scheduled for replacement in T-19+. Acceptable deferral.

---

### Recommendations

1. **(Important) Add `routerProvider` to the `keepAlive` contract test in `provider_graph_test.dart`.** Read `routerProvider` from the container before and after a downstream invalidation (or after `container.invalidate(routerProvider)` + `container.read(routerProvider)`) and assert `identical(routerBefore, routerAfter)`. If a real `GoRouter` construction is inconvenient in the unit-test context, override `routerProvider` with a cheap stub that returns a minimal `GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())])`. The identity contract is independent of the route configuration.

2. **(Low) Remove the tautological `expect` in the static-type test in `watch_pokemon_list_test.dart`.** The typed variable declaration is the sole load-bearing assertion. Remove `expect(stream, isA<Stream<List<Pokemon>>>())`.

3. **(Low) Remove `verify(...).called(1)` from the Ok-path in `get_pokemon_list_test`, `get_pokemon_detail_test`, and `get_evolution_chain_test`.** The return-value identity assertions already validate delegation. Use the Err-path tests as the reference pattern.

4. **(Style) Split `'findPokemon / watch (cache-backed)'` into two groups** in the repository impl test — `'findPokemon (cache-backed)'` and `'watchCachedSummaries'` — to improve test output readability.

5. **(Future — UI epic)** When `PokemonListScreen` is implemented, add a widget test that taps the `ListTile` and asserts navigation to `/pokemon/1`. The `onTap` lambda at line 20 is the only uncovered line in the screen.

---

### Verdict

**Fix 1 issue before merging.**

The test suite is green, hand-written coverage is 93% (well above the ≥80% gate), and VGV mocktail conventions are followed correctly throughout. The use-case tests are proportionate for pure-delegate classes: argument-forwarding verifications via identity checks, plus 2 cases (Ok/Err) per use case. The `findPokemon` repository matrix is genuinely end-to-end against a real in-memory Drift database. The provider graph `keepAlive` identity test is the right approach and closes the main composition-root risk.

The one issue to address before merge is the **missing `routerProvider` identity check in `provider_graph_test.dart`**. The plan explicitly lists all four `keepAlive` providers in its acceptance criteria, and `routerProvider` is the only one not guarded by an identity assertion. If `keepAlive: true` were accidentally removed from `app_router.dart`, no test would fail.

The three low-severity findings (tautological `expect`, over-verification `verify` calls, group naming) can be addressed in this PR or tracked as polish items.

| Severity | Count | Items |
|---|---|---|
| Important | 1 | Missing `routerProvider` in `keepAlive` identity contract test |
| Low | 3 | Tautological `expect` in static-type test (`watch_pokemon_list_test.dart`); over-verification `verify` in Ok-path of 3 use-case tests; mixed group name in repository impl test |
