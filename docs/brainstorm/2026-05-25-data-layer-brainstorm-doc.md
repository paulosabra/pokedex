---
date: 2026-05-25
topic: data-layer
---

# Layer 1 — Infrastructure & Data (T-06…T-13)

## What We're Building

The **Data ring** of the Clean Architecture onion for Pokédex: everything that turns
the public PokéAPI plus a local SQLite cache into typed domain entities, behind a
single cache-first repository. Concretely, backlog tasks **T-06…T-13** — the Dio HTTP
client with an `ErrorMapper`, a Retrofit `PokeApiService`, faithful Freezed/JSON DTOs,
a Remote DataSource, a Drift database + DAOs (Local DataSource), DTO⇄Entity⇄row
mappers, and the `RepositoryImpl` that orchestrates **cache-first / stale-while-revalidate**
with a TTL (Tech Spec §6, §7, §8; PRD RN-02/16, TE-01…TE-09).

Because the dependency DAG has one architectural back-edge — the mappers (T-12) consume
domain **entities** (T-14) and the repository impl (T-13) consumes the domain **repository
interface** (T-15) — this epic also writes those two domain *enabler* contracts up front,
exactly as the backlog's Agile-Master note prescribes. The remainder of the domain
(use cases T-16, DI/routing T-17) stays in Camada 2.

## Why This Approach

The build is split into **three vertical slices**, mirroring the foundation epic's proven
3-PR cadence and following the DAG's natural seams. The *Remote* and *Local* halves are
genuinely independent (one talks to Dio, the other to Drift; no shared types until the
repository), so each becomes a self-contained, independently-testable PR. The third slice
introduces the domain enablers and converges remote + local in the repository — the only
place the two stacks meet.

Two alternatives were weighed and rejected: a **2-PR split** (all infra, then glue) bundles
two unrelated dependency stacks (Dio + Drift) into one oversized review; a **4+-PR granular
split** shrinks reviews but multiplies CI runs and the per-slice review-report overhead for
little gain at this size.

On dependencies, the epic stays on the **analyzer-9 stable codegen line** rather than chasing
latest. Both new generators this epic — `retrofit_generator` (PR1) and `drift_dev` (PR2) —
ride the same `source_gen`/analyzer fork that already forced `freezed`/`riverpod_generator`
onto exact pins. Holding the line keeps the whole codegen set on **stable** releases and
turns any future fork into a loud version-solve error instead of a silent slide to `-dev`.

On modeling, the line is **faithful external contract, lean internal structure**: full-shape
DTOs for every endpoint the product actually touches, but no speculative internal
abstractions (inline per-repository SWR, not a generic helper).

## Key Decisions

- **3 vertical slices against `epic/data-layer`** — PR1 Remote/Network, PR2 Local/Cache,
  PR3 Domain-glue + Repository. Each slice = `feature/data-layer-partN` → `epic/data-layer`,
  with the 5-agent review committed under `docs/reviews/` as `docs(review):` (per the
  established per-slice flow). Remote (PR1) and Cache (PR2) are independent and could even
  proceed in parallel; PR3 depends on both.

- **Domain enablers folded into this epic (PR3)** — T-14 (entities) and T-15 (repository
  interface) are written here as enabling contracts because T-12/T-13 cannot compile without
  them. Scope is kept *minimal*: only the entities and the one interface the data layer
  consumes. Use cases (T-16) and DI/router (T-17) remain in Camada 2.

- **Shared `features/pokemon/` owns the cross-feature data + domain** — entities,
  `PokemonRepository`, DTOs, mappers, and datasources live in one Pokémon feature; the
  presentation features (`pokemon_list`, `pokemon_detail`, `filters`, `sort`, `generations`)
  depend on it. `core/` keeps only transversal infra (`network/`, `database/`, `error/`).
  This resolves the §3 (feature-first) vs §8 (single app-wide repository) tension in favor of
  an honest shared domain — the literal §3 tree (which split `data/` under `pokemon_list` and
  `pokemon_detail`) is superseded, since one repository serves both.

- **`generationId` derived from a local id-range constant, not fetched** — the `/pokemon` list
  endpoint omits generation, so per the dropped-`GenerationDto` decision (RN-15 generation
  filter is a local id-range query), the summary mapper and `PokemonSummaries.generation_id`
  compute generation from the National-Dex id via a named range constant. No per-Pokémon
  species fetch just to populate the column.

