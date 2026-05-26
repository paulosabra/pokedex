---
date: 2026-05-26
topic: presentation-layer
---

# Layer 3 — Presentation / UI (MVVM) — T-18 … T-28

## What We're Building

The **Presentation ring** of the Clean Architecture onion for Pokédex — the only
layer that touches `BuildContext`, Flutter SDK widgets, and `MaterialApp.router`.
It consumes the five use case providers already shipped by the domain epic
(`getPokemonListProvider`, `findPokemonProvider`, `watchPokemonListProvider`,
`getPokemonDetailProvider`, `getEvolutionChainProvider`) and the theme/tokens
shipped by foundation (`PokemonTypeTheme`, `app_colors`, `app_typography`,
`app_theme`), and turns them into the two MVP screens (`PokemonListScreen`,
`PokemonDetailScreen`) plus the shared Design System kit and the discovery
sheets (Filters, Sort, Generations).

Concretely, the full backlog scope: **T-18 (Design System), T-19 (Home list +
pagination), T-20 (search), T-21 (filters sheet), T-22 (sort sheet),
T-23 (generations sheet), T-24 (Detail header + About tab), T-25 (Stats tab),
T-26 (Evolution tab), T-27 (global error/empty states), T-28 (web/desktop
responsiveness)** — 11 tasks, **42 story points**, the biggest epic in the
backlog. MVVM is **literal Tech Spec §5.2**: each screen owns one Freezed
state class, one `@riverpod` `AsyncNotifier` ViewModel, and a `ConsumerWidget`
View that only renders state and dispatches intents.

## Why This Approach

The build is sliced into **four PRs** against `epic/presentation-layer`. The
data-layer epic (36 pt) shipped in 3 PRs and the seam was natural (remote /
local / repository convergence); this epic is 42 pt across two screens with a
shared design system, so the natural seams are **layer foundation → first
screen → second screen → convergence**. PR1 ships the Design System kit alone
because every screen depends on it (DAG: T-18 → T-19, T-24) and reviewer load
on a pure-component PR is dramatically lower than a screen PR mixing
components, ViewModel, and Figma fidelity. PR2 and PR3 each ship one screen
end-to-end — different ViewModel, different data flow, different reviewer
mental model. PR4 converges with global error/empty states (T-27, MUST) and
web/desktop responsiveness (T-28, SHOULD).

Two alternatives were weighed and rejected. A **3-PR mirror of the data-layer
cadence** (DS+Home-shell+Detail-About → Home-discovery+Detail-tabs → polish)
keeps the cadence but mixes Home and Detail work in PR2, which forces
reviewers to context-switch between two screens in a single review. A **2-PR
split** (Home-end-to-end → Detail-end-to-end+polish) cuts CI overhead but each
PR lands at ~20 pt — past the threshold where thorough review degrades. A
**5-PR split** (DS → list shell → discovery → detail → polish) was over-sliced
for a layer with only two screens, ships a barely-usable list in PR2, and
multiplies CI/review overhead for marginal clarity gain.

On state shape, the design follows the project's "**ratify the spec unless
there's a quality reason**" rule (per [[feedback_review-vs-plan]]). Tech Spec
§5.2 sketches a single `PokemonListViewModel` holding the full Home state —
items, pagination, query, filter, sort, generation, refresh error — in one
Freezed `PokemonListState`. That's ratified verbatim because RN-08 (combine
query + filter + sort) intersects trivially in one place via the existing
`findPokemon` use case, AsyncValue maps cleanly to the PRD state machine
(§5.1), and the discovery-mode split (below) puts all the routing logic in
one cohesive controller instead of scattered across coordinating notifiers.

The one substantive opinion beyond the spec is the **browse vs discovery
mode switch + watch-stream bridge**. When the user has no query/filter/non-
default-sort/generation active, the VM is in **browse mode**: paginated
network fetches via `getPokemonList`, AND a `watchPokemonList` subscription
bridged into state so cache revalidations (TE-02 "dados salvos" flag,
RN-02 stale-while-revalidate) surface in the UI without a manual refresh.
When any of those is active, the VM flips to **discovery mode**: single-shot
`findPokemon(query, filter, sort)` against the cache, pagination disabled,
RF-11 instant response. Clearing all filters returns to browse and
re-subscribes. This is more moving parts than ignoring the watch stream, but
it's the only way to make the stream use case (shipped at domain layer for
exactly this purpose) actually do work — and it's what lets TE-02's
"banner of dados salvos quando offline" reflect real cache state.

