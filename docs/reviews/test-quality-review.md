---
title: "Test Quality Review — PR2 (data-part2)"
date: 2026-05-25
branch: feature/data-part2
reviewer: Test Quality Agent (VGV)
scope: Local/Cache stack — Drift AppDatabase (T-09), PokemonDao + PokemonLocalDataSource (T-10), summary encoding utilities
---

## Test Quality Review

### Coverage Summary

- **Test run**: Pass (all tests pass; suite exits 0)
- **Coverage (excl. generated files)**: 89.1% overall (261/293 covered lines)
- **PR2 files at 100%**:
  - `lib/features/pokemon/data/datasources/pokemon_dao.dart` — 68/68 lines
  - `lib/features/pokemon/data/summary_encoding.dart` — 8/8 lines
- **Below threshold — intentionally excluded per scope note**:
  - `lib/core/database/app_database.dart` — 4/36 lines (11%). Covered lines are `AppDatabase.forTesting`, `schemaVersion`, `migration`/`onCreate`. The uncovered lines are Drift `Table` column getters and the `_openConnection()` production factory — all build-time/codegen artifacts or platform-level wiring that cannot be exercised in a unit test context. Per the review brief, this is not flagged as a gap.
- **Not in lcov** (no executable lines): `lib/features/pokemon/domain/entities/pokemon_filter.dart`, `lib/features/pokemon/domain/entities/sort_criteria.dart`, `lib/core/database/cache_policy.dart`, `lib/core/pokemon/pokemon_type_id.dart` — all are `const`/`enum` declarations; Dart does not emit DA lines for them.
- **Missing test files**: None — every testable unit added in PR2 has a corresponding test file.

---

### Test Infrastructure

**In-memory DB setup**: `AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))` is the correct pattern. `closeStreamsSynchronously: true` prevents stream subscriptions from outliving the test (critical for the reactive stream test). The `tearDown(() => db.close())` correctly returns the `Future<void>` from `db.close()`, which `flutter_test`'s `tearDown` accepts as `FutureOr<void>` — no leaked connections across tests.

**Test helper `summary()`**: the factory function with named parameters and sensible defaults (`generationId: 1`, `height: 7`, `weaknessMask: 0`) is clean, reduces duplication, and makes test data intent legible. It correctly delegates `nameNormalized` to `normalizeName(name)`, which means the helper double-encodes the same function under test in `summary_encoding_test.dart`. This is an acceptable tradeoff: the DAO tests need a realistic `nameNormalized` column to test search, and duplicating the normalization call here keeps the fixture consistent with production without extracting a shared constant.

**`ids()` helper**: extracts only the `id` from query results, making assertions concise and order-sensitive. The ordered nature of the list is load-bearing for the sort tests — this is correct.

**Group structure**: five groups (`upsert + read`, `search`, `filters`, `sort`, `watchSummaries`) with a nested `setUp` in the groups that need data. The outer `setUp`/`tearDown` handle DB lifecycle; the inner group-level `setUp` handles fixture data. This is idiomatic and does not repeat setup across tests.

---

### `test/features/pokemon/data/datasources/pokemon_dao_test.dart`

#### Upsert + Read group

**Result**: Pass — strong.

Covers: round-trip with dual-type Pokémon asserting both `primaryTypeId` and `secondaryTypeId`; conflict update (same id, different name, asserts updated name); cache-miss returning `null` for `readSummary`; and a combined detail/evolution-chain/type-relation round-trip in a single test that asserts all three `payloadJson` values and the `readDetail(2)` miss.

The upsert overwrite test correctly exercises `insertOnConflictUpdate` by writing two companions with the same id and asserting the second name survives — this is the only way to prove the `ON CONFLICT REPLACE` behavior rather than a silent no-op.

**Gap — `readEvolutionChain` and `readTypeRelation` null-miss not tested**: `readSummary(999)` has an explicit null-miss test at line 99. `readDetail(2)` has a null-miss assertion at line 128. However, `readEvolutionChain` and `readTypeRelation` null-miss paths have no corresponding assertion. The implementations are identical one-liners (`getSingleOrNull()`), so the regression risk is low, but completeness calls for at least one `expect(await dao.readEvolutionChain(999), isNull)` in the round-trip test.