- **Hold the analyzer-9 stable codegen line** — pin `drift`/`drift_dev` to the **2.31.x**
  line (`drift_flutter` 0.2.8, `sqlite3_flutter_libs` 0.5.x) and pin `retrofit_generator`
  to its analyzer-9-compatible release, both **exact** (not caret). Keeps `analyzer` 9,
  `freezed` 3.2.5, `riverpod_generator` 4.0.3 on stable. Accepted cost: `drift` ~2 minors
  behind 2.33, `retrofit_generator` possibly 1 behind latest. Exact pins are the guardrail —
  a caret would re-admit `-dev` prereleases (they sort *above* the stable inside the range).

- **Model encounters now — full external fidelity** — add `GET /pokemon/{id}/encounters`
  to the Retrofit service + a faithful `EncounterDto` (grouped by game version) mapped to
  `List<LocationEntry>`, so `PokemonDetail.locations` is populated end-to-end. This *extends*
  the Tech Spec §7.2 contract, which omitted the endpoint despite the entity (§8.2) and PRD
  Annex B / RF-34 requiring Location. Rationale: Location is a **real displayed About field**,
  so it counts as external reality the product actually touches — unlike the dropped
  `GenerationDto` (which had no consumer at all).

- **Faithful DTOs for every consumed endpoint** — `/pokemon`, `/pokemon/{id}`,
  `/pokemon-species/{id}`, `/evolution-chain/{id}`, `/type/{id}`, `/pokemon/{id}/encounters`.
  Full PokéAPI shape (not lean), accepting larger fixtures and some unused fields for
  round-trip safety and resilience to missing fields (TE-10).

