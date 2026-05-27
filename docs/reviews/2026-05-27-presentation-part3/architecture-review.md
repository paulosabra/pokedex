# Architecture Review — PR3 (presentation-part3)

**Branch**: `feature/presentation-part3` → `epic/presentation-layer`
**Scope reviewed**: detail screen layer — `PokemonDetailViewModel`, `pokemonEvolutionProvider`,
`PokemonDetailScreen`, `DetailHeader`, `AboutTab`, `StatsTab`, `EvolutionTab` (recursive),
plus the router and `app_boot_test.dart` updates.
**Reference**: `docs/plan/2026-05-26-feat-presentation-layer-plan.md` §"PR3 — Detail tabs"
and Tech Spec §5.2.

## Summary

**Architecture is clean. Ready to merge from a layered-architecture standpoint.**

The detail layer adheres to VGV layered architecture verbatim: presentation imports only
`domain/`, `core/`, and `app/theme/`; no path under PR3 reaches into `data/`. Both feature-
specific providers are correctly family-keyed and isolated. The two conditional collapses
flagged in the plan (`PokemonDetailState` → bare `AsyncValue<PokemonDetail>`, and
`PokemonEvolutionViewModel` → function provider) are well-reasoned and consistent with
YAGNI as long as PR4's refresh affordance is added at the same point in the file where the
plan's docstring already promises the pattern. The DS-component boundary (`lib/core/ui/**`
must not import features) is unbroken — PR3 added no files under `lib/core/ui/`. One
architectural deviation from the plan worth noting (the `_EvolutionBranch` "first child shows
parent" branching shape replaces the plan's "stack-then-Row" shape), but it is a layout
implementation detail, not a layer violation.

No blockers. Three fix-class items (all small) and four suggestions follow.

## Blockers

None.

## Fixes

### F-1 — `PokemonDetailViewModel` is a degenerate MVVM shim today; either own a `refresh()` intent or document that PR4 will

`<lib/features/pokemon/presentation/view_models/pokemon_detail_view_model.dart:22-31>`

The class is a 9-line `build`-only AsyncNotifier with no public intents. The plan
(`docs/plan/2026-05-26-feat-presentation-layer-plan.md:686, 704`) explicitly named
`refresh()` as the intent surface that justifies keeping a class over a function provider.
Without it, the class extends `_$PokemonDetailViewModel` solely for the family-keyed lifecycle
— exactly what a `@riverpod Future<PokemonDetail> pokemonDetail(Ref ref, int id)` function
provider gives you for free (and what the Evolution tab already collapses to).

Two acceptable resolutions:

1. **Add `Future<void> refresh()` now** (low risk; ~15 lines mirroring the docstring's own
   `AsyncLoading.copyWithPrevious(state)` recipe). This honors the §5.2 contract literally
   and turns the class shape into a load-bearing decision, not a placeholder.
2. **Collapse to a function provider** like `pokemonEvolutionProvider` and add `refresh()` in
   PR4 when the pull-to-refresh AC actually lands. This is the strictly YAGNI move.

The current shape is the worst of both: the file claims MVVM-VM status (docstring, class form,
"§5.2" reference) but has no behavior a function provider couldn't deliver. Pick one. If the
project keeps the class, leave a `// TODO(PR4): refresh()` so the asymmetry against
`pokemonEvolutionProvider` is intentional and traceable.

### F-2 — `_EvolutionBranch` rendering shape diverges from the plan; align the plan or document the divergence

`<lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart:63-89>`

The plan's snippet
(`docs/plan/2026-05-26-feat-presentation-layer-plan.md:722-743`) describes a
**stack-then-Row** layout: render the current node, then either recurse vertically (one
child) or wrap children in a `Row` (multiple children).

PR3 implements a **first-child-shows-parent** layout: every child renders a `_Pair`, and only
the first child renders the parent card; subsequent siblings render a blank `SizedBox.shrink()`
where the parent would go. This is a deliberate, defensible design (it sidesteps the
unbounded-width Row problem the plan would create for Eevee's 8 children), but it changes the
shape of the recursive contract:

- The plan's recursion is over `EvolutionNode`; PR3's recursion is over `(parent stage, child
  node)` pairs.
- "Recurse into grandchildren of this branch" at line 126-130 calls
  `_EvolutionBranch(node: child)` — but `child.evolvesTo` may itself branch, and the layout
  will then render every grandchild paired with `child` as parent, repeating the same
  first-child-only mechanic. For a deep, branching tree (rare in PRD scope, but possible) the
  visual breaks: the `_Pair`'s `left: 117` indent stacks linearly, so a 3-deep branch from a
  middle child can collide with the parent's other branches above.

Recommended: update the plan inline (a one-paragraph note in §PR3 saying "first-child-
shows-parent supersedes the stack-then-Row sketch because Eevee's 8 branches don't fit a Row")
**and** add a comment at line 63 of `evolution_tab.dart` referencing the plan revision. The
test surface (Eevee fixture, linear chain, no-evolution) covers the shapes that exist in
canonical PRD data; the divergence is a layout call, not an architectural one. But the plan
and the code must agree, otherwise the next reviewer will read the plan first and flag the
code as wrong.

### F-3 — `EvolutionTab` reaches into `app/theme` to recompute the accent the parent already knows

`<lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart:32-36>`,
`<lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:81-84>`

`EvolutionTab` takes `primaryType` and re-derives `accent` via
`PokemonTypeTheme.styleOf(primaryType).color`. `AboutTab` (`about_tab.dart:26-28`) and
`StatsTab` (`stats_tab.dart:27-29`) each do the same derivation from `detail.summary.types.first`.
The duplication is small but the pattern crystallizes a question: where should the type-derived
accent color live?

Two paths:

- Keep the per-tab derivation (current). Defensible for AboutTab/StatsTab because they receive
  `detail` and the accent is "a single line"; less defensible for `EvolutionTab` which is the
  only tab that doesn't receive `detail` and therefore needs `primaryType` as a separate
  parameter solely to derive the accent.
- Pass `accent` as a parameter from `_Loaded` (which already computes
  `PokemonTypeTheme.styleOf(primary).backgroundColor` at `pokemon_detail_screen.dart:51`) and
  drop `PokemonTypeTheme` imports from all three tabs.

Either is fine. Recommend the second if PR4 adds any responsive switching that re-mounts tabs
in different orders — passing the resolved color from the host removes a recomputation per
rebuild and removes a dependency from `widgets/detail/` on `app/theme/pokemon_type_theme.dart`.

## Suggests

### S-1 — `pokemonEvolutionProvider` lives under `view_models/`; consider `providers/` if convention crystallizes

`<lib/features/pokemon/presentation/view_models/pokemon_evolution_provider.dart:1>`

The file is a function provider, not a ViewModel — every comment in it says so. Keeping it
under `view_models/` works for now (the docstring is explicit), but if PR4 adds a second
function-style provider (e.g., a derived selector over the list state), the
`presentation/view_models/` folder name will start to lie. The grep-ability win of one folder
per role is not negligible. **Not a fix** — this is purely a naming convention. Acceptable to
defer to PR4 if a second non-VM provider lands; revisit when it does.

### S-2 — Recursive widget belongs at `widgets/detail/` — it does, but worth flagging the lint cost for future maintainers

`<lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart:63-89>`

`_EvolutionBranch` is correctly file-private (`_` prefix), correctly scoped to the feature
(`features/pokemon/presentation/widgets/detail/`), and correctly stateless. The fact that the
plan called this "PR3's most complex widget" and the implementation is ~70 lines of
declarative tree-walk is exactly the win MVVM promises. No action needed. Documented here
because the alternative — putting recursive layout helpers in `core/ui/` — would have been a
silent layer violation (DS components import features) and the plan rightly didn't propose it.

### S-3 — `DetailHeader` is feature-specific and lives at the right layer

`<lib/features/pokemon/presentation/widgets/detail/detail_header.dart:15-25>`

The component takes primitive params (id, name, primary type, secondary type, image URL, back
callback) like the PR1 DS components do, but it lives at `features/pokemon/presentation/
widgets/detail/` instead of `core/ui/components/`. The right call: the header's composition
(name watermark + circle + #NNN + name + badges in this exact layout) is the Pokémon detail
screen's defining visual, not a reusable DS primitive. The lint guard
(`test/core/ui/import_boundary_test.dart`) doesn't apply here because the file is under
`features/`, not `core/ui/`, but the underlying principle (don't put feature-coupled
composition under DS) is honored. No action.

### S-4 — `_Loaded.build` reads `detail.summary.types.first` without an empty-types guard

`<lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:49-51>`

`final primary = types.first;` will throw `StateError` if the Pokémon has zero types. The
domain entity (`pokemon.dart`) defaults `types` to `[]`, and the data mapper (`pokemon_detail
_mapper.dart`) constructs `Pokemon` from PokéAPI which guarantees at least one type — so this
is theoretical. But the screen's error path doesn't handle the failure: an empty-types Pokémon
would render `_Loaded` (the VM succeeded), then crash inside `_Loaded.build` with a
`StateError`, which is not the same as `_Error`. A one-line guard
(`if (types.isEmpty) return _Error(error: const FormatFailure())` or similar) is cheap
insurance against bad cache writes. Not blocking — defer to PR4 errors+responsive scope if you
prefer.

## Layer Separation — file-by-file scan

Every PR3 source file was scanned for cross-layer imports:

| File | Layer | Imports cross-layer? |
| --- | --- | --- |
| `lib/features/pokemon/presentation/view_models/pokemon_detail_view_model.dart` | presentation | No — `core/error/result`, `domain/entities/pokemon_detail`, `domain/usecases/get_pokemon_detail`, `riverpod_annotation` |
| `lib/features/pokemon/presentation/view_models/pokemon_evolution_provider.dart` | presentation | No — `core/error/result`, `domain/entities/evolution_chain`, `domain/usecases/get_evolution_chain`, `riverpod_annotation` |
| `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart` | presentation | No — `flutter/material`, `flutter_riverpod`, `go_router`, `app/theme/*`, `core/error/failure`, `domain/entities/pokemon_detail`, sibling VM, sibling tab widgets |
| `lib/features/pokemon/presentation/widgets/detail/detail_header.dart` | presentation | No — `cached_network_image`, `flutter/material`, `app/theme/*`, `core/pokemon/pokemon_type_id`, `core/ui/components/type_badge` |
| `lib/features/pokemon/presentation/widgets/detail/about_tab.dart` | presentation | No — `flutter/material`, `app/theme/*`, `core/pokemon/pokemon_type_id`, `core/ui/components/type_badge`, `domain/entities/{ability,breeding,pokemon_detail}` |
| `lib/features/pokemon/presentation/widgets/detail/stats_tab.dart` | presentation | No — `flutter/material`, `app/theme/*`, `core/pokemon/pokemon_type_id`, `core/ui/components/type_badge`, `domain/entities/{pokemon_detail,stat_set}` |
| `lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart` | presentation | No — `cached_network_image`, `flutter/material`, `flutter_riverpod`, `go_router`, `app/theme/*`, `core/pokemon/pokemon_type_id`, `domain/entities/evolution_chain`, sibling provider |
| `lib/app/router/app_router.dart` (unchanged in PR3) | app | No — `go_router`, `presentation/pages/*`, `riverpod_annotation` |

Negative greps confirming the boundaries:

- `grep -rn "package:pokedex/features/pokemon/data" lib/features/pokemon/presentation/` → **empty**
- `grep -rn "package:pokedex/features" lib/core/` → **empty** (the PR1 import-boundary
  contract holds; PR3 added no new files under `lib/core/`)
- `grep -rn "package:flutter/" lib/features/pokemon/domain/` → no Flutter SDK imports in
  domain entities

Result: **zero layer-separation violations**.

## State Management Correctness — Riverpod 3 family providers

| Check | Detail VM | Evolution provider |
| --- | --- | --- |
| Family keyed by `int id`? | Yes — `build(int id)` (`pokemon_detail_view_model.dart:24`) | Yes — `pokemonEvolution(Ref ref, int id)` (`pokemon_evolution_provider.dart:19`) |
| `ref.watch` vs `ref.read` boundary | `ref.read(getPokemonDetailProvider)` for an imperative call — correct | `ref.read(getEvolutionChainProvider)` for an imperative call — correct |
| `Result<T>` translated at the boundary | Yes — `switch ... Err: throw failure` (`pokemon_detail_view_model.dart:26-29`) | Yes — same shape (`pokemon_evolution_provider.dart:21-24`) |
| Provider keying isolation tested | Yes — `pokemon_detail_view_model_test.dart:55-85` asserts `vm(1)` and `vm(4)` are independent | Yes — `pokemon_evolution_provider_test.dart:65-84` asserts same for id 1 / 133 |
| Async lifecycle (timers, streams, subscriptions) | None — `build` does one `await` and returns. No `ref.onDispose` needed because there's nothing to dispose. | Same — pure one-shot async function. |
| Mutable fields on the notifier | None | n/a (function provider) |

Comparison against the PR2 `PokemonListViewModel` (`pokemon_list_view_model.dart`): PR2's VM
registers `ref.onDispose` first (line 47) because it owns a `Timer` and a `StreamSubscription`.
PR3's VM owns neither, so the omission is correct, not an oversight. The screen reads
`pokemonDetailViewModelProvider(id)` via `ref.watch` (`pokemon_detail_screen.dart:33`) and the
Evolution tab does the same via `pokemonEvolutionProvider(id)` (`evolution_tab.dart:37`) —
correct for `AsyncNotifier`/async function provider consumption.

The Evolution tab passes `skipLoadingOnReload: true` (`evolution_tab.dart:49`) — correct for
the "About + Stats render first while evolution loads" UX (resolved refine 7 in the plan):
once the chain has resolved once, navigating tabs back-and-forth won't flash a skeleton on
re-mount.

Result: **state management is correct.** One nit — F-1 above re: the VM being a degenerate
shim, which is a class-shape decision, not a correctness bug.

## Dependency Direction — graph stays one-way

Verified flow (presentation → domain → data is implicit through repository impl):

```
PokemonDetailScreen (ConsumerWidget)
    ↓ ref.watch
pokemonDetailViewModelProvider(id) (AsyncNotifier, family)
    ↓ ref.read
getPokemonDetailProvider (use case)
    ↓ injects
pokemonRepositoryProvider (binding, from data/)
    ↓ implements
PokemonRepository (domain interface)

EvolutionTab (ConsumerWidget)
    ↓ ref.watch
pokemonEvolutionProvider(id) (function provider, family)
    ↓ ref.read
getEvolutionChainProvider (use case)
    ↓ injects
pokemonRepositoryProvider
```

No reverse edge. The presentation layer never names `pokemonRepositoryProvider` or any
`data/` symbol directly. The use cases (`get_pokemon_detail`, `get_evolution_chain`) own the
data-layer binding, exactly as the domain epic shipped them.

## Package Structure

The project is a single Flutter app (not a melos monorepo), so the "package per layer" check
reduces to a per-folder check:

- `lib/features/pokemon/presentation/view_models/` — additions co-located with PR2's
  `pokemon_list_view_model.dart`. Naming inconsistency flagged in S-1 (function provider
  filed alongside ViewModels), not a structural problem.
- `lib/features/pokemon/presentation/pages/` — `pokemon_detail_screen.dart` upgraded from
  placeholder in-place, correct.
- `lib/features/pokemon/presentation/widgets/detail/` — new subfolder for the four detail
  widgets. The grouping under `detail/` (vs. flat `widgets/`) is consistent with PR2's
  `widgets/sheets/` grouping. Good.
- `test/features/pokemon/presentation/fixtures/` — new fixtures folder for `bulbasaur_detail
  _builder.dart` and `eevee_evolution_chain.dart`. Test-only — appropriately scoped, doesn't
  pollute `lib/`.

Single responsibility per file: each tab widget owns one tab's layout, the header widget
owns the header, the VM owns the detail load, the function provider owns the chain load. No
grab-bag files.

## Verdict

**Architecture is clean. Ready to merge.** Layer boundaries hold; both providers are
family-keyed and isolated; the DS-component boundary is unbroken; the dependency graph flows
one way. The three fix-class items (F-1 degenerate VM, F-2 plan-vs-code branching divergence,
F-3 accent duplication) are stylistic/contract-alignment calls, not architectural violations.
Resolve them in this PR or carry them into PR4 — either choice is sound. The four
suggestions are forward-looking. Approving from the architecture seat.