#### Search group

**Result**: Pass — strong. All four search paths exercised meaningfully.

- Partial substring (`'saur'` → `[1, 2]`): confirms `LIKE '%saur%'` matches both ids without returning non-matches.
- Case-insensitive (`'CHARMANDER'` → `[4]`): confirms `normalizeName` lowercases the query before the SQL `LIKE`.
- Accent-insensitive RN-07 (`'flabe'` → `[669]` and `'FLABÉBÉ'` → `[669]`): two sub-assertions in one test confirm both directions — unaccented query finding accented data, and accented uppercase query normalized to find the same row. This is the most important search invariant.
- Leading-zero number search RN-06 (`'4'`, `'04'`, `'004'` all → `[4]`): three assertions in one test confirm `int.parse` strips zeros before the `id.equals(id)` predicate.
- No-match returns empty, not error.

**Gap — whitespace-only query not tested**: the production code calls `query?.trim() ?? ''` before checking `term.isNotEmpty`. A query of `'  '` (whitespace only) should behave identically to `null` (no filter applied, all rows returned). This path is not tested. With the filter group's five-row dataset it would be straightforward: `expect(await ids(query: '  '), [1, 4, 31, 143, 152])`. If the trim were ever removed or broken, this would silently change behavior.

**Gap — numeric no-match not tested explicitly**: there is a name-query no-match test (`'mewtwo'` → empty). There is no equivalent for a numeric query that finds nothing (e.g., `query: '999'`). The no-match path for the numeric branch (`id.equals(999)` returning an empty list) is not exercised. This is a minor gap given the implementation is a straightforward Drift `where`/`getSingleOrNull`, but adding `expect(await ids(query: '999'), isEmpty)` would make coverage of both search branches' zero-result paths symmetric.

#### Filters group

**Result**: Pass — good coverage of each filter dimension independently.

- Type filter: three sub-assertions cover primary-only match (`fire` → `[4]`), secondary-only match (`poison` → `[1]`), and shared-primary match (`grass` → `[1, 152]`). The secondary-only assertion is important because the SQL uses `primaryTypeId.isIn(ids) | secondaryTypeId.isIn(ids)` — if the `|` were accidentally dropped, only the secondary-only case would catch it.
- Generation filter: `generationId: 2` → `[152]`. Correct.
- Height bucket filter: all three categories tested with representative values (7, 6, 9 dm for short; 13 dm for medium; 21 dm for tall). The SQL predicates `isSmallerThanValue(10)`, `isBiggerOrEqualValue(10) & isSmallerThanValue(20)`, and `isBiggerOrEqualValue(20)` are thus exercised by values within each range, not at the boundaries.
- Weakness bitmask filter: fire-weak Pokémon (`[1]`), water-weak (`[4]`), zero-mask never matches (`grass` weakness → empty).
- Combined intersection: type+generation.
- Zero-result intersection.

**Gap — height boundary values not exercised**: the `_shortMaxDecimetres = 10` (exclusive upper bound for "short") and `_tallMinDecimetres = 20` (inclusive lower bound for "tall") constants are never tested AT the boundary. No test row has `height: 10` (which should be "medium", not "short") or `height: 20` (which should be "tall", not "medium"). If the predicates were accidentally written as `isSmallerOrEqualValue(10)` or `isBiggerThanValue(20)`, the existing tests would not detect the off-by-one. Adding two fixture rows — one at exactly 10 dm (expected: medium) and one at exactly 20 dm (expected: tall) — would close this gap.

**Gap — multi-type filter set not tested**: all `types:` assertions use a single-element set. The SQL for a multi-element set (`types: {grass, fire}`) uses `primaryTypeId.isIn([0, 2]) | secondaryTypeId.isIn([0, 2])` — a union that should return both Grass-type and Fire-type Pokémon. This OR-union behavior is never exercised. With the filter group's existing dataset (bulbasaur=grass, charmander=fire), `ids(filter: const PokemonFilter(types: {PokemonTypeId.grass, PokemonTypeId.fire}))` should return `[1, 4, 152]` (charmander primary fire, bulbasaur+chikorita primary grass). If `.isIn` were accidentally replaced with `.equals(ids.first)`, only the single-element tests would catch it.

