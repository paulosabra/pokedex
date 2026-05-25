# Architecture Review — PR3 (data-layer epic)

**Branch:** `feature/data-part3` · **Scope:** T-14 (entities), T-15 (repository interface), T-12 (mappers), T-13 (RepositoryImpl), `connectivity_plus`
**Standard:** VGV layered monorepo / Clean Architecture onion + the dependency rule
**Plan:** `docs/plan/2026-05-25-feat-infrastructure-data-layer-plan.md`
**Reviewed:** 2026-05-25

PR3 converges the PR1 (remote) and PR2 (cache) halves into pure domain entities served by a single
cache-first `PokemonRepository`. This review confirms the dependency-rule invariants, the DIP wiring,
the mapper translation boundary, and the cache round-trip. The architecture is sound; findings below
are one structural smell that predates PR3 but first bites here, plus minor observations.

---

## Layer Separation

**Violations found in PR3 source: 0.** Independently verified — not relying on the author's grep.

### Domain purity (CRITICAL invariant 1) — PASS for PR3 code

`grep -rE "package:(dio|drift|retrofit|connectivity_plus|flutter)/|features/.../data/"` across
`lib/features/pokemon/domain/**` (excluding generated `*.g.dart`/`*.freezed.dart`) returns nothing.
The complete set of distinct imports in domain source is:

- `package:freezed_annotation/freezed_annotation.dart`
- `package:pokedex/core/error/result.dart`
- `package:pokedex/core/pokemon/pokemon_type_id.dart`
- sibling `domain/entities/*.dart`

Generated domain files (`*.g.dart`, `*.freezed.dart`) were also checked for transitive infra leaks —
clean (they pull only `freezed_annotation`/`json_annotation` plumbing, never dio/drift/retrofit/
connectivity). `sort_criteria.dart` and `pokemon_filter.dart`/`pokemon_page.dart` correctly carry no
`.g.dart` part (no `fromJson` — they are not cached), which is the right call.

The `PokemonTypeId` enum is consumed from `core/pokemon/` exactly as the foundation plan intended, so
the domain reaches a shared kernel rather than a presentation back-edge. Good.

### Data layer dependencies (CRITICAL invariant 2) — PASS

`pokemon_repository_impl.dart` (data) depends on: domain entities, the `PokemonRepository` interface,
`PokemonRemoteDataSource`, `PokemonLocalDataSource`, the five mappers, `connectivity_plus`,
`core/database` (Drift companions/rows), `core/error`, `core/pokemon`. Every one of these flows
downward or sideways within the data ring or into the shared kernel. No data→presentation edge exists
(there is no presentation layer yet). Correct.

Data legitimately depends on domain in three more places, all valid (data → domain is the allowed
direction): the DAO and `PokemonLocalDataSource` import `PokemonFilter`/`HeightCategory`/`SortCriteria`;
the mappers import the entities they produce.

### `core/error` → Flutter coupling (CRITICAL invariant 1, transitive) — IMPORTANT

`lib/core/error/failure.dart:1` imports `package:flutter/foundation.dart` (for `@immutable`). The
domain depends on this file transitively: every entity returns through `Result<T>` (interface T-15)
and `Result` → `Failure` → `package:flutter`. So the *pure-Dart* domain layer in fact transitively
imports Flutter.

- **Provenance:** introduced in foundation commit `6df22e8 feat(core)`, hardened in `1ec3f92`
  (PR1). It is **not** a PR3 change — `git status` shows no modification under `lib/core/`.