## Key Decisions

- **4 PRs against `epic/presentation-layer`** — PR1 = T-18 design system kit
  (~5pt); PR2 = T-19/T-20/T-21/T-22/T-23 Home + discovery (~18pt); PR3 =
  T-24/T-25/T-26 Detail tabs (~11pt); PR4 = T-27 error/empty +
  T-28 responsive (~8pt). Each PR lands its own 5-agent review committed
  under `docs/reviews/2026-05-XX-<slice>/` as `docs(review):` (per
  [[feedback_review-reports-committed]]). Branch flow per
  [[project_git-flow]]: each PR on `feature/<slice>` → `epic/presentation-layer`
  → `develop` → `main`.

- **MVVM = literal Tech Spec §5.2** — Each screen owns: a `ConsumerWidget`
  View (renders state, dispatches intents only — no business logic), a
  Freezed `…State` class (immutable, all UI state in one place), and a
  `@riverpod` `AsyncNotifier` `…ViewModel` (state holder + intent methods).
  ViewModels take use cases through `ref.read`, never repositories or DAOs.
  - **Why:** maps 1:1 to PRD state machine via `AsyncValue<T>` (Tech Spec
    §5.1: Loading=`AsyncLoading`, Loaded=`AsyncData(state)`,
    Empty=`AsyncData(state.copyWith(items: []))`, Error=`AsyncError(failure)`,
    Refreshing=`AsyncData + state.isRefreshing`,
    StaleWithError=`AsyncData(cache) + state.refreshError`).
  - **How to apply:** when use cases return `Result<T>`, the VM translates
    at the boundary — `Ok(value)` becomes `state` mutation,
    `Err(failure)` becomes `throw failure` which Riverpod turns into
    `AsyncError`. This translation is mechanical and lives in one place
    per VM.

- **`PokemonListViewModel` is a single `@riverpod AsyncNotifier`** owning
  the full Home state — `items`, `offset`, `hasMore`, `isLoadingMore`,
  `isRefreshing`, `query`, `filter`, `sort`, `generationId`, `refreshError`,
  plus a derived `isDiscovery` flag (`query.isNotEmpty || filter != null ||
sort != SortCriteria.numberAsc || generationId != null`). Intents:
  `loadMore()`, `search(q)` (300ms debounce per RF-10), `applyFilter(f)`,
  `changeSort(s)`, `selectGeneration(id)`, `clearGeneration()`, `refresh()`.
  - **Why:** RN-08 says query+filter+sort combine; with one VM and one
    `findPokemon` use case, the combination is a single function call,
    not a coordinated state merge. The Tech Spec example is followed
    verbatim because it works.
  - **How to apply:** debounce lives inside the VM (a private `Timer?
_debounce` field cancelled on each `search()` call); the VM is
    constructed via `@riverpod` codegen (not `@Riverpod(keepAlive: true)`)
    so navigating away and back rebuilds — appropriate for the Home
    screen since fresh state on entry is desirable.