**Gap — multi-weakness filter set not tested**: all `weaknesses:` assertions use a single-element set. A multi-element set (e.g., `weaknesses: {fire, water}`) would compute `queryMask = fire_bit | water_bit` and apply `stored_mask & queryMask != 0` — OR semantics (weak to fire OR water). With bulbasaur (fire-weak) and charmander (water-weak), this query should return `[1, 4]`. This is untested. If the mask computation in `typeWeaknessMask(filter.weaknesses)` were subtly wrong for multi-element inputs, only a multi-element test would catch it.

**Gap — combined filter combinations limited**: the only combined-dimension test pairs `types` + `generationId`. No test exercises `types` + `height`, `weaknesses` + `height`, or a three-dimension combination. These combinations exercise the accumulation of multiple `where()` calls on the same `SimpleSelectStatement`. While each dimension works independently, a regression in the accumulation logic (e.g., a premature `return statement` or an incorrect guard condition) would only be caught by multi-dimension tests.

#### Sort group

**Result**: Pass.

Both `numberAsc`/`numberDesc` and `nameAsc`/`nameDesc` are tested with a three-element dataset that has non-trivial ordering (ids 1, 2, 4; names bulbasaur, ivysaur, charmander). The assertions are expressed as full id lists — order-sensitive, not just set membership. This correctly validates sort direction.

Note: `nameAsc`/`nameDesc` sorts on `t.name` (the raw display name), not `t.nameNormalized`. The test data is all ASCII, so there is no observable difference between the two columns. This is consistent with the production code and deliberate per design. No gap here, but if Pokémon with leading accented characters (e.g., hypothetical names starting with `é`) were ever in the dataset, sorting on `t.name` vs. `t.nameNormalized` would produce different results. This is a future maintenance concern, not a current test gap.

#### watchSummaries group

**Result**: Pass — the listener+pumpEventQueue approach is correct and the race condition noted in the comment is real.

The test avoids the subscribe/insert race by using an explicit listener, pumping the event queue after subscription (to observe the initial empty emit), then inserting, then pumping again. This is more deterministic than `expectLater(..., emitsInOrder([...]))`, which can miss the initial emission if the insert fires before the stream delivers. The plan suggested `emitsInOrder` but the implementation's choice is strictly better.

**Gap — watchSummaries asserts list length, not row identity**: `lengths` collects only `rows.length`. The first emission confirms `length == 0` (empty cache observed), the second confirms `length == 1` (one row inserted). The test does not assert that the emitted row is the correct row (e.g., `rows.first.id == 1` or `rows.first.name == 'bulbasaur'`). A bug that emitted the wrong row — or a different row previously in a leaked DB state — would not be caught. Adding `expect(rows.first.id, 1)` on the second emission would close this without structural change.

**Gap — watchSummaries does not test re-emit on UPDATE**: the stream test covers the insert path (empty → non-empty). Drift's `watch()` also re-emits on UPDATE (the conflict-update path). The DAO has an explicit upsert-overwrites test, but there is no test confirming that `watchSummaries` re-emits after a conflict-update upsert. This is a lower-priority gap since Drift's internal watch mechanism is library-tested, but from a contract perspective `watchSummaries` should re-emit whenever the matching rows change — including mutations, not just insertions.

---

### `test/features/pokemon/data/summary_encoding_test.dart`

**Result**: Pass — correct and complete for the cases tested.

**`normalizeName` group**:

- Lowercase: two assertions (`Bulbasaur` and `PIKACHU`). The implementation lowercases before the diacritics lookup, so uppercase accented input (e.g., `'NIDORÁN'` → `'nidoran'`) is exercised in the third test and confirms that the `toLowerCase()` + map-on-lowercase-keys approach works end-to-end for both lowercase and uppercase input.
- Diacritics RN-07: `'Flabébé'` → `'flabebe'`, `'Pokémon'` → `'pokemon'`, `'NIDORÁN'` → `'nidoran'`. These cover the `é` and `á` entries in the map, confirming the rune-iteration approach handles multi-byte characters correctly.
- Unmapped characters (`Farfetch'd`, `Ho-Oh`): confirms the `?? char` fallback preserves non-diacritic characters.

