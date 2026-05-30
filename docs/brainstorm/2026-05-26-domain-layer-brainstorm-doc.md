---
date: 2026-05-26
topic: domain-layer
---

# Layer 2 — Domain (T-16, T-17 + small T-15 revision)

## What We're Building

The **Domain ring** of the Clean Architecture onion for Pokédex — the layer that
turns the already-shipped repository contract (T-15) and entities (T-14) into the
intent vocabulary the Presentation ring will consume next epic. Concretely, the
remaining backlog scope: **T-16 Use Cases** and **T-17 DI + routing**. Use cases
are class-per-intent with `call(...)`, the Riverpod provider graph is wired
end-to-end with `@riverpod` codegen, and `go_router` is set up with the two MVP
routes (`/` and `/pokemon/:id`) behind minimal-Scaffold placeholders that the UI
epic (T-19+) will replace.

The epic also ships a **small, retroactive revision to T-15** along one axis of
the repo's read surface. The interface today exposes three reads, each backed by
a different mechanism and serving a different intent:

| Repo method                              | Backing              | Intent                                        |
| ---------------------------------------- | -------------------- | --------------------------------------------- |
| `getPokemonList(limit, offset)`          | network pagination   | first-load + scroll-infinito (UC-01, RF-03)   |
| `search(query)` + `filter(filter, sort)` | cache SQL (one-shot) | search/filter/sort (UC-02…UC-05, RN-06/07/08) |
| `watchCachedSummaries({sort, filter})`   | cache SQL (stream)   | reactive list updates on revalidation         |

The middle row is the one that's split for no good reason: the DAO already
exposes a combined query (`PokemonLocalDataSource.querySummaries(sort:, query:,
filter:)`), so the two methods collapse into a single
`findPokemon({query, filter, sort})` that routes the RN-08 intersection to the
SQLite WHERE clause. `getPokemonList` and `watchCachedSummaries` stay as they
are — each owns a distinct intent the unified `findPokemon` doesn't subsume.

## Why This Approach

The build is a **single vertical slice** (`feature/domain` →
`epic/domain-layer` → `develop`). At ~6 story points, the data-layer epic's 3-PR
cadence over-slices this work: there is no natural seam separating "pure-Dart
use cases" from "Flutter provider graph + router" that justifies double the CI
runs and review overhead. The PR shape mirrors the data-layer's **PR3
"convergence"** — the layer's own contracts plus the place where everything is
wired into the app — at a smaller size.

Two alternatives were weighed and rejected. A **two-PR split** (use cases then
DI/router) would have shipped use cases as dead code until PR2 lit the app up,
multiplying overhead for a 6-pt epic. A **three-PR slice** (use cases, providers,
router) over-fragments the same small piece of work; the data-layer was 36 pts
and warranted 3 PRs — this is not that.

On modeling, the line stays consistent with the project's
"**faithful external contract, lean internal structure**": **five use case
classes**, one per intent (`GetPokemonList`, `FindPokemon`,
`GetPokemonDetail`, `GetEvolutionChain`, `WatchPokemonList`), each a thin
`call(...)` delegation with no business logic added beyond what the repository
already enforces. The one shape opinion is RN-08: rather than mirror the
backlog's literal `SearchPokemon` + `FilterPokemon` pair (one of which would
intersect by hand), they collapse into one `FindPokemon` riding the DAO's
existing combined query.

## Key Decisions

- **Single PR `feature/domain` against `epic/domain-layer`** — bundles
  use cases, the repo-interface revision, the data-impl `findPokemon()` delegation,
  the full Riverpod provider graph, the `go_router` config, the `app.dart` /
  `main.dart` rewire to `ProviderScope` + `MaterialApp.router`, and the two
  placeholder screens. One CI run, one 5-agent review committed under
  `docs/reviews/` as `docs(review):` (matching the established per-slice flow).

