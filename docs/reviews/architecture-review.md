# Architecture Review — Data Layer PR1 (Remote / Network)

- **Scope:** PR1 of the data-layer epic (`feature/data-part1`), tasks T-06/07/08/11.
- **Reference:** `docs/plan/2026-05-25-feat-infrastructure-data-layer-plan.md`, `docs/project/02-tech-spec.md` (§2 dependency rule, §7 network, §8 contracts).
- **Architecture under review:** VGV layered / Clean Architecture (Presentation → Domain → Data), feature-first, with `core/` for cross-cutting infra.
- **Stack detected:** Flutter 3.x, Dio + Retrofit (network), Freezed + json_serializable (DTOs), Riverpod 3 (DI — not wired in PR1), `very_good_analysis` lints. Generated `*.g.dart`/`*.freezed.dart` excluded per scope.

## Layer Separation

The dependency rule (Tech Spec §2: "dependency arrows always point toward the domain; data implements domain interfaces; presentation never depends on DTOs or the HTTP client") holds without exception in PR1.

Imports were scanned across all 16 non-generated source files in `lib/core/network/**`, `lib/features/pokemon/data/**`, and `lib/core/error/**`.

- **`package:dio` containment — PASS.** Every `package:dio` import lives in the data/network layer and nowhere else:
  - `lib/core/network/dio_client.dart`
  - `lib/core/network/error_mapper.dart`
  - `lib/core/network/interceptors/{retry,rate_limit,logging}_interceptor.dart`
  - `lib/features/pokemon/data/datasources/pokemon_remote_data_source.dart`
  - `lib/features/pokemon/data/services/poke_api_service.dart`
- **`package:retrofit` containment — PASS.** Single import, in `lib/features/pokemon/data/services/poke_api_service.dart` (the `@RestApi` service). The remote data source wraps the service and exposes only DTO return types, so retrofit does not propagate outward.
- **`core/error` stays dio/drift/retrofit-free — PASS.** `lib/core/error/failure.dart` imports only `package:flutter/foundation.dart` (for `@immutable`); `lib/core/error/result.dart` imports only `failure.dart`. No transport dependency. This is the load-bearing invariant: the dio-free domain (PR3) will depend on `core/error`, so any dio import here would leak HTTP into the domain's transitive graph.
- **`ErrorMapper` placement — PASS (matches plan L99-107, L130-134).** `error_mapper.dart` lives in `core/network/`, **not** `core/error/`, precisely because it imports `package:dio`. Confirmed by directory listing: `core/error/` contains only `failure.dart` + `result.dart`; `error_mapper.dart` sits under `core/network/`. The placement decision in the plan is honored exactly.
- **No `flutter` import in network/data — PASS.** No `package:flutter/*` import appears in `core/network/**` or `features/pokemon/data/**`. The data/network code is framework-light (the only Flutter touch in the whole reviewed set is `@immutable` in `core/error/failure.dart`, which is acceptable and conventional for a shared error type).
- **No `dart:io` — PASS (web-safety).** `rate_limit_interceptor.dart` hand-rolls an IMF-fixdate parser specifically to avoid `dart:io`'s `HttpDate`, keeping the network layer web-compatible. The only `dart:io` token in the tree is inside an explanatory comment, not an import.

**Violations found: 0.**

Clean files: all 16 checked files clean.

## State Management Correctness

PR1 introduces **no** state management. Per the plan (L160-163), Riverpod provider wiring (`@Riverpod(keepAlive: true)` for the Dio/service singletons) is deliberately deferred to T-17 / Camada 2. The Dio client ships as a plain factory (`createPokeApiDio()`) and the service/data-source are plain classes, which keeps them unit-testable without a `ProviderContainer`. This is the correct under-engineering for the slice — no provider lifecycle to assess yet.

One adjacent observation, framed as state-adjacent correctness rather than a state-management unit:

- **Interceptor retry-attempt state — sound.** `RetryInterceptor` and `RateLimitInterceptor` both track attempt counts on `RequestOptions.extra` (per-request, keyed by distinct strings `retry_attempt` / `rate_limit_attempt`) rather than on instance fields. A single interceptor instance is therefore safe across concurrent in-flight requests — state is scoped to the request, not the interceptor. This matters because PR3's `getPokemonList` fans out N concurrent `/pokemon/{id}` calls through one shared Dio. Good design choice.

