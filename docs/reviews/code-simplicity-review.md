---
title: "Code Simplicity / YAGNI Review — feature/domain-layer (T-15 revision + T-16 + T-17)"
date: 2026-05-26
scope: "lib/core/network/connectivity_provider.dart, lib/core/network/dio_client.dart, lib/core/database/app_database.dart, lib/features/pokemon/data/* (provider annotations + T-15 revision), lib/features/pokemon/domain/usecases/ (5 new), lib/app/router/app_router.dart, lib/features/pokemon/presentation/pages/ (2 placeholders), lib/main.dart, lib/app/app.dart, plus tests"
reviewer: claude-sonnet-4-6 (simplicity agent)
---

## Simplification Analysis

### Core Purpose

This PR delivers the Domain ring of the Clean Architecture onion. Concretely: (1) the T-15 retroactive revision collapsing `search()` + `filter()` into `findPokemon({query?, filter?, sort})` at the interface and impl level; (2) five pass-through use case classes with `call(...)` and co-located `@riverpod` providers; (3) the full `@riverpod` provider graph wiring Dio → datasources → repo → use cases → router with correct `keepAlive: true` on resource holders; (4) a `GoRouter` with two MVP routes and minimal Scaffold placeholders; (5) `main.dart` + `app.dart` rewired to `ProviderScope` + `MaterialApp.router`. Tests cover use cases (5 files), the `findPokemon` impl matrix, a boot/deep-link widget test, and a `ProviderContainer` keepAlive contract test.

---

### Unnecessary Complexity Found

#### 1. `generationId` on `PokemonLocalDataSource` is a parameter that no caller above it ever passes

**Files:** `lib/features/pokemon/data/datasources/pokemon_local_data_source.dart` lines 42, 51; `lib/features/pokemon/data/datasources/pokemon_dao.dart` lines 71, 84, 97, 134–135

`querySummaries` and `watchSummaries` both accept `int? generationId`. `PokemonRepositoryImpl.findPokemon` calls `_local.querySummaries(sort: sort, query: query, filter: filter)` and never passes `generationId`; `watchCachedSummaries` calls `_local.watchSummaries(sort: sort, filter: filter)` and likewise never passes `generationId`. `PokemonRepository.findPokemon` and `watchCachedSummaries` do not expose the parameter.

