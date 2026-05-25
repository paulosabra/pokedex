# Architecture Review — PR2 (Data Layer · Drift Cache + DAO/Local DataSource)

**Branch:** `feature/data-part2` → `epic/data-layer`
**Tasks:** T-09 (Drift cache) + T-10 (DAO / local data source); T-14 enablers (`sort_criteria`, `pokemon_filter`) pulled forward.
**Plan:** `docs/plan/2026-05-25-feat-infrastructure-data-layer-plan.md` · **Tech Spec:** `docs/project/02-tech-spec.md §6, §8.4`
**Reviewer scope:** PR2 source only (uncommitted, untracked). Generated `*.g.dart`/`*.drift.dart`/`*.freezed.dart` ignored. Mappers/repository (PR3) absence not flagged.
**Date:** 2026-05-25

## Files reviewed

- `lib/core/database/app_database.dart` — Drift tables + `AppDatabase` (T-09)
- `lib/core/database/cache_policy.dart` — TTL constants (T-09)
- `lib/features/pokemon/domain/entities/sort_criteria.dart` — domain enum (T-14 enabler)
- `lib/features/pokemon/domain/entities/pokemon_filter.dart` — domain freezed entity (T-14 enabler)
- `lib/features/pokemon/data/summary_encoding.dart` — shared `normalizeName` / `typeWeaknessMask`
- `lib/features/pokemon/data/datasources/pokemon_local_data_source.dart` — abstract interface
- `lib/features/pokemon/data/datasources/pokemon_dao.dart` — Drift DAO impl
- Config: `analysis_options.yaml`, `.gitignore`, `pubspec.yaml`
- Tests (context only): `pokemon_dao_test.dart`, `summary_encoding_test.dart`, `pokemon_filter_test.dart`

---

## Architecture Review

### Layer Separation

**Violations found: 0.**

The single hardest constraint for this PR — **no `core/` → `features/` dependency** — holds. Verified by import grep:

- `lib/core/database/app_database.dart` imports only `package:drift/drift.dart` and `package:drift_flutter/drift_flutter.dart`. **Zero** `package:pokedex/features/...` imports. (`grep -rn "package:pokedex/features" lib/core/` → none.)
- `lib/core/database/cache_policy.dart` has no imports at all (pure constants).
- `lib/core/pokemon/pokemon_type_id.dart` has no imports.

This is the architecturally load-bearing decision of the PR, and it is correct: **`PokemonDao` is deliberately NOT registered in `@DriftDatabase(daos: [...])`** — it lives in `features/pokemon/data/datasources/` and is constructed manually (`PokemonDao(db)`). Registering it would force `app_database.dart` to `import` the DAO file, which lives under `features/`, inverting the layer rule. The DAO instead reaches *up the allowed direction* — `data` → `core/database` — via `DatabaseAccessor<AppDatabase>`. This is the canonical way to keep a Drift schema in a low layer while the accessor lives in a feature, and the implementation nails it.

Per-file direction check (all legal under VGV layered / Clean Architecture):

| File | Layer | Imports | Verdict |
| --- | --- | --- | --- |
| `core/database/app_database.dart` | core/infra | drift, drift_flutter | Clean — infra only |
| `core/database/cache_policy.dart` | core/infra | (none) | Clean |
| `domain/entities/sort_criteria.dart` | domain | (none — pure Dart enum) | Clean |
| `domain/entities/pokemon_filter.dart` | domain | freezed_annotation, `core/pokemon` | Clean — meets the T-14 constraint exactly |
| `data/summary_encoding.dart` | data | `core/pokemon` | Clean |
| `data/datasources/pokemon_local_data_source.dart` | data | `core/database`, `domain/entities` ×2 | Clean — data may depend on core + domain |
| `data/datasources/pokemon_dao.dart` | data | drift, `core/database`, local DS, `summary_encoding`, `domain/entities` ×2 | Clean — all permitted downstream/peer deps |