- **Use case shape = class with `call(...)`** — exactly as T-16's acceptance
  criterion reads. Each takes the repository via constructor; pass-through
  only (no domain-only business logic exists today, so adding any would be
  speculative — Princípio 7 / YAGNI). **Five classes total:** `GetPokemonList`
  (network-paginated browse, returns `Future<Result<PokemonPage>>`),
  `GetPokemonDetail` (`Future<Result<PokemonDetail>>`), `GetEvolutionChain`
  (`Future<Result<EvolutionChain>>`), `FindPokemon`
  (`Future<Result<List<Pokemon>>>` over cached summaries), and `WatchPokemonList`
  (`Stream<List<Pokemon>>` — the only non-`Result` shape, wrapping
  `watchCachedSummaries` so the VM consumes use cases uniformly).

- **`FindPokemon` collapses the backlog's `SearchPokemon` + `FilterPokemon`** —
  one use case `call({String? query, PokemonFilter? filter, required SortCriteria sort})`
  delegating to the new unified repo method. The backlog wording was written
  against the older repo shape; this is a deliberate refinement noted as a
  small adjustment to T-16, not a deviation from intent. RN-08 (combination)
  is now expressed in one place instead of split + intersected.

- **T-15 retroactive revision — `findPokemon(...)` replaces `search()` + `filter()`** —
  the repository interface gains a single combined method routing to the DAO's
  existing combined query. The two old methods are removed (Camada 3 hasn't
  been built yet, so the surface cost is zero). `getPokemonList` and
  `watchCachedSummaries` stay as-is — each owns a distinct intent. The Tech
  Spec §8.3 snippet is updated in the same PR. The data-layer impl's existing
  tests for `search()` / `filter()` paths get re-shaped to one `findPokemon`
  matrix — contained refactor inside the PR.

- **`@riverpod` codegen for the whole provider graph, co-located with the wrapped
  class** — mirrors the Tech Spec §5 dependency diagram. `dioProvider`,
  `appDatabaseProvider`, `connectivityProvider`, `pokeApiServiceProvider`,
  `pokemonRemoteDataSourceProvider`, `pokemonLocalDataSourceProvider`,
  `pokemonRepositoryProvider`, and one provider per use case (5 total).
  Co-location matches the existing convention (`dioProvider` already lives next
  to `DioClient`). Resource-holding providers stay `keepAlive: true`
  (`Connectivity`, `AppDatabase`, `Dio`); stateless wrappers (datasources,
  repository, use cases) keep the default codegen lifecycle.

- **`go_router` config at `lib/app/router/app_router.dart`** — declared as a
  `@Riverpod(keepAlive: true)` `GoRouter` provider (`routerProvider`); the
  router holds navigation state across the app session, so auto-dispose would
  lose history on a rebuild. Two routes: `/` → `PokemonListScreen`
  placeholder, `/pokemon/:id` → `PokemonDetailScreen` placeholder with
  `int.parse(state.pathParameters['id']!)`. Deep links work on web out of the
  box; Vercel SPA rewrites already in scope at T-31 (later epic).

- **Placeholders = minimal `Scaffold` with AppBar showing route name/id** —
  ~10 lines per screen, no ViewModel, no provider reads beyond what the route
  already gives. Lets `flutter run` boot the app and lets a manual deep-link
  smoke (`/pokemon/25`) verify routing without doing UI work T-19+ throws away.
  Files live at `lib/features/pokemon/presentation/pages/` so the UI epic can
  drop in the real implementations without moving files.

- **App entry rewire** — `lib/main.dart` wraps `PokedexApp` in `ProviderScope`;
  `lib/app/app.dart` swaps `MaterialApp` → `MaterialApp.router(routerConfig: ...)`.
  `PokedexApp` becomes a `ConsumerWidget` so it can `ref.watch(routerProvider)`.
  Theme wiring from the foundation epic stays as-is.

- **`PokemonTypeId` stays at `lib/core/pokemon/`** — it's genuinely
  cross-cutting (used by data DTOs, domain entities, **and** `PokemonTypeTheme`
  in `app/theme/`). Moving it to `domain/entities/` would create an upward
  dependency from theme into a feature module, which the foundation epic
  explicitly avoided. The Tech Spec §8.2 lists it under "Entidades de domínio"
  but the placement is a cross-cutting carve-out; documented here so it isn't
  re-litigated in review.