- **Retroactive domain revision — `generationId` joins `PokemonFilter`** —
  Verified in code: `PokemonFilter` carries `{types, weaknesses, height}`
  only; `findPokemon({required sort, query, filter})` and
  `watchPokemonList({required sort, filter})` have no generation parameter.
  PR1's groundwork step extends `PokemonFilter` with `int? generationId`,
  refreshes Freezed codegen, and verifies the data-layer DAO's
  `querySummaries(...)` already routes through the `generation_id` column
  (T-09 schema confirms it exists; add a WHERE branch if the DAO doesn't
  yet wire it). Tech Spec §8 entity snippet gets updated in the same PR,
  mirroring the T-15 revision the domain epic made for `findPokemon`.
  - **Why:** generation IS a filter axis conceptually (T-23 "Sheet de
    gerações" intersects with type + weakness + height per RN-08).
    Adding it to `PokemonFilter` keeps the contract coherent — one
    filter object, one wire shape — instead of fanning a new parameter
    out to three use cases. Client-side post-filtering (the only
    contract-free alternative) breaks pagination for browse mode
    because each network page might filter to empty.
  - **How to apply:** Home VM keeps `generationId: int?` as a top-level
    state field per Tech Spec §5.2 (separate sheet, separate intent,
    distinct UI affordance). When calling use cases, the VM composes:
    `findPokemon(sort: state.sort, query: state.query.isEmpty ? null :
state.query, filter: (state.filter ?? const PokemonFilter())
.copyWith(generationId: state.generationId))` — the state field is
    the UI source of truth, the filter copy is the wire format. Same
    pattern for the watch-stream subscription's `filter` parameter.

- **Browse vs Discovery mode + `watchPokemonList` bridge** — When
  `isDiscovery == false`: VM's `build()` fires `getPokemonList(limit:
pageSize, offset: 0)` for the first page AND subscribes to
  `watchPokemonList(sort: sort, filter: null)`. The stream re-emits on
  every cache change; each emission **replaces `state.items` AND sets
  `state.offset = items.length`** so the next `loadMore()` paginates
  network from past the stream's window. `state.hasMore` only flips to
  `false` when a `getPokemonList` response signals exhaustion — the
  stream never sets it (the stream sees cache, not the network end).
  `loadMore()` calls `getPokemonList(limit: pageSize, offset:
state.offset)`. When `isDiscovery == true`: VM cancels the stream
  subscription, fires a single `findPokemon(query, filter, sort)`, sets
  `hasMore = false`, disables the scroll-end detector. Switching back
  to browse re-subscribes and the stream's next emission resyncs items
  - offset.
  * **Why:** RF-11 says discovery responds instantly from cache (RN-08
    confirms search/filter/sort happen on the cache); RN-02 says
    revalidation happens in background and surfaces to the UI (TE-02
    "dados salvos" banner). The watch stream is the _only_ way the UI
    sees a revalidation without a manual refresh. The offset-bump rule
    resolves the otherwise-implicit conflict between "stream shows full
    cache slice (could be 200+ items)" and "pagination window is
    24-at-a-time" — the visible list is allowed to grow on revalidation
    and pagination just resumes from there.
  * **How to apply:** the stream subscription is held in a private
    `StreamSubscription?` and torn down in `ref.onDispose` and on every
    flip to discovery mode. `state.items` is the single render source;
    the stream feeds it; `loadMore()` reads from `state.offset` (which
    the stream may have advanced) and appends.

- **`PokemonDetailViewModel` is a `@riverpod` family AsyncNotifier keyed by
  `int id`, loading only `getPokemonDetail(id)`. Evolution loads lazily**
  via a separate `pokemonEvolutionChainProvider.family(id)` watched
  directly by the Evolution tab.
  - **Why:** About + Stats both render fields from the same `PokemonDetail`
    entity, so they share one fetch. Evolution is a separate use case
    (`getEvolutionChain` hits a different endpoint and many pokémon have
    no chain — RF-43/RN-13), so loading it eagerly is wasted work for
    those cases.
  - **How to apply:** header (artwork, #NNN, name, badges, type color)
    reads from the detail VM. Tab bodies: About + Stats read detail VM
    state; Evolution tab uses `ref.watch(pokemonEvolutionChainProvider(id))`
    so it only fetches when the user opens it. Both providers are
    `family`-keyed by `id` so navigating between pokémon doesn't leak
    state.

- **DS components take primitive params, not domain entities** —
  `PokemonCard`, `TypeBadge`, `StatBar`, `SectionHeader`, `SearchField`,
  `AppBottomSheet` all live under `lib/core/ui/components/` and **must
  not import** from `package:pokedex/features/pokemon/domain/...`.
  Components take `id`, `name`, `primaryType`, `secondaryType`,
  `spriteUrl`, etc. as primitive parameters (with `PokemonTypeId`
  allowed because it already lives at `lib/core/pokemon/` for exactly
  this cross-cutting reason — per the domain-layer brainstorm decision).
  - **Why:** the foundation epic explicitly avoided upward dependencies
    (core → features) when carving `PokemonTypeId` out to `core/pokemon/`
    so theme could reference it. The DS kit honors the same rule: an
    `import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart'`
    in `lib/core/ui/components/pokemon_card.dart` would break this
    layering and CI's import rules.
  - **How to apply:** Home/Detail feature widgets are thin adapters that
    pull fields off the entity and pass primitives to DS components
    (e.g., `features/pokemon/presentation/widgets/pokemon_card.dart`
    receives a `Pokemon` and renders `core.PokemonCard(id: p.id,
name: p.name, primaryType: p.primaryType, ...)`). Adapter widgets
    add the entity-aware behavior (onTap → `context.go('/pokemon/${p.id}')`)
    that the pure DS components don't carry.

