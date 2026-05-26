# VGV Code Review — Domain Layer (T-15 revision + T-16 + T-17)

**Scope:** staged + untracked changes on `feature/domain-layer` against
`docs/plan/2026-05-26-feat-domain-layer-plan.md`. Generated `*.g.dart` files were inspected but
not reviewed for style. The deliberate trade-off in the plan — use case provider functions in
`domain/usecases/` referencing `pokemonRepositoryProvider` from `data/repositories/` — is treated
as accepted by design.

**Stack detected:** Flutter (Dart `^3.12.0`), Riverpod 3 + `riverpod_annotation`/`riverpod_generator`
pinned to analyzer-9, Drift 2.31 (pinned), Dio/Retrofit remote, `connectivity_plus ^7.1.1`,
`go_router ^17.2.3` (no `go_router_builder`), `very_good_analysis` lints, `flutter_test` + `mocktail`
+ in-memory Drift for tests. Layered Clean Architecture (core → data → domain → presentation).

---

## Summary

This is a clean, well-scoped slice that lands the domain ring exactly as planned. The
`PokemonRepository` interface change is surgical and one-shot (no callers besides its own impl, so
the cost of collapsing `search()` + `filter()` is paid once and only once); the five use cases are
genuinely intent-only pass-throughs that respect DIP at the class level; the Riverpod 3 provider
graph is sensibly stratified between `keepAlive` resource-holders and default-lifecycle stateless
wrappers; the `MaterialApp.router` rewire is minimal and tested for both default and deep-link
entry paths. `dart analyze` is green, `dart format` is clean, the full test suite passes (no
flaky timing patterns), and the keepAlive contract test does what it advertises — verifying
identity preservation across a downstream rebuild rather than smoke-testing that codegen produced
output. Coverage on hand-written (non-`*.g.dart`) sources is 93% — comfortably above the 80% gate.

The acceptable-by-plan composition cross-layer import (use case provider functions referencing
`pokemonRepositoryProvider` from the data layer) is implemented exactly as the plan describes:
each use case **class** depends only on the `PokemonRepository` interface; only the **provider
function** at the bottom of the file reads the data-layer provider. This is the same pattern the
data layer already uses for `pokemonRepositoryProvider → pokemonRemoteDataSourceProvider/
pokemonLocalDataSourceProvider`. It is a deliberate convention, documented in the plan, and the
costs (one cross-layer symbol import per use case file) are bounded.