## Dependency Direction

The intended graph for PR1 (a leaf-to-trunk chain, no domain yet) is:

```
core/error (failure, result)        ← leaf, depended on by error_mapper
        ▲
core/network/interceptors  →  core/network/dio_client
        ▲                              (dio_client composes interceptors)
core/network/error_mapper (→ core/error)
        ▲
features/pokemon/data/dtos (→ freezed only; named_api_resource is the shared leaf)
        ▲
features/pokemon/data/services/poke_api_service (→ dtos, retrofit)
        ▲
features/pokemon/data/datasources/pokemon_remote_data_source (→ service, dtos, error_mapper)
```

Verified:

- **No reverse edges — PASS.** `core/` imports nothing from `features/` (grep returned none). The remote data source depends *upward* on `core/network/error_mapper` (cross-cutting infra), which is the correct direction.
- **No presentation/app leak — PASS.** Nothing in `data/` or `core/network/` imports `package:pokedex/app/**` or any presentation path.
- **No circular dependency — PASS.** DTOs depend only on `named_api_resource_dto.dart` (shared leaf) + `freezed_annotation`; the leaf depends on nothing internal. Service → DTOs; data source → service + DTOs + error_mapper. The graph is a DAG.
- **No `dio`/`retrofit`/`drift` under any `domain/` path — PASS (structurally).** No `domain/` directory exists yet (PR3 introduces it, per plan L429-461), and a tree-wide grep for `package:(dio|retrofit|drift)` returned zero matches in any path containing `domain`. The plan's PR3 dependency-rule guard (L599-600, L633-635) is pre-satisfied for the code that exists today.

**Direction violations: 0.**

Clean dependencies: `core/error`, `core/network` (+ interceptors), `features/pokemon/data/{dtos,services,datasources}`.

## DIP / Abstraction Boundaries

- **`PokemonRemoteDataSource` abstract interface — PASS (matches Tech Spec §8.4, plan T-11).** Declared as `abstract interface class PokemonRemoteDataSource` with a concrete `PokemonRemoteDataSourceImpl implements PokemonRemoteDataSource`. This is the DIP seam the PR3 repository will depend on, and it is what enables the repository's fakes-not-mocks test strategy (plan L584, L749-751). Keeping the interface even though there is only one impl today is justified by a named downstream consumer, not speculation.
- **`PokeApiService` abstract — PASS.** Retrofit's `@RestApi` abstract class with the generated `_PokeApiService` factory binding. The data source depends on the abstract `PokeApiService` type, so it is mockable (the test uses a mocktail mock of the service).
- **Failure-throw-at-datasource / catch-at-repository boundary — PASS, and sound.** `PokemonRemoteDataSourceImpl._guard` catches `DioException` and `FormatException` and **throws** the mapped `Failure` (via `mapError`). The repository (PR3, out of scope) is the documented catch site that converts the thrown `Failure` back into `Err`. The boundary mechanics are correct:
  - `Failure` is declared `sealed class Failure implements Exception` (`core/error/failure.dart:14`), so throwing it satisfies the `only_throw_errors` lint — exactly the additive change the plan called for (L189-191). The `==`/`hashCode` and the dio-free import set are preserved.
  - `mapError` is a pure top-level function (`Failure mapError(Object error)`), trivially testable, and is the single conversion boundary — no `DioException` can escape the data layer through this path.
  - **Note for PR3 (not a PR1 defect):** `_guard` catches only `DioException`/`FormatException`. A raw `Failure` (e.g. one thrown inside a future mapper) or an unexpected `Error` would propagate uncaught. For PR1 this is correct and complete — the service only ever surfaces dio/format errors. Flagging it solely so the PR3 repository's catch is written to also handle a raw `on Failure` (the plan already commits to this at L592, so it is a consistency reminder, not a gap).

## Package / Folder Structure

The repo is a single-package app (not a multi-package monorepo), so "package structure" maps to folder structure + the single `pubspec.yaml`/`analysis_options.yaml`/`build.yaml`. Assessed against the plan's target layout (L94-128).

