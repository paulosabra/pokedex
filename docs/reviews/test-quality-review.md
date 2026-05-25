---
title: "Test Quality Review — PR1 (data-part1)"
date: 2026-05-25
branch: feature/data-part1
reviewer: Test Quality Agent (VGV)
scope: Remote/Network stack — Dio client + 3 interceptors + ErrorMapper, Retrofit service, Freezed DTOs, RemoteDataSource
---

## Test Quality Review

### Coverage Summary

- **Test run**: Pass (all tests pass per prior verification)
- **Coverage**: 100% line coverage on PR1 data+network files (verified via lcov)
- **Files with tests**: 9/9 testable files covered
  - `lib/core/network/dio_client.dart` → `test/core/network/dio_client_test.dart`
  - `lib/core/network/error_mapper.dart` → `test/core/network/error_mapper_test.dart`
  - `lib/core/network/interceptors/retry_interceptor.dart` → `test/core/network/interceptors/retry_interceptor_test.dart`
  - `lib/core/network/interceptors/rate_limit_interceptor.dart` → `test/core/network/interceptors/rate_limit_interceptor_test.dart`
  - `lib/core/network/interceptors/logging_interceptor.dart` → `test/core/network/interceptors/logging_interceptor_test.dart`
  - `lib/features/pokemon/data/services/poke_api_service.dart` → `test/features/pokemon/data/services/poke_api_service_test.dart`
  - `lib/features/pokemon/data/dtos/*.dart` (7 DTO files) → `test/features/pokemon/data/dtos/*_test.dart`
  - `lib/features/pokemon/data/datasources/pokemon_remote_data_source.dart` → `test/features/pokemon/data/datasources/pokemon_remote_data_source_test.dart`
- **Test helpers**: `test/helpers/fixtures.dart`, `test/helpers/queue_http_adapter.dart` — both present and appropriate

---

### Network / Core Test Quality

#### `test/core/network/error_mapper_test.dart`

**Result**: Pass with one important gap.

All 8 `DioExceptionType` values are explicitly covered — `connectionError` (NetworkFailure), the three timeout types consolidated in one test, `badResponse` subdivided into 404/429/500/503/other-4xx/missing-status-code, and the three catch-all transport types (`cancel`, `badCertificate`, `unknown`) as individual tests. A raw `FormatException` and a Dio-wrapped `FormatException` are both tested.

Assertions use `isA<XxxFailure>()` which verifies the subtype — that is the right level of assertion for a sealed sum type. The assertions are not tautological because the concrete subtype carries semantic meaning (it is what the UI and repository decision logic branch on).

**Gap — no identity/equality check on returned instances**: the `mapError` function returns `const XxxFailure()` from every branch (all constructors are `const`). While the subtype check is sufficient to validate routing correctness, a test that asserts `mapError(...) == const NotFoundFailure()` or `identical(mapError(...), const NotFoundFailure())` would additionally confirm the production code is returning a `const` singleton (a minor performance invariant) and would catch a future regression where someone adds a non-const path. This is low severity but worth noting.

**Gap — 500 vs 503 status codes share one `expect` call per test**: the test titled "500 and 503 map to ServerFailure" makes two `expect` calls inside a single `test(...)`. This is idiomatic for tightly related values and is not an anti-pattern here, but a reader scanning test names only sees one test for two distinct status codes. No structural problem; noted for completeness.

#### `test/core/network/dio_client_test.dart`

**Result**: Pass with one important weakness.

The two tests verify base URL, connect/receive timeouts, and the presence of all three interceptor types. All `expect` calls assert concrete values (`pokeApiBaseUrl`, `Duration(seconds:10)`, `Duration(seconds:15)`, `hasLength(1)`).