There is **one missing-coverage item** worth flagging: the `keepAlive` contract test asserts
identity preservation for `dioProvider`, `appDatabaseProvider`, and `connectivityProvider`, but
**not** for `routerProvider`. The plan's risk register explicitly names the router alongside the
other three (Risks & Mitigations row 2 — "missing `keepAlive: true` on `Connectivity` /
`AppDatabase` / `Dio` / router silently leaks resources"). Of the four, the router is the most
user-visible failure: dropping it on rebuild resets the back stack. The test would extend to one
extra read + identity assertion (no new fixtures needed).

A few smaller observations are listed as 🔵 Suggestions; none block merge.

**Verdict: ready to merge after one small test addition (routerProvider keepAlive identity check).**

---

## 🔴 Critical — Must Fix Before Merge

None.

---

## 🟡 Important — Should Fix

- **`test/app/provider_graph_test.dart:41-67`** — the `keepAlive` contract test covers
  `dioProvider`, `appDatabaseProvider`, and `connectivityProvider`, but not `routerProvider`. The
  plan's risk register names the router as one of the four `keepAlive` invariants
  (`docs/plan/2026-05-26-feat-domain-layer-plan.md:461` and `:425-427` — "Read each of `dioProvider`,
  `appDatabaseProvider`, `connectivityProvider`, `routerProvider` once; capture the four returned
  instances by identity"). The router is also the one with the most visible failure mode (back
  stack reset on rebuild) of the four.
  - Why: A regression flipping `@Riverpod(keepAlive: true)` on the router to default lifecycle
    would silently drop navigation history on any downstream consumer rebuild. The boot/deep-link
    widget tests pump a single frame and use `routerProvider.overrideWith(...)`, so they cannot
    catch this — the real `routerProvider` body has 0% coverage at present
    (`lib/app/router/app_router.dart` `DA:11..27` all `,0`).
  - Fix: extend the existing `keepAlive contract` group to also read `routerProvider` before and
    after the `invalidate(pokemonRepositoryProvider)` step, and assert `identical(before, after)`.
    The router instance is constructible without overrides — no provider it depends on touches
    platform channels — so no extra fakes are needed. Example:
    ```dart
    final routerBefore = container.read(routerProvider);
    // ... existing invalidate / read ...
    expect(identical(routerBefore, container.read(routerProvider)), isTrue);
    ```

---

## 🔵 Suggestions — Nice to Have

- **`lib/app/router/app_router.dart:13-28`** — the `router` function constructs the `GoRouter`,
  binds `ref.onDispose(router.dispose)`, and returns it. The local variable name `router` shadows
  the outer function name `router`, which is harmless but slightly distracting at the read site.
  - Suggestion: rename the local to `goRouter` (or inline the dispose: `final goRouter = GoRouter(...);
    ref.onDispose(goRouter.dispose); return goRouter;`). Cosmetic only; no behavior change.

- **`lib/features/pokemon/domain/usecases/*.dart`** — every use case provider's doc comment is
  copy-paste-identical ("Provides the &lt;UseCase&gt; use case bound to the shared repository.").
  This is fine and the canonical name of each provider is already unambiguous, but the comments
  add no information beyond what the symbol name carries.
  - Suggestion: optional — drop these one-liners since they are pure paraphrase. Keep the class-
    level dartdoc (which **does** carry signal: UC/RF backlog references, pass-through intent).

- **`lib/core/network/connectivity_provider.dart`** — the file name carries the suffix `_provider`
  while every other provider in this PR is co-located in a file named after the wrapped type
  (`dio_client.dart` exposes `dioProvider`, `app_database.dart` exposes `appDatabaseProvider`,
  `poke_api_service.dart` exposes `pokeApiServiceProvider`, `pokemon_dao.dart` exposes
  `pokemonLocalDataSourceProvider`, etc.). The plan explicitly chose to introduce a new file for
  `Connectivity` because there was no existing wrapper file to host the provider — that decision
  is defensible — but the `_provider` filename convention is not consistent with the other six
  provider files.
  - Suggestion: optional — rename to `lib/core/network/connectivity.dart` for filename consistency.
    No user-visible change; the only file referencing the path is the repo impl + tests, and a
    search-and-replace on the imports closes it.

- **`lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:16-21`** — the placeholder
  uses `ListView(children: [ListTile(...)])`. With one child, `Center(child: ListTile(...))` or
  `ListView.builder(itemCount: 1, ...)` is unnecessary either way; this is fine. The smoke link
  is well-placed.
  - No fix needed. Noting that the placeholder is intentionally minimal per plan — the UI epic
    will replace it.

- **`lib/features/pokemon/domain/usecases/watch_pokemon_list.dart:24`** — the `WatchPokemonList`
  class doesn't carry the same `Result` wrapper as the other four use cases, which is documented
  in the class-level dartdoc and validated by the explicit static-type test
  (`test/features/pokemon/domain/usecases/watch_pokemon_list_test.dart:98-118`). The
  `// ignore: omit_local_variable_types` annotation in that test is justified inline — keep the
  comment. Good defensive testing.

- **`lib/app/router/app_router.dart:13`** — `GoRouter` constructor doesn't accept `restorationScopeId`
  in this minimal config; route restoration on hot restart is out of scope for the placeholder
  router. Document or defer to UI epic.
  - No fix needed; explicitly out of scope per the plan ("Out of Scope" §). Calling it out for the
    UI epic backlog.

---

## Simplicity Assessment

- **Lines that could be removed:** ~5–6 (per-provider doc one-liners) — purely cosmetic.
- **Unnecessary abstractions:** none. The five use case classes are documented-on-purpose ceremony
  (Plan's "Risks & Mitigations" row 4 explicitly accepts the cost; brainstorm + plan agree). Each
  is one constructor, one final field, and one `call(...)` — they earn their keep as the
  Presentation-layer's "intent vocabulary" anchor point and as the seam where future business
  rules (cross-repo composition, side effects) will land without re-touching the UI.
- **YAGNI violations:** none. No speculative `BaseUseCase`, no `Either`/`Failure` re-mapping inside
  the use cases, no `equatable`/`copyWith` ceremony on stateless wrappers, no premature `Stream`
  → `BehaviorSubject` upgrade in `WatchPokemonList`. The use case classes are the smallest unit
  that justifies its existence — and exactly five of them, one per intent.
- **Complexity verdict:** Already minimal. The single complex composition (cache-first SWR) lives
  in the data layer; the domain ring this PR adds is a clean wrapper on top.

---

## Testing Assessment

- **New code with tests:** ✅ Every new use case has a dedicated test file; the repository's
  `search`/`filter` block is fully refreshed into a parametric `findPokemon` matrix (only-sort,
  only-query, only-filter, query+filter, corrupt-row); the boot test is updated for
  `MaterialApp.router`; the deep-link test exercises the `/pokemon/:id` route with id=25; the
  provider graph test asserts identity preservation across a downstream rebuild and validates
  use-case provider runtime types.
- **Test quality:** Meaningful. Each `Future<Result<T>>` use case test verifies both the
  Ok-pass-through and the Err-pass-through (no happy-path-only tests), and the `verify(...)` calls
  are scoped to the load-bearing assertion (the use case forwarded its inputs verbatim — not call
  counting). `WatchPokemonList` adds two propagation tests (initial + subsequent emissions) and
  one static-type assertion (`Stream<List<Pokemon>>` vs `Stream<Result<...>>`) — this is the right
  level of paranoia for the one use case whose signature differs from the other four. The
  `// ignore: omit_local_variable_types` directive is annotated inline with the load-bearing
  rationale.
- **`mocktail` patterns:** ✅ `registerFallbackValue(SortCriteria.numberAsc)` is correctly used at
  `setUpAll` for the use case tests whose mocks take `SortCriteria` named-params; matchers use
  `any(named: 'foo')` for forwarding-verification, then `verify(...)` re-binds the exact values to
  prove no transformation occurred. No over-verification (e.g. no `verifyNever` on unused mock
  paths in tests where it doesn't matter). The `_FakeDetail` / `_FakeChain` `Fake` subtypes are
  the right choice for opaque value returns where the test doesn't depend on the payload —
  exactly the VGV convention.
- **State management test coverage:** N/A this slice — no Bloc/Cubit/ViewModel yet (UI epic T-19+).
  The provider graph test verifies the wiring substitutes the impl correctly and the keepAlive
  contract holds for three of the four resource-holders. **`routerProvider` is the gap** (see 🟡
  Important above).
- **UI component test coverage:** ✅ for the placeholder scope — `PokedexApp` boots, the
  `MaterialApp.router` composes, `/` renders the list placeholder, `/pokemon/25` renders the
  detail placeholder. No widget tests for the placeholders themselves; that's appropriate at this
  stage (they're trivial and the UI epic replaces them).
- **Coverage:** 93% on hand-written sources (627/674 lines, excluding `*.g.dart`). The headline
  number reported by `lcov.info` (62.96%) is dragged down by generated Drift table boilerplate
  and the Drift `_$AppDatabase` mixin — neither of which is project code. Sources at &lt;80% on
  hand-written code: `lib/app/router/app_router.dart` (0%, the symbol the boot tests override
  away — see 🟡 fix), `lib/core/database/app_database.dart` (10%, mostly Drift `Table` field
  getters that codegen consumes), `lib/core/network/connectivity_provider.dart` (0%, the body
  `Connectivity()` is never directly called because tests override the provider with a fake — this
  is correct and the function is one trivial line). The 80% gate is met on real code.

---

## Architecture & Convention Notes (PASS)

- **Dependency rule:** ✅ Pure-domain code (`lib/features/pokemon/domain/{entities,repositories}/`)
  has zero imports from `data/` — grep-confirmed (`grep -rn "import.*data/" lib/features/pokemon/
  domain/entities lib/features/pokemon/domain/repositories` returns empty). The intentional
  cross-layer reference lives only in the **provider functions** at the bottom of each use case
  file (`import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';`).
  Each use case **class** takes `PokemonRepository` (the interface) via its constructor — DIP is
  preserved on the runtime side. This matches the plan's documented trade-off ("the use case's
  static type is always the interface (DIP)", plan L348).
- **Layer separation:** ✅ Presentation placeholders (`pokemon_list_screen.dart`,
  `pokemon_detail_screen.dart`) import only `flutter/material` and `go_router`. No state
  management, no ViewModels, no repository or use case references — they are pure placeholder
  widgets, by design.
- **Riverpod 3 conventions:** ✅ All providers use the generic `Ref` parameter (not the codegen
  `<Name>Ref` typedef — `Ref` is the Riverpod 3 stable equivalent and lets the impl be agnostic
  to the provider's name). `@Riverpod(keepAlive: true)` on the four resource-holders
  (Dio/AppDatabase/Connectivity/GoRouter) is correct. Stateless wrappers (service, datasources,
  repo, use cases) use the default lifecycle (`isAutoDispose: true` in codegen) — checked
  against the `.g.dart` outputs. The `appDatabaseProvider` correctly chains
  `ref.onDispose(db.close)`; the `routerProvider` correctly chains `ref.onDispose(router.dispose)`.
- **Provider co-location:** ✅ Convention is followed (the plan's "Datasource provider
  co-location" note matches the actual layout): `dioProvider` → `dio_client.dart`,
  `appDatabaseProvider` → `app_database.dart`, `pokeApiServiceProvider` → `poke_api_service.dart`,
  `pokemonRemoteDataSourceProvider` → `pokemon_remote_data_source.dart`,
  `pokemonLocalDataSourceProvider` → `pokemon_dao.dart` (alongside the implementing class, not
  the interface — explicitly justified in the plan), `pokemonRepositoryProvider` →
  `pokemon_repository_impl.dart`, each `<UseCase>Provider` → its own use case file.
  `connectivityProvider` is the only one in a dedicated file because `Connectivity` is a
  third-party type without a wrapper. Minor filename consistency suggestion in 🔵 above.
- **DIP at the runtime boundary:** ✅ The `pokemonRepositoryProvider` returns the abstract type
  `PokemonRepository` (not `PokemonRepositoryImpl`), so use cases reading the provider see only
  the interface even if they wanted to bypass DIP. Same pattern for
  `pokemonRemoteDataSourceProvider` and `pokemonLocalDataSourceProvider`.
- **T-15 revision:** ✅ `search(String)` and `filter(PokemonFilter, {sort})` are removed from both
  the interface and the impl; `findPokemon({sort, query?, filter?})` is a single one-line
  delegation to `_local.querySummaries(...)` — no logic added in the repo. Tech Spec §8.3 is
  updated in lockstep (`docs/project/02-tech-spec.md`).
- **Immutability & naming:** ✅ All entities remain immutable Freezed value types
  (`PokemonPage`, `Pokemon`, `PokemonDetail`, `EvolutionChain`, etc., from PR3) — domain code
  in this PR adds zero new entities, only consumes the existing ones. Use case class names pass
  the 5-second rule (`GetPokemonList`, `FindPokemon`, `GetPokemonDetail`, `GetEvolutionChain`,
  `WatchPokemonList`). No `Manager`/`Handler`/`Utils`/`Helper`.
- **Cleanliness:** ✅ No lint suppressions in this PR's hand-written sources (the one
  `// ignore: omit_local_variable_types` is in a test, with a load-bearing justification). No
  `TODO`/`FIXME`. No commented-out code. No `print`/`debugPrint`. `dart analyze` clean.
  `dart format` clean.

---

## Regressions & Breaking Changes (CONTROLLED)

- **Removed code:** `search()` and `filter()` are removed from `PokemonRepository` (interface +
  impl). At this point in the project, the only callers were the now-refreshed repo-impl tests —
  no external callers exist yet. The plan's "Interface stability" argument (plan L41-48) is
  validated by the change being free of caller fan-out. The Tech Spec is updated in the same PR.
- **Changed signatures:** `watchCachedSummaries` was already a `{sort, filter}` named-param API
  in PR3, so no signature change there.
- **State changes:** `lib/app/app.dart` switches from `StatelessWidget` + `MaterialApp` +
  `home: Scaffold()` to `ConsumerWidget` + `MaterialApp.router` + `routerConfig: routerProvider`.
  The pre-existing boot test is updated to reflect the new shape and stays green; the addition
  of the deep-link test guards against future regression. `lib/main.dart` adds a `ProviderScope`
  wrapper — this is additive and necessary for any `WidgetRef` consumer downstream.
- **Test coverage:** No tests deleted or weakened. The old `search()`/`filter()` block in
  `pokemon_repository_impl_test.dart` is replaced by a `findPokemon` matrix that covers the same
  branches (sort-only, query, filter, intersection, corrupt-row) and adds the explicit
  "with only sort" case the plan mandated. `watch` tests are preserved verbatim.
- **Dependencies:** One new runtime dep — `go_router: ^17.2.3`, no codegen sister. The plan
  validated this won't drag pinned codegen onto `-dev` builds (no shared dependency surface);
  `flutter pub get` resolves cleanly with the existing pinned set. `pubspec.lock` is committed.

---

## Acceptance Criteria — Plan Trace

Mapping the plan's `Acceptance Criteria` (L437-454) to evidence in this review:

- [x] `flutter pub get` resolves cleanly; `pubspec.lock` committed — confirmed.
- [x] `dart run build_runner build --delete-conflicting-outputs` green — `.g.dart` files
      present and well-formed for every `@Riverpod`-annotated provider.
- [x] `dart analyze` green — confirmed locally.
- [x] `dart format` clean — confirmed (`dart format --output=none --set-exit-if-changed`).
- [x] All five use case test files green — confirmed via full `flutter test` run.
- [x] Repo impl `findPokemon` matrix green — confirmed.
- [x] Boot + deep-link widget tests green — confirmed.
- [x] Provider graph test green — confirmed, **with one missing-row gap** (see 🟡 Important):
      `routerProvider` keepAlive identity is not asserted.
- [x] Coverage ≥ 80% on hand-written domain code — 93% on non-generated sources.
- [x] `PokemonRepository` no longer exposes `search()`/`filter()`; Tech Spec §8.3 reflects the
      new surface — confirmed.

Manual smoke (`flutter run`, browser deep-link `/pokemon/25`) and `/review` outputs were not
performed by this reviewer — they're the developer's pre-merge gate per the plan.

---

## Conclusion

Ship-quality. One small test addition closes the only remaining gap against the plan's stated
risk register (the router's keepAlive identity check). Everything else lines up: the interface
revision is surgical, the use cases are appropriately ceremonial without crossing into overkill,
the provider graph honors Riverpod 3 conventions and the keepAlive trade-offs are deliberate, and
the test suite earns its coverage with meaningful assertions rather than tautologies. The
deliberate composition-root cross-layer import in use case provider files is well-documented and
implemented exactly per spec.
