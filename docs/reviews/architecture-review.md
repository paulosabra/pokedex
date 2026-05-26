# Architecture Review — Domain layer epic (T-15 revision + T-16 + T-17)

**Branch:** `feature/domain-layer`
**Scope:** Domain ring (5 use cases) + composition root (full Riverpod provider graph) + `go_router` wiring
**Standard:** VGV layered architecture / Clean Architecture onion + dependency rule (DIP)
**Plan:** `docs/plan/2026-05-26-feat-domain-layer-plan.md`
**Reviewed:** 2026-05-26

This PR closes the Domain ring: five `class.call(...)` use cases over `PokemonRepository`, the
T-15 retro-revision (`findPokemon` collapsing `search`/`filter`), and the first real composition
root (`ProviderScope` + `MaterialApp.router` + the `dio→service→datasources→repo→use cases→router`
provider graph). The architecture is sound; every Clean Architecture invariant the plan promised
holds in code. One deliberate, plan-documented trade-off is noted (not a finding) and one minor
observation is recorded.

---

## Layer Separation

**Violations found in PR source: 0** (modulo the plan-documented co-location trade-off below).

### Domain entity / repository purity — PASS

`grep -rE "package:(dio|drift|drift_flutter|retrofit|connectivity_plus|sqlite3_flutter_libs|flutter)/"`
across `lib/features/pokemon/domain/**` returns nothing for hand-written files
(`.g.dart`/`.freezed.dart` excluded). The `domain/entities/**` and `domain/repositories/**`
surfaces remain infrastructure-free, matching the PR3 baseline. The domain repository interface
(`lib/features/pokemon/domain/repositories/pokemon_repository.dart`) imports only
`core/error/result.dart`, sibling `domain/entities/*.dart`, and nothing else — clean.

### Use case CLASSES depend only on the interface — PASS (DIP held)

Every use case constructor in `lib/features/pokemon/domain/usecases/*.dart` types its
collaborator as the abstract `PokemonRepository`:

| File | Constructor field type |
| --- | --- |
| `get_pokemon_list.dart:17` | `final PokemonRepository _repository;` |
| `find_pokemon.dart:20` | `final PokemonRepository _repository;` |
| `get_pokemon_detail.dart:17` | `final PokemonRepository _repository;` |
| `get_evolution_chain.dart:16` | `final PokemonRepository _repository;` |
| `watch_pokemon_list.dart:21` | `final PokemonRepository _repository;` |

None reference `PokemonRepositoryImpl` from a typed position. DIP is preserved at the level
that matters for substitutability (mocking in tests, swapping the impl in DI).

### Use case PROVIDER FILES import the data layer — by design, not a violation

The five files import `package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart`
solely to reach `pokemonRepositoryProvider`:

- `get_pokemon_list.dart:2`
- `find_pokemon.dart:2`
- `get_pokemon_detail.dart:2`
- `get_evolution_chain.dart:2`
- `watch_pokemon_list.dart:1`

