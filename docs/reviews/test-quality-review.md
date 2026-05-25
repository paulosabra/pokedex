---
title: "Test Quality Review — PR3 (data-part3)"
date: 2026-05-25
branch: feature/data-part3
reviewer: Test Quality Agent (VGV)
---

## Test Quality Review

### Coverage Summary

- **Test run**: Pass (all tests green)
- **Overall project coverage**: 61.4% (1,267 / 2,064 instrumented lines) — the low total is expected because the UI epic is not yet implemented; the data layer's own numbers are what matter here
- **Mapper coverage (T-12 surface)**: 100% line coverage on all six mapper files
- **RepositoryImpl coverage (T-13 surface)**: 100% line coverage (113 / 113 lines)
- **Domain entity coverage**: mixed — see gaps below

| File | Coverage |
|---|---|
| `data/mappers/generation_ranges.dart` | 100% (11/11) |
| `data/mappers/type_effectiveness.dart` | 100% (22/22) |
| `data/mappers/pokemon_mapper.dart` | 100% (10/10) |
| `data/mappers/pokemon_detail_mapper.dart` | 100% (66/66) |
| `data/mappers/evolution_mapper.dart` | 100% (25/25) |
| `data/mappers/cache_mapper.dart` | 100% (33/33) |
| `data/repositories/pokemon_repository_impl.dart` | 100% (113/113) |
| `domain/entities/location_entry.dart` | **0% (0/2)** |
| `domain/entities/location_entry.g.dart` | **25% (2/8)** |

**Missing test files**: none. Every production file in the reviewed scope has a corresponding test file.

---

### Mapper Test Quality (T-12)

#### generation_ranges_test.dart — Pass with suggestions

The test covers end-of-generation boundary values and both out-of-range sentinels, and it correctly caught a real `generationForId(0)` bug during development. The `kUnknownGenerationId == 0` assertion is borderline (testing a constant rather than behavior) but it functions as a cross-layer contract test given the DAO depends on the numeric value 0 being "unknown."

**Gap — start-of-generation boundaries for gens 3–8 are not tested.** The test verifies `152` (Gen 2 start) and `906` (Gen 9 start) but skips `252`, `387`, `494`, `650`, `722`, and `810`. An off-by-one error that shifted the `<= 251` guard to `<= 252` would return `2` for id `252` instead of `3`, and the current suite would not catch it. With 100% line coverage this cannot cause a hidden regression today, but the gap makes the boundary contract weaker than it should be for a "highest-bug-risk surface."

#### type_effectiveness_test.dart — Pass

Strong fixture-backed setup with real API JSON for Grass, Poison, Ground, and Electric types. All four RN-10 calculation paths are explicitly asserted:

- Single-type 2x and 0.5x
- Dual-type Grass/Poison 2x, 0.25x, and neutral-cancellation (key business rule)
- Dual-type Grass/Ground 4x accumulation (RN-10)
- Dual-type Grass/Ground 0x immunity (RN-10)
- Empty relation map degrading to neutral (TE-10)

The `weaknessMask` is verified against `typeWeaknessMask(effect.weaknesses)` — this is a legitimate structural check, not a tautology, because it confirms the mask field is kept in sync with the weaknesses list.

No issues found.

#### pokemon_mapper_test.dart — Pass

Tests cover: dual-type ordering by slot, single-type, empty sprite fallback, and unknown type name filtering (TE-10). Real fixtures are used for the two main cases. The test file is concise and all assertions are behavioral.

No issues found.

#### pokemon_detail_mapper_test.dart — Pass

Covers a comprehensive set of the detail mapping contract:

- Scalar fields, height, weight, genus from real Bulbasaur fixtures
- Flavor text sanitization: verifies `\n` and `\f` removal and double-space collapse (RN-07)
- Abilities with hidden flag
- Gender percentages at rate 1 (12.5% female) and rate -1 (Ditto, genderless) — RN-11
- Level-100 min/max stat formulas for HP and non-HP with documented arithmetic (RN-12)
- Total stat sum
- Type defense and weakness pass-through (RN-10)
- Location mapping from encounter fixture (RF-34)
- Full null-species degradation (TE-10)

The stat formula assertions include inline comments that document the expected arithmetic, which is exemplary.

**Minor gap**: there is no test for a species present but containing no English flavor text entries. The `_englishFlavorText` function has `english.isEmpty ? '' : ...` — this branch is distinct from `species == null` (which is tested) but is never exercised.

**Minor gap**: `gender_rate` boundary values `0` (100% male) and `8` (100% female) are not tested. The formula `rate / 8 * 100` is simple and covered at `rate = 1`, but the zero-result and full-result cases have not been explicitly pinned.

**Minor gap**: `evYield` is tested for a single-stat EV yield (`1 Sp. Atk`). A multi-stat case (e.g., `1 Attack, 1 Speed`) is not tested; the join logic in `_evYield` has a code path for multiple contributing stats.

#### evolution_mapper_test.dart — Important issue

**The 100% line coverage figure masks insufficient behavioral assertions on the Eevee test.**