**Gap — interceptor ordering not asserted**: the production code attaches interceptors as `[RateLimitInterceptor, RetryInterceptor, LoggingInterceptor]`. This order matters at runtime: the rate-limit interceptor must precede the retry interceptor so that a 429 is caught by the 429-specific path rather than the generic 5xx retry path. The test asserts that each type is present (length 1 each) but does not assert their relative positions. If a future refactor reorders them, no test would fail. Checking `dio.interceptors.toList()[0]` is a `RateLimitInterceptor` and `[1]` is a `RetryInterceptor` would close this gap with a two-line addition.

**Note — `sendTimeout` not configured**: the production `createPokeApiDio()` sets `connectTimeout` and `receiveTimeout` but does not set `sendTimeout`. This is consistent with what is tested and consistent with the plan spec (which only lists the two timeouts). No test gap here — just noting that a future addition of `sendTimeout` would need to be reflected in the test.

#### `test/core/network/interceptors/retry_interceptor_test.dart`

**Result**: Pass — strong.

The test is structured around a `wire()` helper that attaches the interceptor with `baseDelay: Duration.zero` (eliminating real-time delays). The five test cases cover: (1) two sequential transient 5xx errors followed by success — verifying the retry loop and the `callCount` (3); (2) a `connectionError` followed by success — verifying non-`badResponse` transient types; (3) persistent 5xx exhausting `maxRetries` — verifying the cap (callCount 4 = 1 + 3); (4) a non-transient 404 — verifying no retry (callCount 1); and (5) all three non-transient transport types (`cancel`, `badCertificate`, `unknown`) as a loop — each asserts callCount 1 with a `reason:` label.

`callCount` assertions throughout make these behavioral tests rather than "doesn't throw" tests. The plan's requirement that `sendTimeout` and `receiveTimeout` (in addition to `connectionTimeout` and `connectionError`) are transient is verified indirectly through the production `_isTransient` method's coverage — the tests cover `connectionError` explicitly, and 5xx `badResponse` explicitly; the three timeout types are covered via `ErrorMapper` tests.

**Minor gap — timeout types not directly exercised in retry tests**: `connectionTimeout`, `sendTimeout`, and `receiveTimeout` are in the `_isTransient` switch but the retry interceptor tests only exercise `connectionError` and `badResponse`. The `ErrorMapper` tests confirm these types exist on the `DioExceptionType` enum, and `_isTransient` coverage is implicitly 100% (since the overall file has 100% coverage). However, a future reader cannot distinguish "timeout retries are tested" from "the interpreter hit those switch arms during the adapter's fake response path". Adding one test that injects a `DioException(type: DioExceptionType.connectionTimeout)` from the adapter would make the transient-timeout retry contract explicit.

#### `test/core/network/interceptors/rate_limit_interceptor_test.dart`

**Result**: Pass — all three Retry-After paths covered with meaningful assertions.

Six test cases: (1) numeric `Retry-After: 0` → retry succeeds, callCount 2; (2) HTTP-date Retry-After in the past (injected `now` fixed at 2030) → immediate retry, callCount 2; (3) absent Retry-After → fallback, callCount 2; (4) unparseable Retry-After (`not-a-date`) → fallback, callCount 2; (5) persistent 429 exhausts maxRetries, callCount 4; (6) non-429 error is not retried, callCount 1.

The `now` injection is correctly used to make the HTTP-date path deterministic without a real delay. The `fallbackDelay: Duration.zero` in the test wiring eliminates real-time delays.

**Gap — HTTP-date in the future not tested**: the HTTP-date parse path has two sub-branches: `delta.isNegative ? Duration.zero : delta`. The test covers the negative-delta branch (date in the past, immediate retry). The positive-delta branch (date in the future, actual delay) is not exercised. In a test context this can't easily fire without introducing a real `await Future.delayed`, but with `fallbackDelay: Duration.zero` the test could set `retryAfter` to an IMF-fixdate a few milliseconds in the future and rely on `Duration.zero` clamping in the `_retryAfter` not being triggered (i.e., the delta is small and positive). More practically, the current test coverage confirms the HTTP-date parse itself works; the positive-delay branch is an `else delta` that is simple enough that the gap is minor. Still, the `_retryAfter` function's positive-delta branch is the only untested logic path across all PR1 production code, which is worth flagging since the plan calls for 100% data+network coverage.

