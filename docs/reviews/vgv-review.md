# VGV Code Review — Data Layer PR3 (Domain glue + Cache-first Repository)

**Scope:** uncommitted/untracked work on `feature/data-part3` → `epic/data-layer` (backlog T-14, T-15,
T-12, T-13). Reviewed against `docs/plan/2026-05-25-feat-infrastructure-data-layer-plan.md`. Generated
`*.g.dart`/`*.freezed.dart`/`*.drift.dart` ignored. Documented deviations (a)–(e) from the task brief
treated as accepted by design.

**Stack detected:** Flutter (Dart `^3.12.0`), Freezed + `json_serializable` (`build.yaml`
`field_rename: snake`), Drift 2.31 cache, Dio/Retrofit remote, `connectivity_plus ^7.1.1`, `very_good_analysis`
lints, `flutter_test` + `mocktail` + in-memory Drift for tests. Layered Clean Architecture
(core → data → domain).

---

## Summary

This is a strong, ship-quality slice. The domain layer is verifiably pure (no dio/drift/retrofit/
connectivity/flutter imports — grep-confirmed clean), entities are immutable Freezed value types with
precise doc comments tying each field to its PRD rule, mappers are pure top-level functions, and the
cache-first/SWR repository is faithfully implemented with an inline-per-method decision machine (no
premature generic helper). Test quality is excellent: fixture-driven, field-by-field assertions, real
in-memory Drift in the repository tests (fakes where they earn it, real DB where it adds fidelity), and
the documented edge cases (4× weakness, 0× immunity, branching Eevee, partial compose, corrupt cache,
pagination boundaries, type-cache reuse) are all exercised. The business rules (RN-10 weakness math,
RN-11 gender, RN-12 min/max, RN-13 evolution tree, RN-15 generation) are correct against the fixtures.

There is **one genuine correctness gap**: the repository's corrupt-cache recovery catches only
`FormatException`, but a valid-JSON-but-wrong-shape `payloadJson` deserializes via generated
`fromJson` that throws `TypeError` (`json['id'] as num` on a null), which would escape as a raw throw —
violating the plan's explicit T-13 guarantee that "no datasource exception escapes" and "every path
resolves to `Ok`/`Err`." This is narrow (only triggers on schema-evolution / partial-write payloads,
not on the `'not-json'` case the tests cover) but it is exactly the kind of resilience the cache-first
design promises. Fix it and this is ready to merge.

**Verdict: needs work (one Important fix), then ready to merge.**

---

## 🔴 Critical — Must Fix Before Merge

None.

---

## 🟡 Important — Should Fix

- **`lib/features/pokemon/data/repositories/pokemon_repository_impl.dart:262-268` (and `:173`)** —
  corrupt-cache recovery only catches `FormatException`; a structurally-invalid (but JSON-valid)
  `payloadJson` escapes as a raw `TypeError`.
  - Why: `detailFromRow`/`pokemonFromRow`/`evolutionFromRow` do `jsonDecode(...) as Map` (throws
    `FormatException` only when the *text* is not JSON) **then** call the generated `fromJson`. The
    generated decoder is `id: (json['id'] as num).toInt()`, `name: json['name'] as String` — a payload
    like `{}` or one written by a previous entity shape (after a future Freezed field change) throws a
    `TypeError`/`CheckedFromJsonException`, **not** `FormatException`. `_tryParse` (used by
    `getPokemonDetail`) and `_readSummaries` (used by `search`/`filter`) both catch only
    `FormatException`, so that `TypeError` propagates out of the repository. This directly breaks the
    plan's stated T-13 guarantee ("No datasource exception escapes as a raw throw — every path resolves
    to `Ok`/`Err`"; plan L591-592) and the documented corrupt-cache contract ("corrupt → CacheFailure
    offline / miss online"). The existing tests only seed `'not-json'`, which *is* a `FormatException`,
    so the gap is untested.
  - Fix: broaden the parse guard to also cover deserialization errors. e.g. catch `on Object` (or
    `on FormatException` + `on TypeError` + `on CheckedFromJsonException`) inside `_tryParse` and the
    `_readSummaries` try block, treating any decode failure as "corrupt row" → the same miss/offline
    branch. Add two regression tests: a detail row with `payloadJson: '{}'` (valid JSON, wrong shape)
    online → recomposed, offline → `CacheFailure`; and a summary row with `payloadJson: '{}'` →
    `search` returns `CacheFailure`. Mirror the same guard in `getEvolutionChain` (`_tryParse` at
    `:129`).

---

## 🔵 Suggestions — Nice to Have