**Gap — not all diacritic entries exercised**: the `_diacritics` map has 25 entries covering `á à â ä ã å / é è ê ë / í ì î ï / ó ò ô ö õ / ú ù û ü / ç / ñ`. The tests only exercise `é` (Flabébé, Pokémon) and `á` (NIDORÁN). The remaining 23 entries are never directly tested. The relevant Pokémon names that use them (e.g., Farfetch'd uses `'`, not a diacritic; no gen-I Pokémon uses `ü` or `ç`) are rarely encountered. This is a coverage gap the tool does not surface because the individual `if`/`else` branch inside the rune loop is covered by any single diacritic entry hit. The gap matters if a future maintainer adds a new Pokémon name containing, e.g., `ñ` or `ö` and the normalization silently fails due to a typo in the map entry. Adding `expect(normalizeName('señor'), 'senor')` and `expect(normalizeName('über'), 'uber')` would provide two additional anchor tests without verbosity.

**`typeWeaknessMask` group**:

- Empty set → 0. Correct.
- Single type at index 0 (grass) → 1, index 1 (poison) → 2, index 2 (fire) → 4. Confirms `1 << index` bit placement for the three lowest indices.
- Multi-type OR: `{grass, fire}` → `1 | 4 = 5`. Confirms the fold. The sub-assertions `mask & grassMask isNonZero` and `mask & fireMask isNonZero` and `mask & waterMask == 0` verify the bitmask semantics beyond just checking the numeric value.

**Gap — high-index type not tested**: `PokemonTypeId` has 18 values (index 0–17). The highest index tested is `fire` (index 2). The bit encoding for `steel` (index 17) would be `1 << 17 = 131072`. A test `expect(typeWeaknessMask({PokemonTypeId.steel}), 1 << 17)` would confirm no off-by-one in the bit shift for indices beyond the low range. This matters for the DAO's bitmask `&` filter: if the high bit were ever stored as 0 due to integer overflow (Dart uses 64-bit ints, so 1 << 17 is safe, but worth confirming), the weakness filter for Steel-weak Pokémon would silently fail.

---

### `test/features/pokemon/domain/entities/pokemon_filter_test.dart`

**Result**: Pass — covers the three canonical behaviors of a Freezed value object.

- Default construction: asserts `types isEmpty`, `weaknesses isEmpty`, `height isNull`. Confirms the `@Default` annotations work.
- Value equality: two identical filters assert `equals` and matching `hashCode`. This is the critical test for use as a map key or in `== `comparisons in the repository and UI layer.
- `copyWith`: a base filter with `types: {fire}` gets `height: short` applied; asserts the original `types` is preserved and the new `height` is present.

**Gap — inequality not tested**: the equality test only confirms that two equal objects are equal. It does not confirm that two different filters are not equal (e.g., `PokemonFilter(types: {fire}) != PokemonFilter(types: {grass})`). While Freezed's `==` implementation is known-correct, an explicit `isNot(equals(...))` assertion documents the contract and would catch a regression if the equality were ever accidentally hand-overridden.

**Gap — `copyWith` clearing a nullable field to `null` not tested**: `height` is `HeightCategory?` (nullable). The test covers setting `height` from null to a non-null value, but not the reverse — clearing `height` back to `null` via `copyWith(height: null)`. Freezed's generated `copyWith` for nullable fields uses `Object?` sentinel semantics (passing `null` explicitly clears the field). If a future refactor introduces a custom `copyWith` without the sentinel pattern, this path would break. Adding `expect(base.copyWith(height: HeightCategory.short).copyWith(height: null).height, isNull)` would close this gap.

**Gap — `weaknesses` field not tested in `copyWith`**: the `copyWith` test only exercises `height`. The `weaknesses` field (a `Set<PokemonTypeId>`) is never tested in a `copyWith` scenario, nor is `types` mutated via `copyWith`. Given Freezed generates a uniform `copyWith`, this is low-risk, but a single `expect(filter.copyWith(weaknesses: {PokemonTypeId.fire}).weaknesses, {PokemonTypeId.fire})` would complete the coverage.

---

### Anti-Patterns Found

| Location | Anti-pattern | Issue | Fix |
|---|---|---|---|
| `pokemon_dao_test.dart:308` | Asserting count instead of identity | `watchSummaries` test collects only `rows.length` into `lengths`. A wrong row being emitted would not be caught. | Add `rows.first.id == 1` (or equivalent name assertion) to the second emission check. |
| `pokemon_dao_test.dart:265–284` | Incomplete combination coverage | "combined filters intersect" only tests `types + generationId`. Other dimension pairings (`types + height`, `weaknesses + height`) are untested, leaving the multi-where accumulation logic unverified end-to-end. | Add one more combined-filter test pairing a different dimension combination (e.g., `height: short` + `generationId: 1`). |

---

### Recommendations

1. **[Important] Add height exact-boundary rows to the filter group** (`pokemon_dao_test.dart`): Insert rows at exactly 10 dm and 20 dm and assert they fall into the correct bucket (medium and tall, respectively). The current off-by-one boundary for `isSmallerThanValue(10)` vs. `isSmallerOrEqualValue(10)` would be silently wrong without this. This is the highest-risk untested SQL predicate in the DAO.

2. **[Important] Assert row identity in `watchSummaries`** (`pokemon_dao_test.dart`): Change the listener to collect `rows.first.id` (or `rows.map((r) => r.id).toList()`) and assert `[1]` on the second emission alongside the existing length check. A length-only assertion does not verify the content of reactive emissions.

3. **[Important] Add multi-type filter set test** (`pokemon_dao_test.dart`): Test `PokemonFilter(types: {PokemonTypeId.grass, PokemonTypeId.fire})` against the existing filter group dataset and assert the union result `[1, 4, 152]`. The `isIn()` OR logic is only tested via single-element sets currently.

4. **[Suggestion] Add whitespace-only query test** (`pokemon_dao_test.dart`): `expect(await ids(query: '  '), [1, 4, 31, 143, 152])` (using the filter group's setUp data) confirms the `trim()` guard treats whitespace as an absent query.

5. **[Suggestion] Add numeric no-match test** (`pokemon_dao_test.dart`): `expect(await ids(query: '999'), isEmpty)` mirrors the existing name no-match test and makes zero-result coverage symmetric for both search branches.

6. **[Suggestion] Test high-index bit in `typeWeaknessMask`** (`summary_encoding_test.dart`): `expect(typeWeaknessMask({PokemonTypeId.steel}), 1 << 17)` confirms the bit shift is correct at the 18th type (index 17), which is the uppermost bit in the 18-bit mask scheme used by the DAO's `weaknessMask & :mask` filter.

7. **[Suggestion] Test `copyWith` clearing `height` to null and mutating `weaknesses`** (`pokemon_filter_test.dart`): One additional test closing the two `copyWith` field paths not yet exercised.

8. **[Suggestion] Add multi-weakness set test** (`pokemon_dao_test.dart`): `PokemonFilter(weaknesses: {PokemonTypeId.fire, PokemonTypeId.water})` should return `[1, 4]` (bulbasaur fire-weak, charmander water-weak) — confirming OR semantics within the weakness set via the bitmask `&` operation.

9. **[Suggestion] Add `readEvolutionChain` and `readTypeRelation` null-miss assertions** (`pokemon_dao_test.dart`): Extend the round-trip test with `expect(await dao.readEvolutionChain(999), isNull)` to match the existing `readSummary` and `readDetail` null-miss tests.

---

### Verdict

**Fix before merging — Important issues (3), Suggestions (6).**

The PR2 test suite is structurally sound. The in-memory Drift setup is correct, the tearDown is properly async, the search tests cover all specified RN-06/07 requirements meaningfully, and the `normalizeName`/`typeWeaknessMask` tests achieve genuine 100% line coverage with non-tautological assertions. The use of the listener+pumpEventQueue pattern for the reactive stream test is strictly better than the plan's suggested `emitsInOrder`.

The three Important issues all involve SQL predicate correctness that the current tests cannot catch: an off-by-one at the height category boundary, missing row-identity verification on the reactive emission, and untested OR-union semantics for a multi-element type filter set. None of these are paper coverage gaps — each represents a real class of regression that a passing suite would not surface today.

The six Suggestions are low-effort (one or two `expect` calls each) and together would bring filter-dimension combination coverage and encoding edge-case coverage to a level appropriate for a cache layer that PR3 depends on for correctness.
