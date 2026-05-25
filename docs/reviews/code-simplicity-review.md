---
title: "Code Simplicity / YAGNI Review — PR3 (feature/data-part3)"
date: 2026-05-25
scope: "lib/features/pokemon/domain/entities/*.dart, lib/features/pokemon/domain/repositories/pokemon_repository.dart, lib/features/pokemon/data/mappers/*.dart, lib/features/pokemon/data/repositories/pokemon_repository_impl.dart, test/**"
reviewer: claude-sonnet-4-6 (simplicity agent)
---

## Simplification Analysis

### Core Purpose

PR3 introduces (a) nine pure-Dart Freezed domain entities and the `PokemonRepository` interface, (b) six pure-function mappers converting DTOs to entities and entities to cache rows, and (c) a cache-first/SWR `PokemonRepositoryImpl` that composes five PokéAPI endpoints and orchestrates a Drift local cache. Tests must reach 100% mapper coverage and full decision-branch coverage for the repository.

---

### Unnecessary Complexity Found

#### 1. `_tryParse` catches `FormatException` only — `TypeError` from valid-JSON-wrong-shape escapes uncaught

**File:** `lib/features/pokemon/data/repositories/pokemon_repository_impl.dart` lines 262–267

```dart
T? _tryParse<T>(T Function() parse) {
  try {
    return parse();
  } on FormatException {
    return null;
  }
}
```

`pokemonFromRow` / `detailFromRow` call `jsonDecode(row.payloadJson) as Map<String, dynamic>`. If `payloadJson` is valid JSON but not an object (e.g. `"[]"`, `"42"`, `"null"`), `jsonDecode` succeeds but the `as` cast throws `TypeError`, which is *not* a subtype of `FormatException`. `TypeError` then propagates uncaught out of `getPokemonDetail`, turning what should be a `CacheFailure` or a miss into an unhandled exception.

The same narrow catch appears in `_readSummaries` (line 173) for the search/filter path.

Both test cases for corrupt cache (`payloadJson: 'not-json'`) exercise only the `FormatException` arm. There is no test with `payloadJson: '[]'` or `payloadJson: '42'` to confirm `TypeError` is handled.