- **`pokemon_repository_impl.dart:55-57`** — `_ensureAllTypeRelations()` runs **before** the page is
  known to be non-empty, so an offset-past-end (or otherwise empty) page still pre-warms all 18 type
  relations (up to 18 network calls / cache reads) that nothing consumes.
  - Suggestion: move `_ensureAllTypeRelations()` after computing `ids` and short-circuit when
    `ids.isEmpty` (return `Ok(PokemonPage([], hasMore: ...))` first). The "offset past the end" test
    currently passes only because `fetchType` is stubbed; the reorder makes the empty-page path do no
    wasted work and removes the hidden dependency on that stub.

- **`pokemon_repository_impl.dart:57`** — `Future.wait(ids.map(_remote.fetchPokemon))` fans out the
  per-id N+1 with **unbounded** parallelism, whereas the plan specified "bounded-parallel" (plan
  L567/L575).
  - Suggestion: cap concurrency (e.g. chunked `Future.wait`, or a small pool). For a 20-item page this
    fires 20 simultaneous requests; the PR1 rate-limit/retry interceptors make it *safe*, but bounding
    it honors the plan and is gentler on the public API. Low priority for MVP.

- **`pokemon_detail_mapper.dart:22`** — `_whitespace = RegExp(r'\s+')` already matches `\n`/`\r`/`\f`,
  so `_control = RegExp('[\f\n\r­]')` is partially redundant; its load-bearing member is the soft
  hyphen (`­`, U+00AD). The two-pass `replaceAll(_control,' ')` then `replaceAll(_whitespace,' ')` is
  correct (soft-hyphen → space → collapsed), just slightly more machinery than needed.
  - Suggestion: optional — a single `replaceAll(RegExp('[­\\s]+'), ' ').trim()` collapses both in
    one pass. Behavior is identical; this is purely a tidiness note, not a bug. Keep the doc intent
    clear if you change it.

- **`pokemon_repository_impl.dart:30-35`** — the injected clock uses a trailing **positional optional**
  `[this._now = DateTime.now]`. It works and is tested, but VGV leans toward named parameters for
  constructor injection of cross-cutting dependencies (readability at the call site).
  - Suggestion: optional — `{DateTime Function() now = DateTime.now}`. Minor; the current form is fine
    and already covered by `() => clock` in tests.

---

## Simplicity Assessment

- **Lines that could be removed:** ~0 meaningful. The code is already lean. The only candidate is the
  minor regex redundancy in the detail mapper (cosmetic, not a deletion).
- **Unnecessary abstractions:** none. The SWR decision machine is inlined per method (rule-of-three
  respected — no speculative generic helper). `_tryFetch`/`_tryParse`/`_isFresh`/`_isOnline` are small,
  single-purpose, and each used 2+ times — they earn their keep. The `PokemonRemoteDataSource` /
  `PokemonLocalDataSource` interfaces are justified by DIP + the fake/real-DB test strategy (documented,
  matches Tech Spec §8.4).
- **YAGNI violations:** none. `getEvolutionChain` has a named downstream consumer (T-16/T-26).
  `TypeEffectiveness` carries `weaknesses` + `typeDefenses` + `weaknessMask` — all three are consumed
  (detail entity + SQL mask), not speculative.
- **Complexity verdict:** Already minimal. The `getPokemonDetail` branch ladder is the densest spot but
  reads cleanly with early returns and an explanatory comment per branch; no refactor warranted.

---

## Testing Assessment

- **New code with tests:** ✅ Every new mapper, the repository, the generation ranges, and the cache
  mappers have dedicated test files. Domain entities are exercised transitively through the mapper +
  cache round-trip tests (entities are pure Freezed data — no logic beyond `StatSet.total`, which is
  asserted in `pokemon_detail_mapper_test.dart:110`).
- **Test quality:** Meaningful. Fixture-driven with **per-field** assertions (not blanket equality
  only), real-PokéAPI fixtures (Bulbasaur, Pikachu, Eevee, Ditto, grass/poison/ground/electric types),
  and named edge cases. The repository test uses a **real in-memory Drift DAO** rather than mocking the
  local source — high fidelity, catches serialization/SQL bugs a mock would hide. No tautologies, no
  "doesn't throw"-only tests, no over-verification (call counts used only where the SWR contract demands
  it — `verify(fetchPokemon).called(1)` for background revalidation, `verifyNever(fetchType)` for
  type-cache reuse).