**Domain purity (entities) — confirmed.** `grep` for `package:drift`/`package:dio`/`package:retrofit`/`features/.../data`/`core/database`/`core/network` across `lib/features/pokemon/domain/` returned **none**. `sort_criteria.dart` is pure Dart; `pokemon_filter.dart` imports only `freezed_annotation` + `core/pokemon/pokemon_type_id.dart`. Both meet the plan's T-14 rule ("only `freezed_annotation` + `core/pokemon`, no drift/infra") to the letter. `HeightCategory` correctly lives in the domain alongside `PokemonFilter` (it is a filter concept), while the *decimetre thresholds* that interpret it live in the data layer (`pokemon_dao.dart` `_shortMaxDecimetres`/`_tallMinDecimetres`) — the documented Tech-Spec split ("PRD defines categories, data layer owns concrete values") is honored, keeping the domain unit-agnostic.

**`core/` stays free of feature/domain imports — confirmed.** All three core files are clean.

**Clean files: all checked files clean.**

### State Management Assessment

No Riverpod/Bloc units are in scope for PR2 (state wiring is T-17 / Camada 2). The relevant analogue here is **data-source / DAO design**, assessed against the same VGV principles (naming, immutability, single responsibility, DIP, lifecycle):

- **`PokemonLocalDataSource` (abstract interface): Correct.**
  - Descriptive, convention-following name (`*LocalDataSource`); `abstract interface class` gives a clean DIP seam so PR3's repository can be tested against a fake (the docstring says exactly this). This matches Tech Spec §8.4's intent of "implementado via Drift DAO".
  - **Returns raw Drift rows, no entity leakage — confirmed and correct.** Every read returns `PokemonSummaryRow?` / `PokemonDetailRow?` / `EvolutionChainRow?` / `TypeRelationRow?` or `List<PokemonSummaryRow>`; `watchSummaries` streams `List<PokemonSummaryRow>`. No `Pokemon`/`PokemonDetail` domain entity appears. Row→entity mapping is correctly deferred to PR3, exactly as the plan's reconciliation table prescribes (superseding Tech Spec §8.4's older `PokemonDetail?` return signature — the plan is the authoritative reconciliation record, so this is *not* a deviation to flag).
  - **Business-logic placement: Correct.** Search disambiguation (numeric vs name), filter intersection, height bucketing, weakness bitmask, and ordering all live in the DAO (the data layer), reachable as SQL — not in a UI callback. RN-08 "all search/filter/sort over the cache" is satisfied at the right layer.
  - **Single responsibility:** read/write + query/watch over the cache. Focused; no grab-bag.

- **`PokemonDao` (concrete impl): Correct, with two notes (see Suggestions).**
  - `implements PokemonLocalDataSource` + `extends DatabaseAccessor<AppDatabase>` with `_$PokemonDaoMixin` — idiomatic Drift, and the `implements` keeps the abstraction honest.
  - Query construction is factored into one private `_summaryQuery` shared by `querySummaries`/`watchSummaries` (no duplication between the one-shot and reactive paths) — good. `_heightPredicate` and `_ordering` are clean, exhaustive `switch`es over the domain enums.
  - Lifecycle: the DAO holds no resources of its own; `AppDatabase` owns the connection and is disposed by its owner (`db.close()` in tests; provider scope in T-17). Appropriate — the DAO does not over-manage lifecycle.

### Dependency Direction

**Direction violations: 0. Circular dependencies: 0.**

The PR2 dependency graph flows strictly one way:

```
domain/entities (sort_criteria, pokemon_filter)   ← pure
        ▲                         ▲
        │                         │
data/datasources (local DS, DAO) ─┘
        │
        ├──► core/database (app_database, cache_policy)   [infra]
        ├──► core/pokemon  (pokemon_type_id)              [shared leaf]
        └──► data/summary_encoding                        [data peer]

core/database ──► drift, drift_flutter ONLY  (never features/)
```