The parameter exists on the DAO interface, is threaded through the fake wrapper in the repo impl test, and is exercised in DAO unit tests in isolation — but no production code ever routes a non-null value through this path. This is a YAGNI violation: a filter axis that is specced for a future generation-switcher screen (T-19+, out of scope per the plan's "Out of Scope" section) has been pre-implemented at the DAO/interface level before any caller needs it.

**Fix:** Remove `generationId` from `PokemonLocalDataSource.querySummaries`, `watchSummaries`, and the `PokemonDao` implementation. The DAO's `_summaryQuery` block for `generationId` (lines 134–135) goes away too. Re-add when the generation-switcher route lands. The DAO test cases exercising `generationId` filtering can be removed or held in reserve. Estimated removal: ~10 LOC production + ~15 LOC test.

---

#### 2. `provider_graph_test.dart` omits `routerProvider` from the `keepAlive` identity test

**File:** `test/app/provider_graph_test.dart` lines 46–65

The plan (§ "Provider graph — `keepAlive` contract test") specifies four providers to verify: `dioProvider`, `appDatabaseProvider`, `connectivityProvider`, **`routerProvider`**. The plan reads:

> Read each of `dioProvider`, `appDatabaseProvider`, `connectivityProvider`, `routerProvider` once; capture the four returned instances by identity (`identical`). Call `container.refresh(pokemonRepositoryProvider)`. Re-read the same four providers; assert `identical(before, after)` for each.

The test reads and asserts on three of the four providers. `routerProvider` is absent entirely — neither imported nor read nor asserted. `routerProvider` is also a `keepAlive: true` resource-holder (navigation history); the plan explicitly names it as the fourth provider for this reason. Its omission means the test does not cover the `GoRouter.dispose` leak risk the plan's risk register calls out.

**Fix:** Import `app_router.dart`, add `routerProvider` overrides that avoid a `MaterialApp` dependency (the container test is headless; `GoRouter` does not require a widget context to instantiate), read the provider before and after the `invalidate` call, and assert `identical`. The `app_boot_test.dart` already overrides `routerProvider` with `_routerAt(...)`, which proves the approach works. Estimated addition: ~5 LOC.

---

### Code to Remove

| File | Lines | Reason | Estimated LOC |
|---|---|---|---|
| `lib/features/pokemon/data/datasources/pokemon_local_data_source.dart` | 42, 51 | Remove `int? generationId` from both signatures | -2 |
| `lib/features/pokemon/data/datasources/pokemon_dao.dart` | 71, 84, 97, 134–135 | Remove `generationId` param from `querySummaries`, `watchSummaries`, `_summaryQuery`; remove the filter block | -8 |
| `test/features/pokemon/data/repositories/pokemon_repository_impl_test.dart` | 83, 88, 96, 101 | Remove `generationId` from the `_SpyLocalDataSource` delegation stubs | -4 |
| `test/features/pokemon/data/datasources/pokemon_dao_test.dart` | generation-filter test cases | Remove or defer `generationId`-specific test cases | ~-15 |

**Total estimated removal: ~25–30 LOC**

---

### Simplification Recommendations

#### 1. Remove `generationId` from `PokemonLocalDataSource` and `PokemonDao` (Important)

- **Current:** Both `querySummaries` and `watchSummaries` accept an `int? generationId` that is always `null` at every production call site; the DAO implements the filter branch; test helpers thread the parameter through.
- **Proposed:** Drop the parameter entirely from the interface, DAO, and all test stubs. Re-introduce when the generation-switcher screen (T-19+) lands and a real call site exists.
- **Impact:** ~25 LOC removed; the interface becomes honest about what callers actually need today; YAGNI alignment.

#### 2. Add `routerProvider` to the `keepAlive` identity test (Important)

- **Current:** `provider_graph_test.dart` tests three of the four `keepAlive` providers; `routerProvider` is absent despite being named in the plan's explicit AC and risk register.
- **Proposed:** Override `routerProvider` in the container with a minimal `GoRouter(routes: [...])`, read and assert `identical` before/after `invalidate(pokemonRepositoryProvider)`.
- **Impact:** ~5 LOC added; closes the one keepAlive gap the test plan explicitly names; aligns with AC.

---

### YAGNI Violations

#### `generationId` on the datasource interface and DAO

The generation-filter capability is future scope: the plan's "Out of Scope" section explicitly defers the generation-switcher routing to the UI epic (T-19+). Neither `PokemonRepository`, `FindPokemon`, nor any other production call site passes a non-null `generationId` today. Pre-implementing the DAO branch and interface parameter now is speculative extensibility with no current consumer. The data is stored (`generationId` column in `PokemonSummaryRow` is correct and needed for future use), but the query filter surfaced at the interface level violates YAGNI until the screen that needs it lands.

**What to do instead:** Keep the `generationId` column on `PokemonSummaries` (it costs nothing and is populated already). Remove the `generationId` parameter from `querySummaries`, `watchSummaries`, and `_summaryQuery` now. Add it back when T-19+ introduces the generation-switcher.

---

### Items That Are Not YAGNI Violations (Explicitly Accepted Ceremony)

The following patterns were examined and cleared:

**Five use case classes with pass-through `call(...)` methods.** Each is a single-expression delegation with no conditional logic. The plan's risk register calls this out directly: "Use cases over-abstract (one wrapper class per repo method = ceremony). Low risk. Brainstorm + this plan explicitly accept the ceremony cost: T-16's AC literally says 'class with call(...)'. The five-class shape is the agreed convention." Confirmed: each class is minimal (~10 LOC + provider), no behavior is added, and the DIP justification (ViewModels inject the class, not the repo) is sound. No change recommended.

**`createPokeApiDio()` factory function in `dio_client.dart`.** Exposed for unit tests per the in-file comment. Confirmed: `test/core/network/dio_client_test.dart` uses it directly. Justified.

**`AppDatabase.forTesting(super.e)` constructor.** Used in `provider_graph_test.dart` line 28. Justified.

**`connectivity_provider.dart` as a standalone file.** One-liner that couldn't live in `dio_client.dart` without coupling unrelated concerns. The file is minimal; the keepAlive comment explains the non-obvious reason. Justified.

**Use case providers importing `pokemon_repository_impl.dart` (concrete) for `pokemonRepositoryProvider`.** This is the standard Riverpod generated-provider co-location pattern; the provider function returns the abstract `PokemonRepository` type. DIP is preserved at the use-case constructor level. Not a violation.

**`ref.onDispose(router.dispose)` in `routerProvider`.** Correct: without it the `GoRouter` listens to platform routes indefinitely. Not over-engineering.

**`ref.onDispose(db.close)` in `appDatabaseProvider`.** Correct: without it the SQLite file handle leaks on test teardown. Not over-engineering.

**`_routerAt(String location)` helper in `app_boot_test.dart`.** Used by both widget tests. Justified.

**`_FakeConnectivity` in `provider_graph_test.dart`.** A hand-written Fake rather than a mocktail Mock, aligned with VGV convention (noted as a suggestion in the PR3 review). Correctly applied here.

**`WatchPokemonList` stream type-contract test.** The `// ignore: omit_local_variable_types` explicit static-type annotation is the plan-required compile-time assertion. Correct and necessary.

---

### Final Assessment

**Total potential LOC reduction:** ~25 lines net (removals outweigh the 5-line `routerProvider` addition).

**Complexity score:** Low — the code is lean, closely tracks the plan, and the ceremony of five pass-through use-case classes is explicitly accepted by the plan's AC.

**Critical issues:** 0

**Important issues:** 2

1. `generationId` filter parameter exists on `PokemonLocalDataSource` and `PokemonDao` with no production call site — a YAGNI violation against explicitly out-of-scope scope (T-19+). Remove the parameter from the interface and DAO now; keep the column.
2. `provider_graph_test.dart` omits `routerProvider` from the keepAlive identity assertion, directly contradicting the plan's explicit four-provider AC and the risk register entry for router disposal.

**Recommended action:** Needs work — two important fixes required before merge. Both are small and targeted; neither touches the use case classes, the DI graph wiring, or the routing implementation.