- **Discovery sheets are stateless presentational widgets** — `FiltersSheet`,
  `SortSheet`, `GenerationsSheet` take their current selection and an
  `onChanged` callback as parameters; the Home View opens them via
  `showModalBottomSheet` and routes the result back into the
  ViewModel intent (`applyFilter`, `changeSort`, `selectGeneration`).
  Sheets don't own state themselves.
  - **Why:** sheets are transient UI; making them stateful Riverpod
    notifiers would put ephemeral selection state in the global graph
    and complicate disposal. The Home VM is the single source of truth
    for active discovery state.
  - **How to apply:** filter count badge ("3 active filters") is
    computed inside the sheet from its props; pressing "Apply"
    closes the sheet and the result is delivered via the
    `Navigator.pop(value)` return.

- **Figma MCP — authenticate first, fetch per-screen at plan time** —
  Run `/figma:figma-use` + authenticate before invoking `/plan`. Each
  per-screen PR fetches its specific frame via `get_design_context`
  (node-id from Tech Spec §11.1: `268:0` Home, `268:1037` Home-scrolled,
  `268:63` Filters, `268:176` Sort, `268:248` Generations, `268:320`
  Detail-About, `268:378` Detail-Stats, `268:513` Detail-Evolution) and
  validates fidelity with `get_screenshot` for golden-test baselines.
  Tokens come from `get_variable_defs` and confirm what's already in
  `app/theme/`.
  - **Why:** every UI task in the backlog (T-18, T-19, T-21, T-22, T-24,
    T-25, T-26) explicitly cites Figma MCP fidelity validation as an
    acceptance criterion. Backlog v1.1 made this the design contract.
  - **How to apply:** per-PR routine = (1) `get_design_context(node-id)`
    to see the rendered code suggestion, (2) `get_variable_defs(node-id)`
    to confirm tokens, (3) implement against `PokemonTypeTheme`, (4)
    `get_screenshot(node-id)` as the golden baseline for widget tests.

- **Responsiveness (T-28) lives in PR4, behind a `ResponsiveLayout`
  selector widget** — Breakpoints per Tech Spec §9.1:
  `compact < 600 < medium < 1024 < expanded`. `ResponsiveLayout` is a
  single widget under `lib/app/layout/` that chooses sheet vs dialog and
  list-grid column count by breakpoint. Existing screens wrap their
  bottom-sheet calls and their grid through `ResponsiveLayout` — no
  per-screen breakpoint logic.
  - **Why:** PR2 and PR3 land mobile-fidelity screens first (the design
    contract is mobile-first). Pushing all multi-platform logic into
    PR4 keeps PR2/PR3 focused and lets PR4 ship the breakpoint logic
    as one coherent piece.
  - **How to apply:** keep PR2/PR3 screens using `showModalBottomSheet`
    directly; PR4 introduces `ResponsiveLayout.showSheetOrDialog(...)`
    helper and rewires the call sites — minimal diff per screen.