- **Evolution modeled as a tree, not a flat list** — `EvolutionChain { EvolutionNode root }`
  with `EvolutionNode { EvolutionStage stage, List<EvolutionNode> evolvesTo }`. The
  `/evolution-chain` response *is* a tree, and Eevee (#133) — Gen I, guaranteed complete by
  RN-15 — branches into three. This supersedes the Tech Spec §8.2 flat `List<EvolutionStage>`,
  which cannot represent branches. The DTO→entity mapper recurses the chain; UI flattens per
  stage as needed.

- **Cache shape: `payload_json` + indexable columns, 4 tables** (Tech Spec §6.1) —
  `PokemonSummaries` (id, name, primary/secondary type, generation, height, payload, updated_at),
  `PokemonDetails`, `EvolutionChains`, `TypeRelations`. Search/filter/sort run as SQL over
  `PokemonSummaries` for instant offline response (RN-08). `TypeRelations` caches the **18
  static `/type` damage-relation payloads once**, reused across every Pokémon detail — a clear
  earned keep, not speculative.

- **Repository orchestrates a 5-endpoint detail composition** — `getPokemonDetail(id)` fans
  out to `/pokemon` + `/pokemon-species` + `/evolution-chain` + `/type` (×type) +
  `/encounters`, then composes one `PokemonDetail` entity. Cache-first: a valid cached detail
  is served immediately and revalidated in the background; on a cold miss the network fills it;
  on network failure with stale cache, return stale + a stale flag (TE-02); with no cache,
  return `Failure` (TE-01).

- **Inline per-repository SWR, not a generic `staleWhileRevalidate<T>` helper** — one call
  site exists first; abstracting against it is premature (rule of three). Extract later if a
  second consumer proves the duplication.

- **Proactive offline detection via `connectivity_plus`** — model real network state rather
  than inferring offline only from a failed request, so TE-02 (offline-with-cache banner) and
  auto-revalidate-on-reconnect behave correctly.

- **TTL = 7 days, configurable** (RN-16) — Pokémon data changes rarely; `updated_at` per row
  drives expiry; revalidation never blocks the UI. Exposed as a single named constant.

- **`RepositoryImpl` returns `Result<T>`; DTO layer throws** — `DioException`/parse errors are
  mapped to `Failure` at the `ErrorMapper` (T-06) / Remote DataSource boundary and surfaced as
  `Err` by the repository. The domain never sees a `DioException`.

## PR Breakdown (seeds `/plan`)

### PR1 · Remote / Network — T-06, T-07, T-08, T-11
- **Deps added:** `dio`, `retrofit`, `retrofit_generator` (exact, analyzer-9 line). No `intl`:
  `#NNN` is `padLeft(3, '0')` and m/kg is `value / 10` — locale formatting is a presentation
  concern, deferred to the UI epic.
- **Build:** `core/network/` Dio provider (base URL, connect 10s / receive 15s timeouts) +
  interceptors (retry w/ exponential backoff TE-06/07, rate-limit 429 TE-08, logging) +
  `ErrorMapper` (`DioException` → `Failure`). Retrofit `PokeApiService` with the 6 endpoints.
  Faithful DTOs (`PokemonListResponseDto`, `PokemonDto`, `PokemonSpeciesDto`,
  `EvolutionChainDto`, `TypeDto`, `EncounterDto`). `PokemonRemoteDataSource` wrapping the
  service, propagating `Failure`.
- **Tests:** every `DioExceptionType` → correct `Failure`; DTO `fromJson` round-trips against
  real PokéAPI sample payloads (fixtures); RemoteDataSource with a mocked `PokeApiService`.

### PR2 · Local / Cache — T-09, T-10
- **Deps added:** `drift`, `drift_dev`, `drift_flutter` 0.2.8, `sqlite3_flutter_libs` 0.5.x
  (all 2.31.x line, exact). Web WASM assets (`sqlite3.wasm`, `drift_worker.js`) version-matched
  to `pubspec.lock`.
- **Build:** `core/database/` `AppDatabase` with the 4 cache tables (each `updated_at` for TTL),
  conditional connection (`NativeDatabase` mobile/desktop vs WASM web), versioned initial
  migration. `PokemonLocalDataSource` DAOs: upsert/read; search (name case-insensitive +
  accent-insensitive + partial, number with/without leading zeros — RN-06/07); filter by
  type/fraction + sort (number asc/desc, A–Z/Z–A — RF-14…RF-24); reactive `watchSummaries()`
  stream.
- **Tests:** in-memory database; query correctness for search/filter/sort; stream emissions.

### PR3 · Domain glue + Repository — T-14, T-15, T-12, T-13
- **Deps added:** `connectivity_plus`.
- **Build:** `features/pokemon/domain/` entities (`Pokemon`, `PokemonDetail`, `Training`,
  `Breeding`, `StatSet`, `EvolutionChain`, `EvolutionNode`, `EvolutionStage`, `LocationEntry`,
  `Ability`, `PokemonPage`…) — pure Dart, no framework imports — plus the `PokemonRepository`
  interface (`Result<T>` returns + reactive summaries stream). `features/pokemon/data/` mappers
  DTO→Entity and Entity↔cache row, applying Annex B / RN (number `#NNN` RN-03, type order
  preserved RN-05, `generationId` from id-range constant RN-15, gender from `gender_rate` RN-11,
  Min/Max @ level 100 RN-12, weaknesses combining both types RN-10, recursive evolution tree
  RN-13). `RepositoryImpl` cache-first/SWR/TTL with the 5-endpoint detail composition +
  `connectivity_plus` gating.
- **Tests:** **100% mapper coverage** (highest bug risk — Principle 11); **all repository
  decision branches** (cache hit / miss / stale / error) covered with fake datasources.

## Open Questions

- **RN-07 accent-insensitive search implementation** — SQLite `LIKE` is ASCII-case-insensitive
  only and not accent-folding. Resolve in PR2 planning: store a normalized `name_normalized`
  column (lowercased, diacritics stripped) and query against it (SQL-native, preferred) vs.
  filter in Dart. Dataset is bounded (Gen I = 151; full ≈ 1000), so either is viable.
- **Exact resolvable pins** — confirm at plan time, via a real dependency resolution, the exact
  `drift`/`drift_dev`/`retrofit_generator` versions that co-resolve on analyzer 9 with
  `freezed` 3.2.5 / `riverpod_generator` 4.0.3 (lock from evidence, not from the memory snapshot).
- **Drift web WASM verification** — validate the WASM connection on a real web target; confirm
  the release asset is `drift_worker.js` (not `drift_worker.dart.js`) and assets are
  version-matched; degrade path via `DriftWebOptions.onResult` → in-memory.
- **`EncounterDto` shape** — `/encounters` returns `LocationAreaEncounter[]` (location_area +
  version_details[]); decide how much of the version grouping to map into `LocationEntry` for
  the About section vs. flatten.
- **Image/artwork caching (RN-17, TE-11)** — `cached_network_image` is a UI-layer concern
  (deferred to the UI epic); confirm nothing in the data layer needs to pre-cache artwork.