- **`data` → `domain`: legal and present.** The DAO and local DS depend on `PokemonFilter`/`SortCriteria`/`HeightCategory`. This is the correct direction (Clean Architecture: data may know the domain contracts it serves).
- **`data` → `core/database`: legal.** DAO accesses the schema/companions; local DS references companion/row types from the schema.
- **`core/database` → `features/*`: absent.** The back-edge that would break the rule does not exist (the whole reason the DAO is unregistered). Verified.
- **No circulars.** `domain` imports nothing from `data`/`core/database`; `core` imports nothing from `features`. `summary_encoding` (data) → `core/pokemon` (leaf) only.

**Shared `summary_encoding` placement — sensible and correct.** It sits in the **data layer** (`features/pokemon/data/summary_encoding.dart`), depends only on `core/pokemon`, and exposes the two encodings (`normalizeName`, `typeWeaknessMask`) that **must agree between the PR2 DAO query and the PR3 cache mapper**. Putting the canonical bit-layout / normalization in one data-layer module that both PRs import is exactly right: it prevents the classic "writer and reader disagree on the encoding" bug, and it does not pollute the domain (the encoding is a storage/index concern, not a business rule). The DAO already consumes both (`normalizeName(term)` for search, `typeWeaknessMask(filter.weaknesses)` for the mask filter), proving the shared contract works end to end.

**Clean dependencies:** all PR2 edges.

### Package Structure

This is a single-package app (`pokedex`), so "package structure" maps to **module/layer folder structure** plus the build/lint config that governs generated code.

- **Folder placement: Complete.** Files land where the plan's target tree specifies: cache infra under `core/database/`, domain enablers under `features/pokemon/domain/entities/`, data sources under `features/pokemon/data/datasources/`, shared encoding under `features/pokemon/data/`. UI is correctly absent (Camada 2).
- **Test directories: Complete.** Mirror structure present: `test/features/pokemon/data/datasources/pokemon_dao_test.dart`, `test/features/pokemon/data/summary_encoding_test.dart`, `test/features/pokemon/domain/entities/pokemon_filter_test.dart`.
- **Generated-code config: Complete and correct.** `analysis_options.yaml` and `.gitignore` both add `*.drift.dart` (keeping the 1:1 ignore/analysis invariant from the project memory). This is defensive — `part`-mode drift emits `*.g.dart`, but the glob protects against a future switch to modular output. Good.
- **Dependency manifest: Correct and well-justified.** `pubspec.yaml` pins `drift 2.31.0` / `drift_dev 2.31.0` / `drift_flutter 0.2.8` exact, with an inline comment explaining the analyzer-9 stable-codegen rationale (2.32.0 → analyzer ^10 would drag freezed/riverpod onto `-dev`). `sqlite3_flutter_libs ^0.5.24` added; `json_annotation` bumped `^4.9.0`→`^4.11.0`. These match the plan's locked pins exactly.
- **Single clear responsibility per file:** each file does one thing (schema; TTL; enum; filter; encoding; DS contract; DAO). No grab-bag.

**`AppDatabase`: Complete.** Four tables (`PokemonSummaries`, `PokemonDetails`, `EvolutionChains`, `TypeRelations`), each with `updatedAt` epoch-ms for TTL (RN-16); `nameNormalized` column resolves RN-07 SQL-natively; `weaknessMask` with `withDefault(0)` (populated PR3); `payloadJson` documented as opaque to the cache layer (entity serialization owned by PR3 mappers). `forTesting` ctor enables in-memory tests; `schemaVersion = 1` + `MigrationStrategy(onCreate: createAll)`. Web-safe: no `dart:io`/`dart:ffi` in the non-generated data layer (verified by grep); the web connection is handled by `drift_flutter`'s `driftDatabase(web: DriftWebOptions(...))`.

---

## Findings (ranked)

### Critical
None. The PR is architecturally sound; the one non-negotiable rule (no core→feature) is upheld.

### Important
None. (The items below are suggestions, not merge-blockers.)