This is the deliberate trade-off the plan locks in (plan §"Architecture Notes" and "Datasource
provider co-location"): providers live next to the wrapped concrete type; the abstract type is
defined in the domain, so the provider can't sit there without inverting the wiring direction.
The mitigations the plan promised are all present:

1. Providers return the **abstract** type (`pokemonRepository(Ref) → PokemonRepository`,
   `pokemonRemoteDataSource(Ref) → PokemonRemoteDataSource`,
   `pokemonLocalDataSource(Ref) → PokemonLocalDataSource`). Verified at:
   - `pokemon_repository_impl.dart:316-321`
   - `pokemon_remote_data_source.dart:86-88`
   - `pokemon_dao.dart:173-175`
2. Static types on use case fields are the interface (above).
3. The data import is _only_ used to read the provider symbol — `git grep -n
   "PokemonRepositoryImpl\b" lib/features/pokemon/domain/` returns nothing.

The cost is one acknowledged seam: domain provider _files_ touch the data import surface. The
gain is convention consistency (every provider co-located with its wrapped type) and zero
indirection for codegen. Standing trade-off; flagged here so the next reviewer doesn't
re-litigate.

### Presentation purity (placeholders) — PASS

`lib/features/pokemon/presentation/pages/*.dart` imports `flutter/material.dart` and
`go_router/go_router.dart`. No data-layer or domain-internal imports. The UI epic will introduce
ViewModels reading use case providers; the foundation is clean.

### Core layer purity — PASS

`grep -rn "import 'package:pokedex/features" lib/core/` returns nothing. `core/` does not depend
on any feature.

### App layer purity — PASS for the composition root

`lib/app/app.dart` and `lib/main.dart` depend only on `app/router/app_router.dart`,
`app/theme/app_theme.dart`, and `flutter_riverpod`. `lib/app/router/app_router.dart` imports the
two presentation pages directly — appropriate for a router config that names its destinations.

---

## State Management Correctness (Riverpod 3 codegen)

All providers use `@Riverpod` / `@riverpod` codegen, return the right type, and follow the
plan's lifecycle policy.

| Provider | File:line | Lifecycle | Justification |
| --- | --- | --- | --- |
| `dioProvider` | `core/network/dio_client.dart:21` | `keepAlive: true` | Socket pool / interceptors |
| `appDatabaseProvider` | `core/database/app_database.dart:126` | `keepAlive: true` + `ref.onDispose(db.close)` | SQLite handle |
| `connectivityProvider` | `core/network/connectivity_provider.dart:9` | `keepAlive: true` | Platform stream subscribers |
| `routerProvider` | `app/router/app_router.dart:11` | `keepAlive: true` + `ref.onDispose(router.dispose)` | Nav history |
| `pokeApiServiceProvider` | `data/services/poke_api_service.dart:56` | Default (`@riverpod`) | Stateless Retrofit wrapper |
| `pokemonRemoteDataSourceProvider` | `data/datasources/pokemon_remote_data_source.dart:86` | Default | Stateless wrapper |
| `pokemonLocalDataSourceProvider` | `data/datasources/pokemon_dao.dart:173` | Default | Stateless wrapper |
| `pokemonRepositoryProvider` | `data/repositories/pokemon_repository_impl.dart:316` | Default | Stateless wrapper |
| `getPokemonListProvider` | `domain/usecases/get_pokemon_list.dart:27` | Default | Stateless wrapper |
| `findPokemonProvider` | `domain/usecases/find_pokemon.dart:32` | Default | Stateless wrapper |
| `getPokemonDetailProvider` | `domain/usecases/get_pokemon_detail.dart:25` | Default | Stateless wrapper |
| `getEvolutionChainProvider` | `domain/usecases/get_evolution_chain.dart:24` | Default | Stateless wrapper |
| `watchPokemonListProvider` | `domain/usecases/watch_pokemon_list.dart:31` | Default | Stateless wrapper |

Findings:

- **`keepAlive` correctness — PASS.** All four resource-holders that the plan flags as
  leak-risks (`dio`, `appDatabase`, `connectivity`, `router`) are marked `keepAlive: true`.
  Stateless wrappers all use the default lifecycle. The boot widget test and the dedicated
  `provider_graph_test` (per plan) are the runtime canary; static review confirms the
  annotations.
- **Disposal hooks — PASS.** Resources with explicit `close`/`dispose` semantics get
  `ref.onDispose`:
  - `appDatabaseProvider` → `ref.onDispose(db.close)` (`app_database.dart:129`).
  - `routerProvider` → `ref.onDispose(router.dispose)` (`app_router.dart:27`).
  Dio and Connectivity have no first-class close method exposed at this level; the `keepAlive`
  alone is sufficient.
- **`Ref` typing — PASS.** Hand-written providers use the unprefixed `Ref` parameter, and the
  generated `*.g.dart` files declare `create(Ref ref)` (verified for `dio_client.g.dart:47` and
  `app_router.g.dart:48`). This is the Riverpod 3 codegen pattern; no legacy `xRef` typedefs in
  source.
- **`part` directives and co-location — PASS.** Every annotated file has a matching
  `part '<basename>.g.dart';` and the generated file exists on disk. Providers are co-located
  with the wrapped type (or, in the case of `pokemonLocalDataSourceProvider`, with the wrapped
  _concrete_ class `PokemonDao`, since the impl lives in a different file from its interface
  — exactly as the plan documents).
- **Use case classes — PASS.** Each is a `class` with one `call(...)`, the repo injected via
  the constructor, no business logic beyond what the repo enforces. Asymmetric return type on
  `WatchPokemonList` (`Stream<List<Pokemon>>`, no `Result`) is intentional and matches the
  interface — verified at `watch_pokemon_list.dart:24-27`.

No `Manager` / `Handler` / `Helper` god-class naming. No mutable state on use case classes
(they hold a single `final` repo reference). Business logic location is correct: the use cases
are pass-throughs; cache/online policy lives in `PokemonRepositoryImpl`.

---

## Composition Root Correctness

### Single `ProviderScope` at the top — PASS

`grep -rn "ProviderScope" lib/` returns exactly one hit: `lib/main.dart:6`. No nested or
duplicate scopes, no `ProviderScope.overrideWith` in production code. The boot pattern is the
canonical `runApp(const ProviderScope(child: PokedexApp()));`.

### `MaterialApp.router` wiring — PASS

`lib/app/app.dart:14-18` uses `MaterialApp.router(routerConfig: ref.watch(routerProvider))`.
The widget is a `ConsumerWidget` so `ref.watch` is legal. The router is read through the
provider (single source of truth); no parallel `GoRouter` construction in `app.dart` or
`main.dart`. The theme wiring from the foundation epic is preserved verbatim.

### Router lifecycle — PASS

`routerProvider` is `@Riverpod(keepAlive: true)` and disposes the router on container teardown
via `ref.onDispose(router.dispose)` (`app_router.dart:27`). The combination matches the plan's
named risk: a missing `keepAlive` would reset nav history on every rebuild; a missing dispose
would leak the underlying listener. Both are guarded.

### Routes — PASS

Two routes, matching the plan exactly:

- `/` → `PokemonListScreen()` (`app_router.dart:15-18`)
- `/pokemon/:id` → `PokemonDetailScreen(id: int.parse(state.pathParameters['id']!))`
  (`app_router.dart:19-24`)

Deep-link parsing happens at the route boundary, not inside the screen — appropriate, since the
screen receives an `int` and is testable without a router. `go_router_builder` is intentionally
out of scope (no codegen pin risk).

---

## Dependency Direction

```
main.dart
  └── app/app.dart
       ├── app/theme/app_theme.dart (core-free)
       └── app/router/app_router.dart
            └── features/pokemon/presentation/pages/*.dart
                 └── (flutter/material + go_router only)

domain/usecases/<each>.dart (classes)  ──depends on──>  domain/repositories/PokemonRepository
domain/usecases/<each>.dart (providers) ──reads──>      data/repositories/pokemon_repository_impl.dart::pokemonRepositoryProvider

data/repositories/pokemon_repository_impl.dart
  └── data/datasources/{remote,dao}.dart  ──>  data/services/poke_api_service.dart  ──>  core/network/dio_client.dart
       └──────────────────────────────────>  core/database/app_database.dart
                       └─────────────────>  core/network/connectivity_provider.dart
                       └─────────────────>  domain/entities/* (mapping target only)
                       └─────────────────>  domain/repositories/pokemon_repository.dart (implements)

core/** depends on nothing inside features/
```

- **No cycles.** Verified by hand-tracing imports and by `grep -rn "import 'package:pokedex/features" lib/core/` returning empty.
- **Domain interface → Data impl direction is correct.** `PokemonRepositoryImpl implements PokemonRepository` (`pokemon_repository_impl.dart:35`), `PokemonRemoteDataSourceImpl implements PokemonRemoteDataSource` (`pokemon_remote_data_source.dart:40`), `PokemonDao ... implements PokemonLocalDataSource` (`pokemon_dao.dart:27`). The dependency inversion is in the right direction at the type level.
- **The one observed "upward" edge** is the plan-accepted import from `domain/usecases/*.dart`
  to `data/repositories/pokemon_repository_impl.dart` (for the provider symbol). Class-level
  types remain pointed at the interface; this is a wiring-file concession, not a structural
  dependency on the impl. Already discussed in Layer Separation above.

---

## Package Structure

This is a single-package app (not a melos monorepo), so the package-level checklist degrades
to module-level. Each layer keeps a single, clear responsibility:

- `core/` — shared infrastructure (error types, network plumbing, database, cross-cutting type
  identity). Imports nothing from `features/`.
- `features/pokemon/data/` — DTOs, mappers, services, datasources, repository impl, providers.
  Imports `core/` and `domain/` (the latter for interfaces it implements and entities it maps
  to).
- `features/pokemon/domain/` — entities, repository interface, use cases. Hand-written domain
  source files import only `core/error/*`, `core/pokemon/pokemon_type_id.dart`, sibling
  domain files, and (in the use case provider lines only) the data repository file for the
  provider symbol.
- `features/pokemon/presentation/` — placeholder pages only. UI epic will add ViewModels and
  state classes.
- `app/` — composition root: theme, router, root widget, entry point.

`pubspec.yaml` adds exactly one new dep (`go_router: ^17.2.3`); no codegen, no pin disruption
(plan §"Pubspec validation"). The pinned analyzer-9 codegen set (`freezed: 3.2.5`,
`riverpod_generator: 4.0.3`, `drift: 2.31.0`, `drift_dev: 2.31.0`, `retrofit_generator: 10.2.6`)
is preserved verbatim, matching the project's `analyzer9-toolchain` memory.

> **Note:** the plan targeted `go_router: ^16.x`. The committed value is `^17.2.3`. The plan's
> §"Resolved Open Questions" §1 explicitly accepts pin drift at execution time provided the
> pinned codegen set isn't disturbed (and provided the resolved minor is recorded in the PR
> description). Both conditions can be met here. Worth flagging in the PR body if not already
> there.