**Fix:** widen the catch to `on Object` (matching `_revalidateDetail`'s own pattern) or at minimum `on Exception`.

---

### Code to Remove

No significant dead code or unused abstractions were found.

The `_statLabels` constant in `pokemon_detail_mapper.dart` (lines 13–20) is a private map used exactly once in `_evYield`. It is small and its purpose is clear where it sits; moving it inline would make the `_evYield` function harder to read and is not a simplification gain. **No removal recommended.**

---

### Simplification Recommendations

#### 1. `_tryParse`: widen exception catch (Critical)

- **Current:** `on FormatException`
- **Proposed:** `on Object` (or `on Exception`)
- **Impact:** closes the `TypeError` escape hatch at zero LOC cost; aligns with `_revalidateDetail`'s existing `on Object` pattern. Apply the same fix to `_readSummaries` (line 173).

#### 2. `PokemonFilter` defaults test is tautological (Important)

**File:** `test/features/pokemon/domain/entities/pokemon_filter_test.dart`

The single test verifies that `PokemonFilter()` has empty `types`, empty `weaknesses`, and `null` height. These are exactly the `@Default` values already checked by the Freezed generator at codegen time. The in-test comment says "the DAO relies on these defaults", which is a real coupling constraint — but the right place to assert that coupling is in the DAO's own filter tests (which already exist in `pokemon_dao_test.dart` and exercise the no-filter-active path). This test adds no new invariant and cannot fail unless a developer manually removes the `@Default` annotations.

- **Current:** one group, one test, 15 lines
- **Proposed:** delete the file; the DAO tests already guard the defaults in context
- **Impact:** -15 LOC; reduces the set of tests that must be maintained when entity shape changes

#### 3. `_MockConnectivity` uses a behaviour mock where a value stub is sufficient (Suggestion)

**File:** `test/features/pokemon/data/repositories/pokemon_repository_impl_test.dart` lines 34, 40, 65–67, 91

The plan specifies "fake Connectivity (StreamController)" (plan L584). What was implemented is a mocktail `Mock` with `thenAnswer` stubs — `goOnline()` and `goOffline()` convenience helpers. This is not incorrect and the test reads well, but it bypasses VGV's stated fakes-not-mocks convention and links the test to mocktail's invocation matching machinery unnecessarily. For a simple synchronous boolean result, a plain hand-written fake (a tiny class with a settable `_online` flag) would be shorter and have no mocking overhead.

- **Current:** `_MockConnectivity extends Mock`, two `when().thenAnswer()` stubs
- **Proposed:** `class _FakeConnectivity implements Connectivity { bool isOnline = true; ... }`
- **Impact:** eliminates mocktail dependency for connectivity; aligns with plan and VGV convention; roughly even LOC, clarity gain

#### 4. `composedDetail()` test helper uses empty type effectiveness (Suggestion)

**File:** `test/features/pokemon/data/repositories/pokemon_repository_impl_test.dart` lines 79–84

```dart
PokemonDetail composedDetail() => pokemonDetailFromDtos(
  pokemon: pokemonDto,
  species: speciesDto,
  effectiveness: computeTypeEffectiveness(const [], const {}),
  encounters: const [],
);
```

This produces a `PokemonDetail` with empty `weaknesses` and `typeDefenses`. When it is used to seed the "fresh cache hit" and "stale cache" tests, the cached entity has different type data than what the repository's actual `_composeDetail` would produce (which computes effectiveness from real type DTOs via `_ensureAllTypeRelations` or `_relationFor`). The tests pass because they do not assert on weakness/type-defense equality, but the seeded detail is not representative of what the code produces in production. Passing `computeTypeEffectiveness(pokemonDto.types.map(...), ...)` or a realistic `TypeEffectiveness` constant would make the fixture accurate without adding complexity.

- **Impact:** test fidelity improvement; ~5 LOC change

#### 5. Evolution `timeOfDay` and `location` condition branches lack test coverage (Suggestion)

**File:** `test/features/pokemon/data/mappers/evolution_mapper_test.dart`

`_conditionFrom` in `evolution_mapper.dart` has six condition branches: `minLevel`, `item`, `trade`, `minHappiness`, `heldItem`, `knownMove`, `timeOfDay`, `location`. Tests cover `minLevel` (Bulbasaur fixture), `item` (Vaporeon via Eevee fixture), `trade` (plan mentions it), `heldItem` (Gliscor in inline test), `knownMove` (Sylveon in inline test). The `timeOfDay` and `location` branches (lines 40–43) are not exercised by any test case. Since 100% branch coverage is claimed for mappers, these constitute missed coverage.

- **Proposed:** add two inline `EvolutionDetailDto` cases — one with `timeOfDay: 'night'` (asserts `'During night'`) and one with `location: NamedApiResourceDto(name: 'mt-moon', ...)` (asserts `'At mt moon'`)
- **Impact:** ~20 LOC; closes the 100% coverage claim honestly

#### 6. Stale `getEvolutionChain` path is present in code but not tested (Suggestion)

**File:** `lib/features/pokemon/data/repositories/pokemon_repository_impl.dart` lines 127–133; `test/features/pokemon/data/repositories/pokemon_repository_impl_test.dart`

`getEvolutionChain` checks `_isFresh` and serves the cache only if fresh. There is no test for the stale-chain path (stale cached chain → refetch and re-upsert). The "serves a fresh cached chain" test exists, but no "stale cached chain → network refetch" test. This leaves an untested branch in a method that is otherwise described as fully branch-covered.

- **Proposed:** add a test seeding a chain with `updatedAt: daysAgo(400)` and verify `fetchEvolutionChain` is called
- **Impact:** ~15 LOC; closes the coverage gap

---

### YAGNI Violations

None found. Every interface, abstraction, and helper serves its documented purpose:

- The `PokemonRepository` abstract interface has a named consumer (T-16 use case + Evolution tab T-26, recorded in the plan).
- `_tryFetch` / `_tryParse` / `_isFresh` / `_isOnline` / `_relationFor` / `_ensureAllTypeRelations` / `_composeDetail` / `_revalidateDetail` are each called from multiple sites (confirmed by reading the implementation).
- The `TypeEffectiveness` value class bundles three co-computed outputs that are always needed together; it is not a premature abstraction.
- The `pokeApiTypeIds` constant is used both in `_relationFor` (type id → fetch URL) and tested explicitly; it is not speculative.
- Inline SWR per method (no generic helper) is the correct call for rule-of-three discipline at this stage.
- Pure-function mapper grouping is VGV convention; the six mapper files map cleanly to the six mapper domains.

---

### Final Assessment

**Total potential LOC reduction:** ~30 lines (tautological test removal + test additions wash each other out; net is small)

**Complexity score:** Low — the codebase is well-structured, minimalist, and closely follows the plan.

**Critical issue (1):** `_tryParse` / `_readSummaries` catching `FormatException` only lets `TypeError` escape for valid-JSON-wrong-shape payloads. Widen to `on Object` or `on Exception` before merge.

**Important issue (1):** `PokemonFilter` defaults test is tautological and should be deleted; the invariant is already guarded by DAO tests.

**Suggestions (4):**
1. Replace `_MockConnectivity` with a hand-written fake to align with VGV fakes-not-mocks and the plan's spec.
2. Make `composedDetail()` use realistic type effectiveness so seeded cache data reflects production output.
3. Add `timeOfDay` and `location` evolution condition tests to close the 100% coverage claim for `evolution_mapper.dart`.
4. Add a stale-chain test for `getEvolutionChain` to close its branch-coverage gap.

**Recommended action:** Proceed with simplifications — one bug fix required (critical); one test removal (important); four test improvements (suggestions).