### Suggestions

**S1 — `PokemonTypeId.index` is now a persistence contract, but the enum carries no guard comment.**
`primaryTypeId`/`secondaryTypeId` store `PokemonTypeId.index`, and `weaknessMask` packs `1 << type.index` per the `typeWeaknessMask` encoding (`summary_encoding.dart:52`). That makes the **declaration order of `PokemonTypeId` a stored schema invariant**: reordering or inserting a value mid-enum silently corrupts every cached row and bitmask written under the old order (with `schemaVersion = 1` and no migration to rewrite them). The enum (`lib/core/pokemon/pokemon_type_id.dart`) has no comment warning that the order is load-bearing for persistence (`grep` for any "order/persist/stable/do not reorder" guard → none). This is not a bug today, but it is a latent foot-gun for a future contributor. *Recommendation:* add a one-line doc note on the enum ("Ordinal `index` is persisted in the Drift cache and packed into `weaknessMask`; appending is safe, reordering/inserting is a breaking schema change requiring a migration + `schemaVersion` bump"). Cheap insurance; no code change.

**S2 — Plan/impl deltas in the connection strategy and `daos:` registration — confirm they are intentional (they appear to be sound improvements).**
The plan's T-09 text (and Tech Spec §6.2) described a `core/database/connection/` directory with conditional `native.dart`/`web.dart`/`connection.dart` exports, and `@DriftDatabase(tables: [...], daos: [PokemonDao])`. The implementation instead:
  (a) uses `drift_flutter`'s single `driftDatabase(name:, web: DriftWebOptions(...))` inline in `_openConnection()` — no `connection/` directory; and
  (b) uses `@DriftDatabase(daos: [])` (PokemonDao unregistered, constructed manually).
Both deltas are **architecturally *better* than the plan**, not regressions: (a) `drift_flutter` is the current idiom and removes hand-rolled conditional-import boilerplate while still being web-safe (no `dart:io` leaks into `lib`); (b) is exactly what keeps `core/` free of a `features/` import — registering the DAO as the plan literally wrote it (`daos: [PokemonDao]` inside `core/database/app_database.dart`) would have *created* the core→feature violation. So the implementation correctly diverged from the plan to *preserve* the dependency rule. *Recommendation:* none required for merge; note this delta in the PR description so a reviewer cross-checking against the plan isn't surprised, and so the plan can be retro-annotated (the plan already set the precedent of recording reconciliations).

**S3 — `secondaryTypeId.isIn(ids)` NULL semantics — verify intent (likely already correct).**
The type filter uses `t.primaryTypeId.isIn(ids) | t.secondaryTypeId.isIn(ids)` (`pokemon_dao.dart:116`). In SQL, `NULL IN (...)` evaluates to `NULL` (not `false`), but because it is OR-combined with the non-nullable `primaryTypeId.isIn(ids)` inside a `WHERE`, the row is correctly included iff *either* matches — single-type mons (null secondary) are not wrongly excluded. The DAO test ("by primary or secondary type") confirms the behavior. This is a *correctness*/test concern more than architecture; raised only so the SQL NULL nuance is on record. No change needed.

---

## Verdict

**Architecture is clean — ready to merge (from an architecture standpoint).**

The defining constraint of this PR — keeping the Drift schema in `core/` while the DAO lives in `features/`, with **no core→feature edge** — is implemented correctly and deliberately (unregistered DAO + manual construction). The dependency rule holds in every direction: domain entities are pure, the data layer depends only downstream (core/infra) and on domain contracts, and there are no circular edges. The local data source returns raw Drift rows with row→entity mapping correctly deferred to PR3, and the shared `summary_encoding` is placed sensibly in the data layer so PR2's query and PR3's mapper share one canonical encoding. The three findings are all non-blocking suggestions; **S1 (enum-order persistence guard)** is the most valuable cheap follow-up.

**Critical: 0 · Important: 0 · Suggestions: 3.**