The Eevee branching test (line 31) only asserts:
1. `chain.root.stage.name == 'eevee'`
2. `chain.root.evolvesTo.length == 8`
3. `vaporeon.stage.condition == 'Use water stone'`

The Eevee fixture exercises all five remaining condition branches in `_conditionFrom` — `minHappiness` (Espeon and Umbreon), `timeOfDay` (Espeon day, Umbreon night), and `location` (Leafeon, Glaceon) — but none of these output strings are asserted. The three branches that produce `'High friendship'`, `'During day'`/`'During night'`, and `'At eterna-forest'` run silently, with their output discarded. A bug that corrupted those condition strings would not be detected by the current test.

The dedicated constructor test (lines 45–85) correctly adds `heldItem` and `knownMove` coverage via a synthetic DTO, which is the right pattern. But the Eevee fixture test should be extended to spot-check at minimum one node from each of the three remaining condition families.

**Pattern note**: the Eevee branching test verifies structural completeness (count) and one representative value. This is a good starting point but, for a surface designated T-12 (highest-bug-risk), every output path of the condition mapper should have an assertion. The test as written provides false confidence: it would still pass if `minHappiness` produced `null` or if `timeOfDay` produced a garbled string.

#### cache_mapper_test.dart — Pass with minor gap

All four cache entity types have explicit round-trip tests (summary, detail, evolution, type-relations). The `summaryToCompanion` companion test verifies each derived SQL column individually, not just the JSON blob. The `pokemonFromRow` round-trip confirms the entity survives encode/decode unchanged.

**Minor gap**: all tests use Bulbasaur (dual-type: Grass/Poison). The `summaryToCompanion` function sets `secondaryTypeId: Value(null)` for single-type Pokémon, and the `summaryToCompanion` companion test never exercises this branch. A Pikachu (single-type Electric) fixture is available and could close this with a two-line companion test.

**Minor gap**: the detail round-trip always uses `encounters: const []`. The `LocationEntry.fromJson` factory is therefore never called in the entire test suite (confirmed by 0% coverage on `location_entry.dart`). The cache_mapper round-trip should use the `encounters_bulbasaur.json` fixture to exercise location deserialization from the JSON cache layer.

---

### Repository Implementation Test Quality (T-13)

#### pokemon_repository_impl_test.dart — Pass with important gaps

**Architecture**: the test correctly uses a real in-memory Drift database (`NativeDatabase.memory()`) as the local source and Mocktail mocks for the remote and connectivity. This is the right approach — it exercises the actual DAO query behavior and catches real SQL/ORM issues while isolating network calls. The injected clock and helper functions (`nowMs`, `daysAgo`) make TTL tests deterministic. Fixture files are used for all remote DTO data.

**Decision machine coverage for `getPokemonDetail`**:

| Branch | Tested |
|---|---|
| Cold miss, online → compose, cache, return | Yes |
| Cold miss, offline → NetworkFailure | Yes |
| Mandatory `/pokemon` fails → propagate failure | Yes |
| Fresh cache, online → return cached, background revalidate | Yes |
| Stale cache, network success → return fresh | Yes |
| Stale cache, network failure → serve stale (TE-02) | Yes |
| Corrupt cache, online → treat as miss, recompose | Yes |
| Corrupt cache, offline → CacheFailure | Yes |
| Partial compose (species fails) → return degraded, not cached | Yes |
| Partial compose (type + encounters fail) → return degraded, not cached | Yes |
| Type cache reuse (fresh cached relations) → no remote type fetch | Yes |

The stale+failure test (TE-02) verifies the stale value is the exact sentinel `'STALE'`, not merely "non-empty." This is a meaningful assertion.

**Issue — fresh cache background revalidate test uses a bare type assertion.** The test at line 196 asserts `expect(result, isA<Ok<PokemonDetail>>())` and then verifies `remote.fetchPokemon` was called. It does not assert that the returned value is the original cached entity (i.e., that the background fetch did not block the return). This is the central contract of the "serve cache immediately, update in background" pattern. The assertion `expect((result as Ok).value, stateEquals(cached))` or at minimum `expect((result as Ok).value.description, isNot('STALE'))` (with a sentinel-seeded cache) would make the test authoritative.

**Issue — stale evolution chain is not tested.** The evolution chain tests cover two states: cold miss (line 318) and fresh cache hit (line 337). The third state — row exists but is stale (`_isFresh` returns false) — is absent. In this case the implementation falls through to a remote fetch and updates the cache. This path includes the `upsertEvolutionChain` call that is not otherwise exercised. Given the TTL branch is already proven for `getPokemonDetail`, the risk is low, but the omission means the TTL enforcement for evolution chains is unverified.

**Issue — null `chainId` branch untested.** `getEvolutionChain` has a guard `if (chainId == null) return const Err(NotFoundFailure())` (line 125). The LCOV data confirms this line is not instrumented — it was never executed across all tests because all fixtures have well-formed evolution chain URLs. A test that provides a species with a malformed or absent `evolutionChain.url` would close this.