- **No domain-side connectivity port** — `PokemonRepositoryImpl` keeps taking
  `Connectivity` directly. The `PokemonRepository` interface already hides the
  dependency from callers; introducing a domain wrapper would be a YAGNI
  abstraction with one implementation (Princípio 8 / [[feedback_abstraction-vs-fidelity]]).

- **Test coverage targets per Princípio 11 / VGV gate (≥ 80%)**:
  unit tests for each of the 5 use cases against a mocked `PokemonRepository`
  (the 4 `Future<Result<T>>` ones plus a stream test for `WatchPokemonList`);
  unit tests for the new `findPokemon()` path in `PokemonRepositoryImpl`
  (uses the in-memory DAO already set up by the data epic, exercises the
  query/filter/sort matrix); a small widget test confirming `MaterialApp.router`
  boots and that `/pokemon/25` reaches the detail placeholder with the parsed
  id (deep-link smoke). All repository mocks via `mocktail`, matching the
  data-layer epic's convention.

## PR Breakdown (seeds `/plan`)

### PR1 · `feature/domain` — T-15 revision + T-16 use cases + T-17 DI/router

- **Pubspec change first:** add `go_router` (`^16.x` candidate; verify analyzer
  compatibility on the existing pinned set — see [[project_analyzer9-toolchain]]).
  Run `flutter pub get`; confirm `dart run build_runner build
--delete-conflicting-outputs` still green before any source edits.
- **T-15 revision:** add `findPokemon({String? query, PokemonFilter? filter,
required SortCriteria sort})` to `PokemonRepository`; remove `search()` and
  `filter()` from the interface; update Tech Spec §8.3.
- **`PokemonRepositoryImpl.findPokemon(...)`** — delegates to
  `_local.querySummaries(sort:, query:, filter:)`. Old `search()` / `filter()`
  impls and tests removed; one parametric `findPokemon` matrix test takes their
  place.
- **5 use case classes** under `lib/features/pokemon/domain/usecases/`:
  `get_pokemon_list.dart`, `get_pokemon_detail.dart`, `get_evolution_chain.dart`,
  `find_pokemon.dart`, `watch_pokemon_list.dart`. Each: constructor takes the
  repo; `call(...)` returns `Future<Result<T>>` (or `Stream<List<Pokemon>>` for
  the watch case).
- **`@riverpod` providers** for the whole graph, co-located: `connectivity`,
  data-layer providers (added if not present alongside `Dio` / `AppDatabase`),
  `pokemonRepositoryProvider`, and 5 use case providers.
- **`lib/app/router/app_router.dart`** with `routerProvider`
  (`@Riverpod(keepAlive: true)`) and two routes.
- **`lib/features/pokemon/presentation/pages/`** — minimal `Scaffold`
  placeholders for `PokemonListScreen` and `PokemonDetailScreen(id)`.
- **`lib/main.dart`** wraps `PokedexApp` in `ProviderScope`; **`lib/app/app.dart`**
  becomes a `ConsumerWidget` using `MaterialApp.router`.
- **Test surface:** unit tests for the 5 use cases (mocktail), refreshed
  `PokemonRepositoryImpl.findPokemon()` matrix test, widget test for the
  deep-link smoke.
- **5-agent review** (`/review` then `docs(review):`) committed under
  `docs/reviews/2026-05-XX-domain-layer/`.

## Open Questions

- **`go_router` version pin.** A non-builder pin (`go_router: ^16.x` as of
  2026-05) likely sits cleanly outside the analyzer-9 fork — `go_router_builder`
  is the only codegen-bearing piece, and we don't need it at MVP. Confirm at
  plan time before adding to `pubspec.yaml`.
- **Smoke helper on the list placeholder.** Should the list placeholder render
  a tap target to `/pokemon/1` so manual smoke testing doesn't require typing
  a URL? Light call; decide at plan time.