- **Folder layout — matches the plan exactly.**
  - `lib/core/network/{dio_client.dart, error_mapper.dart, interceptors/{retry,rate_limit,logging}_interceptor.dart}` ✓
  - `lib/features/pokemon/data/dtos/` — 7 DTO files (named_api_resource, pokemon_list_response, pokemon, pokemon_species, evolution_chain, type, location_area_encounter) ✓
  - `lib/features/pokemon/data/services/poke_api_service.dart` ✓
  - `lib/features/pokemon/data/datasources/pokemon_remote_data_source.dart` ✓
  - No premature `database/`, `mappers/`, `repositories/`, or `domain/` scaffolding — YAGNI honored (those land in PR2/PR3).
- **`pubspec.yaml` — correct.** Runtime deps `dio: ^5.9.0`, `retrofit: ^4.9.2` in `dependencies`; codegen `retrofit_generator: 10.2.6` (exact) in `dev_dependencies`, matching the plan's load-bearing pin rationale (analyzer-9 stable fork). `mocktail` present for the service/data-source mocks. No `dio_smart_retry` (hand-rolled interceptors, per plan). No `drift`/`connectivity_plus` yet (correctly deferred to PR2/PR3).
- **`build.yaml` — correct and well-scoped.** First repo-global `build.yaml`; sets `json_serializable: field_rename: snake`. Hyphenated `official-artwork` correctly handled with an explicit `@JsonKey(name: 'official-artwork')` override in `pokemon_dto.dart`, as the plan requires (snake rename cannot convert hyphens).
- **`analysis_options.yaml` — correct.** Includes `very_good_analysis`; excludes generated outputs. (`*.drift.dart` is not yet added — that is a PR2 task per plan L376-378, not a PR1 gap.)
- **Test mirror structure — complete.** `test/` mirrors `lib/` 1:1 for every PR1 unit (network, interceptors, dtos, service, data source), with real-payload fixtures under `test/fixtures/` (Bulbasaur, Pikachu, Eevee, Ditto, species, evolution chains, 4 types, encounters). Matches the plan's fixture-driven test strategy.
- **Single clear responsibility per unit — PASS.** DTOs are transport-only (Freezed + fromJson); the one piece of logic on a DTO — `NamedApiResourceDto.idFromUrl` — is a faithful-contract helper (parsing the PokéAPI's trailing-id URL convention), which belongs with the DTO that owns the URL. Interceptors each own one concern (retry / rate-limit / logging). `error_mapper` is one pure function. No grab-bag files.

## DTO Faithfulness (modeling external reality — secondary)

Consistent with the project's "faithful external contract / lean internal" stance: DTOs model the API shape fully and tolerate missing fields (TE-10). `PokemonDto` makes `sprites` nullable and defaults the `types`/`stats`/`abilities` lists to empty; `NamedApiResourceDto.name` defaults to `''` to cover the url-only resource shape (e.g. a species' `evolution_chain`). `getEncounters` correctly returns a top-level `List<LocationAreaEncounterDto>` (the API returns a JSON array, not a wrapper). These are data-layer concerns, modeled correctly, and they do not bleed upward.

## Verdict

**Architecture is clean — ready to merge from an architectural standpoint.**

Every load-bearing invariant the plan and Tech Spec call out is satisfied:

- `package:dio` and `package:retrofit` are fully contained in the data/network layer.
- `core/error` is dio/drift/retrofit-free; `ErrorMapper` correctly lives in `core/network/`, not `core/error/`.
- No reverse or circular dependencies; `core/` never depends on `features/`.
- The `PokemonRemoteDataSource` DIP seam is in place and is what unblocks PR3's fake-based repository tests.
- The throw-`Failure`-at-datasource boundary is correct, enabled by `Failure implements Exception`.
- Zero `dio`/`retrofit`/`drift` imports under any `domain/` path.
- Folder structure matches the plan with appropriate YAGNI on PR2/PR3 scaffolding.

**Critical issues: 0. Important issues: 0. Suggestions: 1** (a forward-looking note for PR3, not a PR1 change): when PR3 writes the repository catch, ensure it catches a raw `on Failure` in addition to the data-source mapping, since `_guard` intentionally narrows to `DioException`/`FormatException` only. The plan already commits to this (L592), so it is a consistency reminder.