- **Why flag it in PR3 anyway:** PR3 is the PR that makes the domain layer *exist* and makes it
  depend on `Result`/`Failure`. Before PR3 nothing claimed to be a "pure Dart, no-framework" layer;
  now `T-14`'s acceptance criterion ("no framework imports") and the plan's Principle 8 / line 633
  ("`domain/` may import only `dart:core`, `freezed_annotation`, `core/error`, `core/pokemon`") are
  on record — and `core/error` silently violates the spirit of that allow-list because it drags in
  Flutter. The plan explicitly lists `core/error` as a permitted dependency *on the assumption it is
  framework-free* (the same paragraph justifies keeping `ErrorMapper` out of `core/error` "to keep the
  dio-free domain['s] transitive imports" clean — the identical reasoning applies to Flutter).
- **Impact:** today, low — the app is Flutter-only, so nothing breaks. But it forecloses ever
  extracting `domain` (or `core/error`) into a pure-Dart package, and it makes the "pure domain"
  claim technically false. It also means a future pure-Dart unit test of an entity transitively
  loads `package:flutter`.
- **Fix (one line, trivial):** replace `import 'package:flutter/foundation.dart';` +
  `@immutable` with `import 'package:meta/meta.dart';` (`meta` re-exports `@immutable` and is a
  pure-Dart package already in the transitive set). `core/error` then becomes genuinely
  framework-free and the domain allow-list holds literally, not just by convention.

This is the single structural finding worth fixing before the layer ossifies. It is **Important**, not
Critical, because it is a transitive/latent coupling with zero runtime effect today and a one-line
remedy — but it should be fixed in this PR (or a fast follow) while `core/error` has exactly one
offending line, rather than after presentation code piles on.

**Clean files (PR3):** all domain entities, both repository contracts, all five mappers,
`summary_encoding.dart`, and `pokemon_repository_impl.dart` are clean on the layer rule.

---

## State Management Assessment

No state management (Bloc/Riverpod) lands in PR3 — providers/use cases are T-16/T-17 (Camada 2). The
reviewable analogue is the repository's collaborator wiring and lifecycle:

- **`PokemonRepositoryImpl`: Correct.** All four collaborators (`PokemonRemoteDataSource`,
  `PokemonLocalDataSource`, `Connectivity`, `DateTime Function() now`) are **constructor-injected**;
  there is no global state, no service locator, no `DateTime.now()` called inline (the clock is
  injected and defaults to `DateTime.now`, which makes TTL branches deterministically testable). This
  is textbook DI and is exactly what enables the fakes-not-mocks repository tests the plan calls for.
- **Naming: Correct.** `PokemonRepositoryImpl`, `pokemonFromDto`, `computeTypeEffectiveness`,
  `summaryToCompanion` are descriptive and domain-vocabulary-aligned — no `Manager`/`Handler`/`Data*`
  grab-bags.
- **Business logic location: Correct.** All rules (weakness math, gender, min/max, generation ranges,
  evolution condition derivation, sanitization) live in pure top-level mapper functions in the data
  layer, not smeared across the repository or (later) UI. The repository orchestrates; the mappers
  translate. Clean separation of "decide" vs "transform".
- **Disposal/lifecycle:** the repository owns no streams/subscriptions it must dispose; it maps the
  DAO's `watchSummaries` stream lazily (`.map`) and returns it — disposal belongs to the consumer
  (correct, the repo did not create the source). `Connectivity` is injected, not constructed, so its
  lifecycle is the composition root's concern (T-17). No leak.

No state-management violations.

---

## Dependency Direction

The dependency graph flows one way; **no reverse or circular edges found.**

```
presentation (none yet)
        │
        ▼
   domain/entities  ◄──────────────┐ (the documented, intended back-edge:
   domain/repositories (interface)  │  mappers + impl consume domain, per plan L20-24)
        ▲              ▲            │
        │ implements   │ produces  │
        │              │           │
   data/repositories/impl ── uses ─┴─ data/mappers ── uses ─ data/dtos, data/datasources
        │
        ▼
   core/database, core/network, core/error, core/pokemon   (shared kernel)
```

- **DIP (CRITICAL invariant 3) — PASS.** `class PokemonRepositoryImpl implements PokemonRepository`
  (`pokemon_repository_impl.dart:28`). The contract is owned by `domain/repositories/`; the
  concretion lives in `data/repositories/`. Domain defines, data implements — the inversion is
  correct. Likewise both datasources expose `abstract interface class` contracts that their `*Impl`
  classes implement, so the repository depends on datasource *abstractions* (DIP all the way down),
  which is what lets it be faked in tests.
- **The one architectural back-edge is the intended enabler.** Mappers (T-12) and the impl (T-13)
  consume domain entities (T-14) and the repo interface (T-15). The plan (L20-24, L680) records this
  deliberately — domain enablers are written up-front so the data ring has contracts to satisfy. This
  is data→domain (allowed), not domain→data. No violation.
- **No circular dependency.** Domain never imports data; data imports domain; both import the shared
  `core/*` kernel; `core/*` imports neither feature layer (verified — `core/database` and
  `core/network` import only their own infra + dtos via the datasource boundary, never `domain` or the
  repository).

**Clean dependencies:** all PR3 edges.

---

## Translation Boundary (CRITICAL invariants 4 & 5)

### DTO ↔ entity ↔ row mapping — PASS (no DTO/row leak into entities)

- **`pokemon_mapper.dart` / `pokemon_detail_mapper.dart` / `evolution_mapper.dart`** take DTOs in,
  return pure entities out. No `PokemonDto`, `*Companion`, or `*Row` type appears on any entity field
  — confirmed by reading every entity (`pokemon.dart`, `pokemon_detail.dart`, etc.): fields are
  primitives, `PokemonTypeId`, and sibling entities only. The DTO and Drift-row types never cross the
  boundary into `domain/`.
- **`cache_mapper.dart`** is the entity↔row translator and is the *only* mapper that imports
  `package:drift` and `core/database` — correct, because companions/rows are Drift artifacts that
  belong strictly in the data layer. Entities are encoded to `payloadJson` via `jsonEncode(toJson())`
  and decoded via `fromJson(jsonDecode(...))`. The Drift types stop at this file.
- **Derived columns** (`primaryTypeId`/`secondaryTypeId`/`nameNormalized`/`height`/`weaknessMask`)
  are computed in the data layer at upsert time, never stored on the entity. The entity stays the
  source of truth in `payloadJson`; the columns are pure search/filter indices. This is the right
  split and keeps the cache layer entity-shape-driven, not schema-driven.

### Symmetric snake round-trip (CRITICAL invariant 5) — PASS

`build.yaml` sets `json_serializable: field_rename: snake` repo-globally. The same generated code
encodes (`toJson`) and decodes (`fromJson`) the cache `payloadJson`, so the round-trip is symmetric by
construction — a domain entity emitting `snake_case` JSON into the cache is not a wire-format leak, it
is internal cache serialization. The build.yaml comment documents this intent. Confirmed: no entity
carries a hand-written `@JsonKey` that would desync encode/decode; the hyphenated `official-artwork`
key is handled in the *DTO* layer (PR1), not in entities.

One latent coupling worth a comment (Suggestion, not a defect): `payloadJson` stores the entity's
*current* JSON shape. A future field rename/removal on `Pokemon`/`PokemonDetail` will make old cached
rows fail `fromJson`. The architecture already handles this gracefully — `pokemon_repository_impl.dart`
wraps every decode in `_tryParse`/`on FormatException` and treats a corrupt/unreadable payload as a
cache miss (online) or `CacheFailure` (offline). So schema drift degrades safely rather than crashing.
No action required; noted so the cache-versioning expectation is explicit.

---

## Persisted-contract coupling (`PokemonTypeId.index` ↔ cache) — assessed, acceptable

The cache stores `PokemonTypeId.index` in `primaryTypeId`/`secondaryTypeId` and as the weakness-mask
bit (`1 << index`, `summary_encoding.dart:53`). `pokemon_type_id.dart` carries a prominent ⚠ doc-comment
warning that the enum order is a **persisted contract** ("Do NOT reorder or remove values… Append new
types at the end only"). This is the correct way to manage an enum-index-as-persistence-key coupling:

- The risk (silent cache corruption on reorder) is real but **documented at the definition site**,
  which is where a future editor will see it.
- The two distinct numbering schemes are cleanly separated: `PokemonTypeId.index` (app's own persisted
  order) vs `pokeApiTypeIds` (the PokéAPI's `/type/{id}` numbering, `type_effectiveness.dart:8-27`).
  Mixing these would be a bug; keeping them as two explicit maps with a doc-comment explaining the
  difference is the right design. The repository fetches with `pokeApiTypeIds[type]!` and persists with
  `type.index` — correct on both sides.

**Suggestion:** the schema invariant is currently guarded only by prose. A cheap belt-and-suspenders
would be a single golden/unit test asserting the full `PokemonTypeId.values` → index ordering (and/or
that `weaknessMask` for a known type set equals a fixed literal), so an accidental reorder fails CI
loudly instead of silently corrupting caches. The doc-comment is good; a test would make it enforced.

---

## Documented deviation — `getEvolutionChain` resolves chainId via species (online-only)

`getEvolutionChain(id)` (`pokemon_repository_impl.dart:117-146`) fetches `/pokemon-species/{id}` to
obtain the chain id before it can read/serve the chain cache, so the method is **online-only on a cold
chain lookup** even though the chain row itself may be cached. The code documents this inline
("The chain id lives on the species (not cached separately), so resolving it needs the network").

**Architectural assessment: acceptable for this layer, with a noted asymmetry.**

- It is honest and isolated — the deviation is local to one method and clearly commented.
- It is consistent with the PokéAPI shape: the chain id is not on `/pokemon`, only on
  `/pokemon-species`, so resolving it offline is genuinely impossible without extra cached state.
- **Asymmetry worth noting (Suggestion):** `getPokemonDetail` composes evolution implicitly and caches
  the whole detail, while `getEvolutionChain` cannot serve a cached chain offline because it cannot
  resolve the chain id offline. A future refinement (out of PR3 scope) could persist the
  `pokemonId → chainId` mapping (e.g. on the summary or detail row) so a warmed chain is offline-
  serveable. Not a violation; the current behavior matches the documented contract and degrades to a
  clean `Err(NetworkFailure)` offline.

---

## Package / Module Structure

This is a single-package app (`pokedex`), so "package structure" maps to module/folder structure.

- **`domain/` module: Complete.** `entities/` + `repositories/`, pure Dart, single responsibility
  (the domain model + its contracts). No grab-bag.
- **`data/` module: Complete.** `dtos/`, `datasources/`, `services/`, `mappers/`, `repositories/` —
  each folder a single concern. `summary_encoding.dart` sits at `data/` root (shared by the PR2 DAO and
  the PR3 cache mapper) rather than inside `mappers/`; this is the correct home because it is consumed
  by both the datasource (PR2) and the mapper (PR3) and belongs to neither exclusively.
- **Test directories: Present.** `test/features/pokemon/data/mappers/` (6 files, one per mapper +
  generation_ranges) and `test/features/pokemon/data/repositories/` exist, matching the source tree.
- **No unnecessary modules.** Every folder earns its existence; no single-file orphan packages.
- **One-file-per-concept discipline holds:** five mappers split by concept (pokemon / detail /
  evolution / type-effectiveness / cache) rather than one mega-mapper — appropriate given each is a
  distinct, independently-tested translation with its own bug surface (weakness math being the
  highest-risk).

Structure is clean.

---

## Verdict

**Architecture is clean — ready to merge.** The dependency rule holds across all PR3 source; DIP is
correctly applied (impl implements the domain-owned interface); the DTO↔entity↔row translation boundary
leaks nothing into the domain; the cache round-trip is symmetric; DI is constructor-based with no global
state; and the persisted-enum coupling is documented at its definition site.

The one item to address is the **transitive Flutter import via `core/error/failure.dart`** — it is a
pre-existing foundation/PR1 line, not a PR3 change, but PR3 is where the "pure domain" contract starts
depending on it, so fixing it now (swap `package:flutter/foundation` → `package:meta` for `@immutable`)
is cheap insurance before the layer hardens. Treat it as Important, not blocking.

### Summary counts

- **Critical: 0**
- **Important: 1** — `core/error/failure.dart` imports `package:flutter/foundation`, transitively
  pulling Flutter into the nominally-pure domain layer (one-line fix: use `package:meta`).
- **Suggestions: 3**
  - Add a unit/golden test pinning `PokemonTypeId.values` ordering (the persisted-contract invariant
    is currently prose-only).
  - Document/accept the `payloadJson` cache-versioning expectation (drift handling already degrades
    safely — make the assumption explicit).
  - Consider persisting `pokemonId → chainId` later so `getEvolutionChain` can serve cached chains
    offline (resolves the documented online-only asymmetry; out of PR3 scope).