**Minor — `_expectImmediateRetry` is extracted as a top-level function outside `main()`**: this is an unusual pattern — the helper is only used by one test. It was presumably extracted to work around Dart's inability to call `return` on an `async` test body that is nested and named inline. This is a tooling workaround, not a quality problem, but it means the test body for "honors an HTTP-date Retry-After in the past" is not co-located with the rest of the test cases. Consider inlining it as a local function inside the group.

#### `test/core/network/interceptors/logging_interceptor_test.dart`

**Result**: Acceptable, with a known inherent limitation.

Two tests: (1) successful request passes through unchanged (asserts `response.statusCode == 200`); (2) error passes through without being swallowed (asserts `throwsA(isA<DioException>())`).

**Limitation — logging side-effect not asserted**: `LoggingInterceptor.onRequest`, `onResponse`, and `onError` each call `developer.log(...)`. The tests verify the pass-through contract (responses and errors propagate) but do not verify that logging actually occurred. This is the standard tradeoff with `dart:developer` — it goes to a platform-specific sink with no public test API. The tests are therefore as complete as they can be without mocking the `dart:developer` namespace or injecting a logger. This is not a gap created by the test author; it is an inherent constraint of the logging approach. **Noted without a required fix.**

**Minor weakness — only one success fixture tested**: the test uses `jsonOk('{"ok":true}')` — a hand-constructed minimal JSON body. Since the `LoggingInterceptor` is pass-through and does not inspect the body, this is fine. However, the test verifies `statusCode == 200` but not the response body. Since the interceptor's job is pass-through, the right assertion here is actually a body round-trip check to prove the interceptor does not mutate the response. Adding `expect(response.data, {'ok': true})` would strengthen this from "status passes through" to "entire response passes through untouched."

---

### DTO Test Quality

#### `test/features/pokemon/data/dtos/pokemon_dto_test.dart`

**Result**: Pass — strong fixture-driven coverage with meaningful field-level assertions.

Three test cases: dual-type Bulbasaur, single-type Pikachu, and a minimal TE-10 payload. The Bulbasaur test asserts `id`, `name`, `height`, `weight`, `baseExperience` non-null, types count 2 with `containsAll`, `stats hasLength(6)`, abilities non-empty, and the nested `officialArtwork.frontDefault` containing the expected URL fragment. The Pikachu test asserts `types.single.type.name == 'electric'`, catching the single-element list regression. The TE-10 minimal test asserts all optional fields are null/empty.

**Gap — `stats` values not checked**: the test asserts `dto.stats hasLength(6)` but does not check any individual stat's `baseStat`, `effort`, or `stat.name`. Since the mapper (PR3) will read `baseStat` values to compute Min/Max, a deserialization bug (e.g., `base_stat` silently returning 0 because the snake-case rename missed a hyphen or nesting) would not be caught here. At minimum one stat — say, HP — should have its `baseStat` asserted against the fixture value.

**Gap — `abilities` field**: the test asserts `dto.abilities isNotEmpty` for Bulbasaur but does not check any ability's `name` or `isHidden` flag. Similarly to stats, the `isHidden` flag is used in PR3 to populate the ability entity's `isHidden` property. A regression in that field's deserialization would be invisible.

**Gap — `slot` field on type slots not asserted**: the comment "order is asserted in the PR3 mapper" is reasonable, but the `slot` field itself is a required field on `PokemonTypeSlotDto` and is entirely untested here. If `slot` were deserialized as `0` for all slots due to a name mismatch, the PR3 sort-by-slot logic would fail silently.

#### `test/features/pokemon/data/dtos/evolution_chain_dto_test.dart`

**Result**: Pass — covers both structural shapes (linear chain and branching chain).

The Bulbasaur linear test traverses the full three-stage chain, asserting species names at each level and `evolutionDetails[0].minLevel == 16` on the Ivysaur node. The Eevee branching test asserts eight evolutions and spot-checks one name (`vaporeon`).