- **RN business-rule coverage:** RN-10 (single, dual, 4×, 0× immunity, missing-relation degrade),
  RN-11 (gendered % + genderless Ditto), RN-12 (HP + non-HP min/max with exact arithmetic), RN-13
  (linear chain conditions, branching Eevee, held-item/known-move triggers), RN-15 (every generation
  boundary + out-of-range → 0, including the fixed `generationForId(0)` lower-bound). All present.
- **Repository branch coverage:** offline list/detail/evolution; cold-miss compose+cache; fresh hit +
  background revalidate; stale + net-success; stale + net-failure → `Ok(stale)`; corrupt online → miss;
  corrupt offline → `CacheFailure`; partial compose (species fail) not cached; type+encounters degrade;
  type-cache reuse; pagination `hasMore` true/false + offset-past-end; search/filter/watch + corrupt
  summary → `CacheFailure`. Matches the plan's enumerated branch list.
- **State management test coverage:** N/A this slice (no Bloc/Cubit — repository + mappers only; state
  management lands in Camada 2 / T-16+).
- **UI component test coverage:** N/A this slice (no UI in PR3, by design).
- **Gap:** the corrupt-cache tests use `'not-json'` (a `FormatException`) only; the valid-JSON-wrong-
  shape path that the Important finding describes is **untested** and currently unhandled. Adding those
  two regression tests is the concrete proof for the fix.

---

## Architecture & Convention Notes (PASS)

- **Dependency rule:** ✅ `domain/` imports only `freezed_annotation`, `core/error`, `core/pokemon`,
  and sibling entities — grep-confirmed no `dio`/`drift`/`retrofit`/`connectivity_plus`/`flutter/`
  leak, and no `data/` or `core/database/` import. The repository (data layer) correctly depends
  *inward* on the domain interface (DIP).
- **Layer placement:** ✅ mappers and `RepositoryImpl` live in `data/`; the abstract `PokemonRepository`
  and entities in `domain/`. Cache mappers correctly own the row↔entity boundary so the local data
  source stays entity-free (matches the §8.4 reconciliation).
- **Error vocabulary:** ✅ all fallible one-shots return `Result<T>`; `watchCachedSummaries` returns a
  plain `Stream<List<Pokemon>>` (deliberate, documented). Failures use the sealed `Failure` taxonomy;
  the repository catches `on Failure` and re-wraps as `Err` — datasource throws never leak as
  `DioException`.
- **Mapper correctness:** ✅ type order by slot (RN-05), unknown type names dropped (TE-10),
  `generationForId` ranges correct incl. the fixed lower-bound guard, gender eighths math, min/max
  formulas (HP vs non-HP), weakness product over defender types with neutral-on-missing degrade,
  evolution condition precedence (level → item → trade → happiness → held-item → known-move → time →
  location), soft-hyphen/control-char sanitization. `_factor` matches PokéAPI type slugs against
  `PokemonTypeId.name` — correct, and `pokeApiTypeIds` (API ids) is correctly kept distinct from
  `PokemonTypeId.index` (persisted contract).
- **Immutability & naming:** ✅ all entities immutable Freezed; names pass the 5-second rule
  (`computeTypeEffectiveness`, `pokemonDetailFromDtos`, `PokemonRepositoryImpl`, `kUnknownGenerationId`,
  `_ensureAllTypeRelations`). No `Manager`/`Handler`/`Utils`.
- **Cleanliness:** ✅ no lint suppressions, no `TODO`/`FIXME`, no `print`/`debugPrint`, no commented-out
  code in the new files. `connectivity_plus` pinned `^7.1.1` per plan (v7 `List<ConnectivityResult>`
  API used correctly in `_isOnline`). `macos/.../GeneratedPluginRegistrant.swift` change is the expected
  auto-generated connectivity_plus registration.
- **Documented deviations honored:** entity-with-json for symmetric cache payload (a), online-only
  `getEvolutionChain` via species (b), 4-endpoint detail compose with evolution on-demand (c),
  persisted `PokemonTypeId.index` guarded by the PR2 comment (d), `generationForId(0)` lower-bound fix
  (e) — all verified as implemented.

## Regressions & Breaking Changes (PASS)

- No existing files deleted or weakened; PR3 is purely additive (entities, repo interface, mappers,
  repo impl, tests) plus `pubspec` (`connectivity_plus`) and the generated macos registrant.
- No public API of PR1/PR2 changed. The repository consumes the existing
  `PokemonRemoteDataSource`/`PokemonLocalDataSource`/`PokemonDao` and `summary_encoding`
  (`normalizeName`, `typeWeaknessMask`) without modification.
- `pubspec.yaml` adds one runtime dependency with a sensible caret pin; no removals or downgrades.