---

## Observations (not violations)

1. **Use case provider file → data impl import (plan-accepted trade-off).** Five files, five
   imports — already documented above. The current convention is locally consistent, plan-
   documented, and not blocking. The cleanest alternative would be a `domain/usecases/_di.dart`
   barrel that imports the data file once and re-exposes `pokemonRepositoryProvider` to the
   use cases, but that adds indirection for no behavioural gain. Standing as-is is the right
   call; record this so a future reviewer sees the reasoning rather than re-flagging it.
2. **`go_router` version drift from `^16.x` to `^17.2.3`.** Codegen pins held (see Package
   Structure note); functionally fine. Mention the resolved version in the PR body per the
   plan's §"Resolved Open Questions" #1.

---

## Verdict

**Architecture is clean. Ready to merge.**

- Layer separation: 0 violations. The five `domain/usecases → data/pokemon_repository_impl`
  imports are the plan-accepted, plan-documented co-location trade-off; class-level types
  remain on the abstract interface (DIP held).
- State management: All providers correctly typed, correctly co-located, correct lifecycle
  policy (`keepAlive: true` on the four resource-holders, default on stateless wrappers).
  `ref.onDispose` present where it matters (db, router).
- Dependency direction: One-way, no cycles. Core depends on nothing in features. Data
  implements domain. Presentation depends on go_router only (no upward leak).
- Composition root: One `ProviderScope` at `main.dart:6`. `MaterialApp.router` reads
  `routerProvider` (single source of truth). Two routes wired per the plan.
- Package structure: Modules have single responsibilities; pubspec adds one dep, codegen pins
  untouched.

No critical or important issues. Two minor observations recorded above for PR-body / future-
reviewer context.