**Gap — `isBaby` field not tested for true**: both tests check `isBaby` (Bulbasaur asserts `isFalse`), but no fixture or inline payload exercises `isBaby: true`. The `@Default(false)` on the field means a missing key is silently treated as `false`, which is correct, but the true-value path is never exercised. While no Gen-I starter is a baby Pokémon, a fixture with `"is_baby": true` on a root node would close the gap and confirm Freezed correctly deserializes the boolean when present.

**Gap — `EvolutionDetailDto` nullable fields not directly tested**: the Bulbasaur test asserts `minLevel == 16`, which is the non-null path for that field. The nullable fields (`item`, `heldItem`, `minHappiness`, `timeOfDay`, `location`, `knownMove`, `gender`) are all present in the DTO but are never individually asserted to be `null` on a fixture that doesn't contain them, nor asserted to be non-null on a fixture that does. The PR3 mapper's `evolutionDetails[0].minLevel` (level-based evolution condition) depends on these nullable fields. The current test leaves the TE-10 coverage of individual evolution detail fields to implicit Freezed behavior.

#### `test/features/pokemon/data/dtos/pokemon_species_dto_test.dart`

**Result**: Pass — two meaningful real-fixture tests.

Bulbasaur test asserts `id`, `name`, `genderRate`, `captureRate > 0`, `growthRate.name` non-empty, `generation.name`, `eggGroups` non-empty, `flavorTextEntries` non-empty, `genera` non-empty, and `evolutionChain.idFromUrl` non-null.

Ditto test asserts `name` and `genderRate == -1` — the critical genderless-species case for the PR3 gender mapper.

**Gap — `hatchCounter` and `baseHappiness` not asserted**: these are required fields on the DTO that feed the PR3 `Training` entity. They are never checked. A deserialization error (wrong field name, wrong type) would be invisible.

**Gap — `flavorTextEntries` content**: the test asserts `flavorTextEntries isNotEmpty` but does not drill into the structure (e.g., `entries.first.language.name` or `entries.first.flavorText` being non-empty). The PR3 description mapper picks the English flavor text using `language.name == 'en'`; a bug in the nested `FlavorTextEntryDto.language` deserialization would not be caught.

**Gap — no TE-10 (missing-fields) test**: unlike `pokemon_dto_test.dart` which has an explicit TE-10 case, `pokemon_species_dto_test.dart` does not test what happens when optional list fields (`eggGroups`, `flavorTextEntries`, `genera`) are absent. These fields have `@Default` on their Freezed constructors, so this is less critical than for non-defaulted optional fields, but consistency with the other DTO tests and the plan's explicit TE-10 requirement is missing.

#### `test/features/pokemon/data/dtos/location_area_encounter_dto_test.dart`

**Result**: Pass — covers both the non-empty (fixture) and empty-array edge cases.

The Pikachu fixture test asserts `encounters isNotEmpty`, `first.locationArea.name isNotEmpty`, `versionDetails isNotEmpty`, `versionDetails.first.version.name isNotEmpty`, and `encounterDetails isNotEmpty`. The empty-array test asserts `isEmpty`.

**Gap — `maxChance` and `EncounterDetailDto` fields not asserted**: `VersionEncounterDetailDto.maxChance` (required `int`) and the `EncounterDetailDto` fields `chance`, `minLevel`, `maxLevel`, and `method.name` are never individually verified. Since the Pikachu fixture has concrete numeric values for all these fields, adding at minimum `expect(first.versionDetails.first.maxChance, greaterThan(0))` and `expect(first.versionDetails.first.encounterDetails.first.chance, greaterThan(0))` would confirm the numeric fields are correctly deserialized.

#### `test/features/pokemon/data/dtos/type_dto_test.dart`

**Result**: Pass — covers two semantically distinct type configurations.