- **Global error/empty widgets (T-27) live under `lib/core/ui/`** —
  `OfflineErrorWidget`, `EmptySearchResultsWidget`,
  `StaleCacheBanner` etc., each with an `onRetry` callback and TE-coded
  messaging (TE-01 "Você está offline", TE-02 "Dados salvos…",
  TE-04 "Nenhum Pokémon encontrado para …", TE-05 "Nenhum resultado
  para filtros"). Screens render them based on `AsyncValue` state +
  state.refreshError fields.
  - **Why:** the PRD §8 explicitly forbids blank error screens; reusable
    widgets ensure consistency and let golden tests cover them once.
  - **How to apply:** widgets are pure presentational (no Riverpod
    deps); they take all data via constructor params and surface
    callbacks. Screens decide which to render based on AsyncValue
    pattern matching + isDiscovery flag.

- **Test coverage targets per Princípio 11 / VGV ≥ 80% gate** — DS
  components: Flutter golden tests per component (T-18 AC). ViewModels:
  unit tests with mocked use case providers (use `ProviderContainer` +
  overrides; mock use cases with `mocktail`, matching data + domain
  epic conventions). Screens: widget tests covering happy path + each
  error/empty state (no `AsyncLoading` golden — too flaky). Deep-link
  smoke from domain epic stays green.
  - **Why:** the data-layer epic established mocktail + in-memory
    overrides as the test idiom; presentation reuses the same harness
    plus Flutter's golden tests for visual surfaces.
  - **How to apply:** Figma `get_screenshot` is the **visual reference
    during dev** — the designer-truth used to confirm the Flutter
    render matches intent; it is NOT a Flutter-comparable bitmap
    (different rasterizer, different fonts). Flutter goldens are
    **self-baselined**: first run generates `test/.../goldens/*.png`
    via `--update-goldens`, CI compares subsequent runs against those
    committed PNGs. The Figma screenshot lives outside the test
    harness (referenced in PR description / commit notes). Widget
    tests pump the screen with `ProviderScope(overrides:
[usecaseProvider.overrideWith(...)])`.

## PR Breakdown (seeds `/plan`)

### PR1 · `feature/presentation-part1` — T-18 Design System kit + domain revision (~6 pt)

- **Pubspec change:** likely none — `cached_network_image` (for artwork)
  may need adding; `flutter_svg` if the type icons are SVG (check
  Figma); golden tests use Flutter SDK built-in `matchesGoldenFile`,
  no extra deps. Verify before any source edits.
- **Domain revision (groundwork before DS components):** extend
  `PokemonFilter` with `int? generationId`; rerun `dart run build_runner
build --delete-conflicting-outputs` to refresh the Freezed file;
  verify `PokemonLocalDataSource.querySummaries(...)` already filters
  by `generation_id` (T-09 schema confirms the column exists) and add
  a WHERE branch if it doesn't yet; update Tech Spec §8 entity snippet;
  add/refresh a `findPokemon` test covering the generationId axis.
  This is a small retroactive revision in the spirit of the domain
  epic's T-15 revision — same PR carries the domain change AND the DS
  components so neither ships in isolation.
- **Figma MCP:** authenticate, then pull design context for the Badge,
  Text Field, and stat-bar instances from frames `268:0`, `268:63`,
  `268:378`. `get_variable_defs` confirms tokens already in
  `app/theme/` match.
- **Components under `lib/core/ui/components/`:**
  `pokemon_card.dart`, `type_badge.dart`, `stat_bar.dart`,
  `section_header.dart`, `search_field.dart`, `app_bottom_sheet.dart`.
  All parameterised with **primitive types** (`int id`, `String name`,
  `PokemonTypeId primaryType`, etc.) — no imports from
  `features/pokemon/domain/`. No Riverpod, no data dependencies. Each
  consumes `PokemonTypeTheme` for type-driven colors (RN-04).
- **Test surface:** one Flutter golden per component (6 goldens),
  self-baselined under `test/core/ui/components/goldens/`. Figma
  `get_screenshot` of the corresponding node is the visual reference
  during dev and is linked in the PR description so reviewers can
  eyeball fidelity; it is not compared bitmap-equal. Widget tests
  for parameter variations (TypeBadge with each of the 18 types,
  StatBar at 0/50/100/max values).
- **5-agent review:** `/review` → commit `docs(review):` under
  `docs/reviews/2026-05-XX-presentation-part1/`.
- **CI gates:** `dart format`, `dart analyze` (per
  [[project_analyzer9-toolchain]]), `flutter test` (use the very-good-cli
  MCP wrapper per [[feedback_vgv-cli-hooks]]), `dart run build_runner
build --delete-conflicting-outputs` clean.

### PR2 · `feature/presentation-part2` — T-19/T-20/T-21/T-22/T-23 (~18 pt)

- **Pubspec change:** likely none — confirm `cached_network_image`
  landed in PR1. No new deps expected.
- **Figma MCP:** per-PR fetch of frames `268:0` (Home), `268:1037`
  (Home full-scroll), `268:63` (Filters), `268:176` (Sort),
  `268:248` (Generations) — context + variable_defs + screenshot per
  frame.
- **Files added:**
  - `lib/features/pokemon/presentation/state/pokemon_list_state.dart`
    (Freezed)
  - `lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`
    (@riverpod AsyncNotifier — single VM, browse/discovery split,
    watch-stream bridge)
  - `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart`
    (replaces placeholder; ConsumerWidget)
  - `lib/features/pokemon/presentation/widgets/pokemon_card.dart`
    (consumes DS PokemonCard, adds onTap → context.go)
  - `lib/features/pokemon/presentation/widgets/sheets/filters_sheet.dart`
  - `lib/features/pokemon/presentation/widgets/sheets/sort_sheet.dart`
  - `lib/features/pokemon/presentation/widgets/sheets/generations_sheet.dart`
- **Behavior covered:** UC-01 paginated browse, UC-02 search (300ms
  debounce), UC-03 filter combine, UC-04 sort change, UC-05 generation
  filter, UC-08 pull-to-refresh, RN-08 RN-09 RN-14 enforcement.
- **Test surface:** PokemonListViewModel unit tests via
  `ProviderContainer` with mocked use case providers (browse-mode
  pagination, discovery-mode `findPokemon` switch, debounce behavior,
  stream bridge, mode flip on filter clear, error mapping). Widget
  test for screen happy path (renders cards from VM state). Flutter
  golden per sheet under `test/features/pokemon/presentation/goldens/`
  (self-baselined); Figma node screenshot linked in PR description.
- **5-agent review:** `docs(review):` under
  `docs/reviews/2026-05-XX-presentation-part2/`.

### PR3 · `feature/presentation-part3` — T-24/T-25/T-26 (~11 pt)

- **Pubspec change:** likely none — `flutter` ships `TabBar`/`TabBarView`.
- **Figma MCP:** fetch frames `268:320` (Detail-About), `268:378`
  (Detail-Stats), `268:513` (Detail-Evolution) — context + variables
  - screenshot.
- **Files added:**
  - `lib/features/pokemon/presentation/state/pokemon_detail_state.dart`
    (Freezed — wraps `PokemonDetail`)
  - `lib/features/pokemon/presentation/view_models/pokemon_detail_view_model.dart`
    (@riverpod family AsyncNotifier keyed by `int id`)
  - `lib/features/pokemon/presentation/view_models/pokemon_evolution_view_model.dart`
    (separate provider for lazy evolution loading; family by id)
  - `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart`
    (replaces placeholder; ConsumerWidget with `DefaultTabController`)
  - `lib/features/pokemon/presentation/widgets/detail/detail_header.dart`
  - `lib/features/pokemon/presentation/widgets/detail/about_tab.dart`
  - `lib/features/pokemon/presentation/widgets/detail/stats_tab.dart`
  - `lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart`
- **Behavior covered:** UC-06 detail load, UC-07 evolution stage
  navigation (tapping a stage triggers `context.go('/pokemon/$id')`),
  RF-29 type-colored header, RF-31..34 about sections, RF-35..39 stats
  - Type Defenses, RF-40..43 evolution chain, TE-10 missing fields
    show "—", RF-43/RN-13 no-evolution case.
- **Test surface:** PokemonDetailViewModel unit tests
  (`getPokemonDetail` success/failure → AsyncValue states; family
  keying isolation). Separate evolution provider test (lazy load,
  no-evolution case). Widget tests per tab (about/stats/evolution),
  with mocked detail VM state for happy + missing-fields. Flutter
  goldens per tab under `test/features/pokemon/presentation/goldens/`
  (self-baselined); Figma node screenshots linked in PR description.
  Existing deep-link smoke from domain epic stays green.
- **5-agent review:** `docs(review):` under
  `docs/reviews/2026-05-XX-presentation-part3/`.

### PR4 · `feature/presentation-part4` — T-27 errors + T-28 responsive (~10–11 pt)

> Backlog sums T-27 (3pt) + T-28 (5pt) = 8pt, but PR4 also rewires PR2's
> bottom-sheet call sites through `ResponsiveLayout` and reshapes the
> router for master-detail on expanded breakpoints. The realistic sizing
> is 10–11 pt; flagged here so the PR doesn't slip without explanation.

- **Pubspec change:** none expected.
- **Figma MCP:** no dedicated frame for error/empty states per T-27;
  responsive (T-28) has no separate Figma either — both follow the
  established DS visual language.
- **Files added under `lib/core/ui/`:**
  - `lib/core/ui/states/offline_error_widget.dart` (TE-01)
  - `lib/core/ui/states/stale_cache_banner.dart` (TE-02)
  - `lib/core/ui/states/empty_search_widget.dart` (TE-04)
  - `lib/core/ui/states/empty_filter_widget.dart` (TE-05)
  - `lib/core/ui/states/generic_error_widget.dart`
    (TE-03/06/07/09 fallback with Retry)
- **Files added under `lib/app/layout/`:**
  - `lib/app/layout/breakpoints.dart` (compact/medium/expanded
    constants per §9.1)
  - `lib/app/layout/responsive_layout.dart` (helper widget +
    `showSheetOrDialog`)
  - `lib/app/layout/master_detail_scaffold.dart` (detail-in-panel
    on expanded breakpoint per §9.1)
- **Modifications:**
  - PokemonListScreen rewires bottom-sheet calls through
    `ResponsiveLayout.showSheetOrDialog`
  - PokemonListScreen renders error/empty states (Offline, Empty
    Search, Empty Filters) based on AsyncValue + isDiscovery
  - PokemonDetailScreen wraps in master-detail when expanded
    (T-28 / RF-46)
  - PokemonListScreen grid column count from `ResponsiveLayout.gridColumns`
- **Test surface:** unit tests for breakpoint logic, widget tests
  for each error/empty widget (parameterized), golden tests per
  breakpoint for Home (compact / medium / expanded), golden tests
  for master-detail layout on expanded.
- **5-agent review:** `docs(review):` under
  `docs/reviews/2026-05-XX-presentation-part4/`.

## Open Questions

- **`cached_network_image` pinning.** The card and detail artwork
  needs caching. Verify latest stable major and whether it pulls
  any transitive analyzer-bound codegen — per
  [[project_analyzer9-toolchain]] the current pin keeps freezed/riverpod
  on the analyzer-9 stable line; a wrong dep could break that. Decide
  at plan time (PR1).
- **SVG vs PNG for type icons.** Figma may export type icons (Bug,
  Fire, etc.) as SVG or as raster glyphs in an icon font. If SVG,
  add `flutter_svg`. Confirmed via `get_design_context` on frame
  `268:0` at PR1 plan time.
- **Tab implementation strategy for Detail.** Stock `TabBar` +
  `TabBarView` inside `DefaultTabController` is the obvious choice,
  but Figma may show a custom segmented control (Profile #1 frames).
  Confirm against `get_screenshot(268:320)` at PR3 plan time — if
  custom, build a `_SegmentedTabs` widget in the same PR.
- **Header artwork source.** PRD/Tech Spec don't specify whether to
  use the PokéAPI `sprites.other['official-artwork'].front_default`
  or another sprite variant. Tech Spec §11 implies the detail header
  uses official artwork. Confirm against frame `268:320` and pick the
  sprite path at PR3 plan time; the `PokemonDetail` entity already
  carries sprite URLs from the mapper.
- **Evolution-stage navigation behavior.** Tapping an evolution stage
  could `context.go('/pokemon/$id')` (replaces current route — clean
  URL stack) or `context.push` (back stack accumulates). PRD UC-07
  says "abre o detalhe correspondente" without specifying. Lean
  `context.go` so deep links remain canonical and the back stack
  doesn't grow on a 3-stage chain. Confirm at PR3 plan time.
- **Pull-to-refresh integration with discovery mode.** RF-08 says
  pull-to-refresh always works on the list. In discovery mode the
  list is cache-only — should refresh kick a network revalidation
  for the underlying `getPokemonList` even in discovery? Probably
  yes (the user expects "refresh" to mean "ask the network"), but
  this stretches `findPokemon`'s contract. Decide at PR2 plan time;
  if needed, the VM can fire both `getPokemonList(0)` (to fill cache)
  and re-run `findPokemon` after.
- **Stream-bridge race on rapid mode flips.** If the user types,
  clears, types, clears in quick succession, the watch subscription
  is rapidly torn down and re-created. Include a unit test in PR2
  that fires 5 mode flips back-to-back and asserts a single live
  subscription at the end (no leaks, no duplicate emissions).