**Issue — corrupt evolution cache is not tested.** The `_tryParse` path within the fresh evolution cache branch (line 130) is hit only by the happy-path test. There is no test for a row that is fresh but has corrupt JSON, which would cause `_tryParse` to return null and fall through to a remote fetch. The analogous corrupt-cache tests exist for `getPokemonDetail` but not for `getEvolutionChain`.

**`getPokemonList` coverage**: three tests cover the core paths (offline, success with `hasMore`, empty page, per-id failure). The success test verifies `items.length == 1`, `hasMore == true`, and that the DAO received the upsert — sufficient at the integration level since `pokemonFromDto` is independently unit-tested.

**`search` / `filter` / `watchCachedSummaries`**:
- Search delegates correctly and the corrupt-summary CacheFailure path is explicitly tested (line 404).
- Filter is tested with `const PokemonFilter()` (all defaults, no active criteria). The delegation of type, weakness, and height filter parameters to the DAO is never exercised at the repository level. The DAO itself tests these in `pokemon_dao_test.dart`, so this is a boundary choice, but the composition is unverified at the repository layer.
- `watchCachedSummaries` has one happy-path stream test. The error path (corrupt summary in the stream — which would throw `FormatException` since no error handling wraps the `.map()`) is untested.

---

### Anti-Patterns Found

**evolution_mapper_test.dart:31–43 — Structural count without behavioral assertions**

- Issue: `expect(chain.root.evolvesTo, hasLength(8))` verifies a count but no test asserts the output of the `minHappiness`, `timeOfDay`, or `location` condition branches that the Eevee fixture exercises. Three condition branches produce return values (`'High friendship'`, `'During day'`/`'During night'`, `'At eterna-forest'`) that are silently discarded after execution.
- Fix: Add `firstWhere` look-ups for Espeon, Umbreon, and Leafeon and assert their `stage.condition` values, matching the pattern already used for Vaporeon.

**pokemon_repository_impl_test.dart:196–206 — Bare type assertion on the most important cache contract**

- Issue: `expect(result, isA<Ok<PokemonDetail>>())` does not confirm the returned value is the cache snapshot. The core promise of the fresh-cache branch is "caller receives the old value immediately while revalidation proceeds in the background." A bare type check would pass even if the implementation inadvertently awaited the revalidation.
- Fix: Seed the cache with a sentinel description (as the stale tests do) and assert `expect((result as Ok<PokemonDetail>).value.description, equals(seededDetail.description))`.

---

### Recommendations

1. **Extend the Eevee branching test** to assert Espeon's condition (`'High friendship'`), Umbreon's condition (`'During night'` or `'During day'`), and Leafeon's condition (`'At eterna-forest'`). The Vaporeon look-up pattern at line 39 is the right template. This closes the most significant assertion gap for T-12.

2. **Add a location cache deserialization test** — change the `detail cache round-trips through payloadJson` test in `cache_mapper_test.dart` to use `encounters_bulbasaur.json` (already available as a fixture) so that `LocationEntry.fromJson` is exercised. This closes the 0% gap on `location_entry.dart`.

3. **Add a stale evolution chain test** — seed the chain with `updatedAt: daysAgo(8)`, stub `remote.fetchEvolutionChain` to return the DTO, and assert the result is `Ok` and that `verifyNever` on the remote fetch is no longer satisfied. This closes the missing TTL branch and the `upsertEvolutionChain` path in `getEvolutionChain`.

4. **Add a null `chainId` test** — stub `remote.fetchSpecies` to return a `PokemonSpeciesDto` with an empty or malformed `evolutionChain.url` and assert `NotFoundFailure`.

5. **Strengthen the fresh cache revalidation test** — seed the cache with a distinguishable sentinel description and assert the returned value matches the cached entity, not the revalidated one, to make the "serve immediately" contract explicit.

6. **Add generation boundary assertions for gens 3–8** — test `generationForId(252)` through `generationForId(810)` at the first ID of each generation to guard against off-by-one regressions at the 251, 386, 493, 649, 721, and 809 boundaries.

7. **Add a single-type summary companion test** — call `summaryToCompanion` with a Pikachu (single-type, `types.length == 1`) and assert `companion.secondaryTypeId.value == null`.

---

### Verdict

**Fix 5 issues before merging.**

The test suite is well-structured, uses real fixtures and a real in-memory database for the repository, and achieves its stated 100% line coverage targets. Most mapper logic is thoroughly verified. However, five issues need to be addressed:

1. The Eevee branching test exercises three condition branches (`minHappiness`, `timeOfDay`, `location`) without asserting their output — false confidence on the highest-bug-risk surface.
2. `LocationEntry.fromJson` is at 0% coverage because the detail cache round-trip uses empty encounters.
3. The stale evolution chain branch is untested.
4. The null `chainId` guard in `getEvolutionChain` is never triggered.
5. The fresh cache background-revalidation test uses a bare `isA<Ok>` assertion that does not verify the "serve cache immediately" contract.

Items 3–5 require small additions; items 1–2 require fixture changes. None require structural refactoring. The three "minor gap" findings in the recommendations section are suggestions rather than blockers.