Grass type test asserts `id == 12`, `name == 'grass'`, `doubleDamageFrom` contains `'fire'`, `doubleDamageTo` contains `'water'`. Ground type test asserts `name == 'ground'`, `noDamageFrom` contains `'electric'`. The immunity test is the most important case because the `noDamageFrom` list drives the `0×` multiplier in the PR3 weakness math.

**Gap — `halfDamageFrom`/`halfDamageTo`/`noDamageTo` lists never checked**: the `DamageRelationsDto` has six directional lists but only `doubleDamageFrom`, `doubleDamageTo`, and `noDamageFrom` are tested. The `halfDamageFrom` and `halfDamageTo` lists are critical for the `0.5×` multiplier in the PR3 `type_effectiveness.dart` computation. A deserialization bug in either half-damage list would produce wrong weakness results without any test catching it here. The electric and poison type fixtures in `test/fixtures/` provide concrete half-damage data that could be used.

**Gap — only two of four type fixtures are used**: `test/fixtures/` contains `type_electric.json`, `type_grass.json`, `type_ground.json`, and `type_poison.json`. Only grass and ground are used. The electric fixture (`id: 13`, `doubleDamageFrom: ['ground']`) and poison fixture (`id: 4`, `halfDamageTo: [...]`, `noDamageTo: ['steel']`) sit unused. This is not a coverage gap per se (the DTO structure is uniform), but the poison `noDamageTo` list being untested means the `noDamageTo` deserialization path is exercised only implicitly via Freezed `@Default`.

#### `test/features/pokemon/data/dtos/named_api_resource_dto_test.dart`

**Result**: Pass — thorough for a small utility DTO.

Four `idFromUrl` sub-tests cover: standard trailing-id URL, URL without trailing slash, URL with no trailing integer, and empty string. Both `name` defaulting and explicit `name` presence are tested.

No gaps found. This is the most thoroughly exercised DTO relative to its surface area.

#### `test/features/pokemon/data/dtos/pokemon_list_response_dto_test.dart`

**Result**: Pass.

Two tests: a full page with pagination cursors (asserts `count`, `next` non-null, `previous` null, `results hasLength(2)`, `results.first.idFromUrl == 1`) and a TE-10 minimal payload with `count: 0` (asserts `results isEmpty`, `next null`).

No gaps found. The `idFromUrl` delegation to `NamedApiResourceDto` is correctly tested in the `NamedApiResourceDto` tests.

---

### Service Test Quality

#### `test/features/pokemon/data/services/poke_api_service_test.dart`

**Result**: Pass — each endpoint verified for path, query parameters, and return-value field.

The `serviceReturning()` helper creates a real `Dio` with the `QueueHttpAdapter` serving a single `jsonOk(body)` response. `path()` and `query()` helpers inspect `adapter.lastOptions!.uri` to verify the exact path and query parameters.

Six tests: `getPokemonList` (asserts `count`, path ends with `/pokemon`, `limit`/`offset` query params); `getPokemon` (asserts `result.name`, path ends with `/pokemon/1`); `getSpecies` (asserts `result.id`, path); `getEvolutionChain` (asserts `result.id`, path); `getType` (asserts `result.name`, path); `getEncounters` (asserts result non-empty, path).

**Gap — error behavior not tested**: the service tests only cover the success path. `PokeApiService` is generated by Retrofit; Retrofit's error handling (wrapping HTTP errors in `DioException`) is exercised by the interceptor tests, so this is not a critical gap. However, a test confirming that a 404 response from the adapter propagates as a `DioException` (rather than, say, silently returning null) would add a layer of defense against future Retrofit version changes. This is a suggestion, not a required fix.

**Gap — `getPokemonList` with `limit=0` or `offset=0` as boundary values**: only `limit=20, offset=40` is tested. Offset 0 (first page) is used in the remote data source tests but never in the service test itself. Minor.

**Gap — no test for the service's `baseUrl` override**: the `@RestApi(baseUrl: ...)` annotation sets the base URL, but the test constructs `Dio` with an explicit `baseUrl`. The service can be constructed with a custom `baseUrl` override (`PokeApiService(dio, baseUrl: '...')`). This is a Retrofit feature, not tested here, which is acceptable for a codegen integration test.

---

### DataSource Test Quality

#### `test/features/pokemon/data/datasources/pokemon_remote_data_source_test.dart`

**Result**: Pass — correct fake/mock strategy with meaningful behavior assertions.

Uses mocktail (`_MockPokeApiService extends Mock implements PokeApiService`) for the service layer, which is the VGV-specified mocking library. `PokemonRemoteDataSourceImpl` is the subject under test (not mocked). All error mapping tests use `throwsA(isA<XxxFailure>())` — the right assertion for the translation contract.

Four success tests: `fetchPage`, `fetchPokemon`, `fetchEvolutionChain`, `fetchEncounters`. Five error-mapping tests: 404→NotFoundFailure, FormatException→ParsingFailure, connectionTimeout→TimeoutFailure, 5xx→ServerFailure, connectionError→NetworkFailure.

**Gap — `fetchSpecies` success not tested**: `fetchSpecies` is one of the six public methods on `PokemonRemoteDataSource` and has no success-path test. The error-mapping mechanism is shared via `_guard<T>()`, so the error behavior is implicitly covered by the tests for `fetchPage`, `fetchPokemon`, `fetchSpecies` (error), `fetchType` (error). But the success path for `fetchSpecies` — confirming the DTO is passed through without transformation — is missing. This follows the pattern of the other four success tests and should be added.

**Gap — `fetchType` success not tested**: same as `fetchSpecies`. `fetchType` appears only in an error-path test (`fetchType maps a connection error to NetworkFailure`). The success path is not tested.

**Gap — `fetchEncounters` error not tested**: `fetchEncounters` has a success test (returns empty list) but no error test. Of the six methods, only `fetchPage`, `fetchPokemon`, `fetchSpecies`, and `fetchType` have error-path tests. `fetchEncounters` and `fetchEvolutionChain` (which also only has a success test) lack error coverage. Since error handling is uniform via `_guard`, this does not represent a logic risk, but it does mean that if `_guard` were accidentally removed from those two methods, no test would catch it.

**Note — `verify()` usage on `fetchPage` success**: `verify(() => api.getPokemonList(20, 0)).called(1)` in the `fetchPage` test is over-verification of a pure delegation. The more important assertion (`expect(result, dto)`) already proves the call was made (the mock would not have returned `dto` otherwise). The `verify` call is not harmful, but it binds the test to the implementation detail that delegation happens exactly once. In the other success tests, `verify` is correctly absent. Removing it from the `fetchPage` test would be consistent.

---

### Test Helpers Quality

#### `test/helpers/queue_http_adapter.dart`

**Result**: Strong design.

The `QueueHttpAdapter` correctly implements `HttpClientAdapter` with a queue of responders that replays the last responder on exhaustion. `callCount` and `lastOptions` fields enable behavioral assertions. Responders can throw, enabling connection-error simulation. The two factory functions (`jsonOk`, `status`) are clean and cover the two cases needed across all interceptor tests.

**Observation — `lastOptions` is nullable but never guarded**: callers use `adapter.lastOptions!` (force-unwrap). This is safe because `lastOptions` is always set when `callCount > 0`, and all callers assert on it only after making a request. The null safety is implicit. Adding a `late RequestOptions lastOptions` and initializing it in `fetch` (removing the nullable `?`) would eliminate the force-unwrap and make the invariant explicit. Minor style suggestion.

#### `test/helpers/fixtures.dart`

**Result**: Correct and minimal.

`fixture(name)` returns raw `String`; `fixtureJson(name)` returns `Map<String, dynamic>`; `fixtureJsonArray(name)` returns `List<dynamic>`. Appropriate separation for DTO (object) and encounter (array) cases. No issues.

---

### Anti-Patterns Found

| Location | Anti-pattern | Issue | Fix |
|---|---|---|---|
| `pokemon_remote_data_source_test.dart:40` | Over-verification | `verify(() => api.getPokemonList(20, 0)).called(1)` is redundant — the mock's `thenAnswer` already guarantees the call happened (the DTO was returned). | Remove the `verify` call; the `expect(result, dto)` assertion is sufficient. |
| `logging_interceptor_test.dart` | Missing side-effect assertion | `LoggingInterceptor` calls `developer.log(...)` on every path but no test confirms logging actually fires. | Inject a `Logger` interface or accept the constraint as inherent to `dart:developer`. If the team later moves to a `package:logging` based approach, this should be revisited. |
| `rate_limit_interceptor_test.dart:45-48` | Helper extracted out of group scope | `_expectImmediateRetry` is a top-level function outside `main()`, used by exactly one test. This scatters the test logic. | Inline as a local `async` function inside the group. |

---

### Recommendations

1. **Assert interceptor order in `dio_client_test.dart`** (Important): Add `expect(dio.interceptors.toList()[0], isA<RateLimitInterceptor>())` and `expect(dio.interceptors.toList()[1], isA<RetryInterceptor>())`. The ordering matters for correctness and is the only structural invariant not currently tested.

2. **Add `fetchSpecies` and `fetchType` success tests + `fetchEncounters` and `fetchEvolutionChain` error tests to `pokemon_remote_data_source_test.dart`** (Important): These four test gaps leave two methods with only a success path, two with only an error path. Each is one `when`/`thenAnswer` + `expect` pair.

3. **Assert at least one `baseStat` value in `pokemon_dto_test.dart`** (Important): The PR3 Min/Max computation reads `baseStat`; a deserialization bug is silent without this check. Use the Bulbasaur fixture's HP stat value.

4. **Add `halfDamageFrom`/`halfDamageTo` assertions to `type_dto_test.dart`** (Important): These lists drive the `0.5×` multiplier in PR3 weakness math. Use the existing `type_electric.json` or `type_poison.json` fixtures.

5. **Add a TE-10 missing-fields test to `pokemon_species_dto_test.dart`** (Suggestion): Consistent with `pokemon_dto_test.dart` and the plan's explicit TE-10 requirement. Pass a minimal map with only required fields and assert the three defaulted lists are empty.

6. **Test `isBaby: true` in `evolution_chain_dto_test.dart`** (Suggestion): Either add an inline minimal JSON object with `"is_baby": true` to one test, or add a baby Pokémon fixture (e.g., Togepi). This confirms Freezed deserializes the boolean when present, not just when absent.

7. **Assert `slot` on `PokemonTypeSlotDto` and at least one stat's `baseStat` in `pokemon_dto_test.dart`** (Suggestion): The `slot` field drives type-ordering in PR3; a zero-default bug is invisible without this check.

8. **Inline `_expectImmediateRetry` in `rate_limit_interceptor_test.dart`** (Suggestion): Move the helper inside the group as a local function for co-location of test logic.

9. **Assert `LoggingInterceptor` response body pass-through** (Suggestion): Add `expect(response.data, {'ok': true})` to the success test in `logging_interceptor_test.dart` to confirm the interceptor does not mutate responses.

---

### Verdict

**Fix before merging — Important issues (4), Suggestions (5).**

The PR1 test suite is well-structured: real fixtures against real DTO shapes, a properly designed fake adapter, mocktail used correctly for the service mock, `callCount` assertions throughout the interceptor tests, and meaningful `DioExceptionType`-to-Failure subtype assertions in `error_mapper_test.dart`. Coverage is reported at 100% and the passing test suite reflects genuine behavioral coverage, not just line hits.

The four Important issues do not represent correctness bugs in the current code — they are test gaps that would fail to catch specific future regressions: interceptor reordering in `dio_client.dart`, silent deserialization bugs on `baseStat`/`halfDamageFrom`, and uncovered method paths in the remote data source. These gaps are acceptable to carry into PR3 only if tracked, but they should be closed before the epic merges.

The Suggestions are all low-effort improvements (one or two `expect` calls each) that increase long-term resilience without changing the test structure.
