# Architecture Review — `feature/presentation-part1`

**Scope reviewed**: PR1 of the presentation-layer epic. Two architectural-level
changes: (1) Design System kit under `lib/core/ui/components/` (6 stateless
widgets) and (2) retroactive domain revision adding `int? generationId` to
`PokemonFilter` with the matching DAO WHERE branch.

**Reviewer**: architecture-review-agent
**Date**: 2026-05-26
**Plan reference**: `docs/plan/2026-05-26-feat-presentation-layer-plan.md`
**Verdict**: **Ready to merge** — architecture is clean. No critical or
important issues. Three suggestions for forward consistency.

---

## 1. Layer Separation

### Detected layers (single-package app, no monorepo)

The repo organizes responsibilities by directory rather than by Pub package:

| Layer (logical)              | Path                            | Allowed dependencies                                  |
| ---------------------------- | ------------------------------- | ----------------------------------------------------- |
| Cross-cutting kernel         | `lib/core/{error,network,database,pokemon}/` | Flutter SDK, 3p packages, sibling `core/` modules |
| Design System                | `lib/core/ui/`                  | `core/` kernel, `app/theme/`, Flutter SDK, 3p UI deps |
| App composition (theme/router) | `lib/app/{theme,router}/`     | `core/`, feature presentation entry points (router only) |
| Feature — data               | `lib/features/pokemon/data/`    | `core/`, own `domain/` interfaces                     |
| Feature — domain             | `lib/features/pokemon/domain/`  | `core/error`, `core/pokemon`                          |
| Feature — presentation       | `lib/features/pokemon/presentation/` | `core/ui`, `app/theme`, own `domain/` (and current data DI pre-existing) |

### Layer-separation findings

**All six new DS files** (`lib/core/ui/components/*.dart`) were scanned line by
line. Every import is either Flutter SDK, an approved 3p (`cached_network_image`),
the theme tokens in `lib/app/theme/`, the kernel-level `PokemonTypeId` in
`lib/core/pokemon/`, or a sibling DS component. **Zero** imports from
`package:pokedex/features/**` appear under `lib/core/ui/**`.

```
lib/core/ui/components/pokemon_card.dart      → app/theme, core/pokemon, sibling DS
lib/core/ui/components/type_badge.dart        → app/theme, core/pokemon
lib/core/ui/components/stat_bar.dart          → app/theme
lib/core/ui/components/section_header.dart    → app/theme
lib/core/ui/components/search_field.dart      → app/theme
lib/core/ui/components/app_bottom_sheet.dart  → app/theme, sibling DS
```

**Static guard** at `test/core/ui/import_boundary_test.dart` mirrors this rule
in CI: it walks `lib/core/ui/**` and fails the build on any
`package:pokedex/features/` import line. The guard is the right shape for the
problem (convention rots; a one-line lint catches it instantly) and is
correctly scoped to the subtree it protects. No false negatives observed: the
file reads every `.dart`, skips none, and matches the `import` keyword at the
trimmed line start.

**No layer violations.**

### Notes on the `app/` ↔ `core/` relationship

Strict Clean Architecture would put `core/` below `app/` (kernel under
composition root). This repo's `app/theme/` imports `core/pokemon/PokemonTypeId`
(theme needs a stable enum to key colors on) — that's already established by
the foundation epic and remains correct. The DS pulls **down and across**
(`core/ui` → `app/theme` → `core/pokemon`), which is one direction only and
forms no cycle. The plan's reasoning for keeping `PokemonTypeId` in `core/`
specifically to keep this chain acyclic is sound and the PR honors it.

---

## 2. Design System Placement — `lib/core/ui/` vs `lib/app/ui/`

**Verdict**: correct call.

The plan's justification — that `PokemonTypeId` already lives at `lib/core/pokemon/`
for the same cross-cutting reason — holds up under inspection. The DS satisfies
the criteria for "core" placement:

1. **Domain-agnostic**: every component takes primitives (`int id`, `String name`,
   `PokemonTypeId primaryType`, …). None imports a domain entity. Replacing the
   word "Pokémon" in the type signatures with "Card" would leave the components
   compilable as a generic kit.
2. **Reusable across features**: when the second feature lands (e.g., a future
   "Trainers" area), DS components like `SectionHeader`, `SearchField`,
   `AppBottomSheet`, `StatBar` would be drop-in.
3. **No app-composition coupling**: nothing in `lib/core/ui/` reaches into
   `lib/app/router/`, `lib/app/app.dart`, or any other composition root.

`lib/app/ui/` would be a worse home because `lib/app/` is becoming the
composition root (router, MaterialApp, theme wiring, soon `layout/` in PR4).
A DS kit doesn't belong in the composition root — it belongs underneath it
where features and the composition root can both consume it.

**One forward-looking observation** (suggestion S1 below): when PR4 lands the
error/empty state widgets, the plan correctly places them under
`lib/core/ui/states/`. PR4 also introduces `lib/app/layout/` (breakpoints,
responsive layout, master-detail) — the plan explicitly justifies that
placement as app-level composition because the scaffold wires routes. That
distinction is right: `core/ui/` is kit; `app/layout/` is composition.

---

## 3. Retroactive Domain Revision — `PokemonFilter.generationId`

**Verdict**: clean additive change. No migration risk, no coupling.

### The change is minimal-surface and isomorphic to the existing path

```dart
// lib/features/pokemon/domain/entities/pokemon_filter.dart
const factory PokemonFilter({
  @Default(<PokemonTypeId>{}) Set<PokemonTypeId> types,
  @Default(<PokemonTypeId>{}) Set<PokemonTypeId> weaknesses,
  HeightCategory? height,
  int? generationId,    // NEW — nullable, no default → backward-compatible
}) = _PokemonFilter;
```

```dart
// lib/features/pokemon/data/datasources/pokemon_dao.dart  (lines 119–122 added)
final generationId = filter.generationId;
if (generationId != null) {
  statement.where((t) => t.generationId.equals(generationId));
}
```

### Why this is not a coupling/migration risk

1. **DB schema unchanged**. `lib/core/database/app_database.dart` line 27
   already declared `IntColumn get generationId => integer()();` as part of the
   foundation epic for exactly this purpose. No migration, no schema change,
   no codegen risk for Drift.
2. **Repository interface unchanged**.
   `PokemonRepository.findPokemon({sort, query, filter})` and
   `watchCachedSummaries({sort, filter})` already accept a `PokemonFilter?`.
   Adding a field to the filter is a value-type extension — no method signature
   moves.
3. **All callers stay green**.
   - Use case (`find_pokemon.dart`) is a pure pass-through; no change needed.
   - Existing data-layer tests pass because `generationId` defaults to `null`
     (nullable, no default literal) → the existing WHERE chain is unchanged
     when callers don't set it.
   - The added test in `pokemon_filter_test.dart` asserts the default is
     `isNull` and `copyWith` works on the new field independently — defensive
     and correct.
4. **DAO change is appended in the right place**. The new WHERE branch sits
   after `height`, inside the `if (filter != null)` guard, following the
   same null-check pattern as the other predicates. No reordering or refactor
   of existing logic.
5. **Spec sync**. `docs/project/02-tech-spec.md` §8.2 was updated to mirror
   the entity. The pattern matches the T-15 retroactive revision from the
   domain epic and follows the same "spec change rides in the same PR as the
   code change" convention.

### Tests cover the seam

- `test/features/pokemon/domain/entities/pokemon_filter_test.dart` — new
  defaults and `copyWith` cases.
- `test/features/pokemon/domain/usecases/find_pokemon_test.dart` — added a
  "forwards a filter combining generationId with types" case, verifying the
  use case forwards the new field verbatim.
- `test/features/pokemon/data/datasources/pokemon_dao_test.dart` — fixture
  rows now include `generationId: 2` (chikorita) so future WHERE-branch
  assertions have data to bite into; the file scaffolds the new column
  surface even where direct generation-WHERE assertions aren't yet wired in
  every group (see Suggestion S2).

**No risk identified.** The revision is small, isolated, and backwards
compatible by design.

---

## 4. Dependency Direction

### Graph of imports introduced by this PR

```
lib/core/ui/components/pokemon_card.dart
  → lib/app/theme/{app_colors, app_typography, pokemon_type_theme}
  → lib/core/pokemon/pokemon_type_id
  → lib/core/ui/components/type_badge      (sibling, OK)
  → package:cached_network_image, package:flutter/material

lib/core/ui/components/type_badge.dart
  → lib/app/theme/{app_typography, pokemon_type_theme}
  → lib/core/pokemon/pokemon_type_id
  → package:flutter/material

(stat_bar, section_header, search_field, app_bottom_sheet — all subsets of the above)

lib/features/pokemon/data/datasources/pokemon_dao.dart
  → unchanged set of imports; only the WHERE branch is added

lib/features/pokemon/domain/entities/pokemon_filter.dart
  → unchanged imports; one field added
```

### Cycle check

- `core/ui` → `app/theme` → `core/pokemon`. **Acyclic.**
- `app/theme` does NOT depend on `core/ui` (verified by grep). **Acyclic.**
- `features/pokemon/domain` does NOT depend on `core/ui`. **Acyclic.**
- The PR adds no new edge that closes a cycle.

### Pre-existing observation (not a PR1 regression)

The domain use cases under `lib/features/pokemon/domain/usecases/` import
`package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart`
to construct their Riverpod providers (e.g., `ref.watch(pokemonRepositoryProvider)`).
This is a domain-on-data import that exists in all five use case files and
was introduced by the domain epic (commit `14da3a7`), not by this PR.

**Status**: pre-existing, **not introduced by PR1**, and tracked in prior
review reports. PR1 introduces no new violations of this kind. The domain
use case ring still depends on `PokemonRepository` *interface* for its
business logic; only the Riverpod wiring touches the concrete provider, which
is a Riverpod-DI concession the team has already accepted. Flagging only so
the team carries it forward when scoring this PR's dependency hygiene
("no new violations; the existing domain→data wiring remains").

### PR1 verdict

**No new direction violations.** The new DS subtree imports cleanly downward.

---

## 5. Package / Subtree Structure

This is a single-package Flutter app — no Pub workspaces. Treating
`lib/core/ui/` as a logical "package":

- [x] **Single responsibility**: design-system primitives. Six components,
      each one widget per file, each one clear concern.
- [x] **Test directory mirrors structure**:
      `test/core/ui/components/{<name>_test.dart, goldens/<name>*.png}`.
- [x] **No grab-bag risk**: each file is named for the one component it
      exports.
- [x] **No unnecessary dependencies**: `cached_network_image` is the only
      new direct dep, justified by RF-01 imagery + offline-cached artwork.
      `pubspec.yaml` adds it at `^3.4.1` and `pubspec.lock` (per the plan's
      analyzer-9 pin guardrail) should be verified before merge — the plan
      requires `dart pub deps --style=tree | grep -i analyzer` to confirm no
      drift to `analyzer ^10`. Out of architectural scope, but flagging so
      the toolchain memory is honored.
- [x] **Const constructors used**: every component is `const` where
      possible (`const PokemonCard({...})`, `const TypeBadge({...})`, etc.).
- [x] **`super.key` pattern**: every public component uses
      `super.key` (no manual key forwarding).
- [x] **Doc comments on public API**: every public class, enum, and
      parameter carries a `///` doc comment referencing the relevant RF/RN.
- [x] **Lint guard exists**: `test/core/ui/import_boundary_test.dart`
      mechanically enforces the boundary.

### One minor structural note (no action required for PR1)

The plan's target structure (`lib/core/ui/` subtree) anticipates a sibling
`lib/core/ui/states/` directory in PR4. Today, only `components/` exists.
This is the YAGNI cut the plan called for. No premature `barrel.dart`
exports, no empty placeholder files — clean.

---

## 6. State Management

**Not applicable to PR1.** The DS components are pure `StatelessWidget`s
with no Riverpod imports, no Bloc, no `ChangeNotifier`. State will land in
PR2 (`PokemonListViewModel`) and PR3 (`PokemonDetailViewModel`). The DS's
stateless shape is what *enables* clean state-management hosting in those
PRs — every widget takes its inputs via constructor parameters and emits
events via `VoidCallback`/`ValueChanged<T>`. Reviewed and confirmed.

---

## 7. Consistency with the Epic Plan

Spot-checked PR1 against the plan's PR1 acceptance criteria
(`docs/plan/2026-05-26-feat-presentation-layer-plan.md` lines 432–457):

| AC                                                                       | Status |
| ------------------------------------------------------------------------ | ------ |
| All 6 DS components implemented                                          | Yes    |
| Type colors via `PokemonTypeTheme`; zero `Color(0xFF…)` literals in DS   | Yes — verified by grep across `lib/core/ui/components/*.dart` |
| Components take primitive params; no `features/pokemon/domain/` imports  | Yes    |
| Lint guard for `lib/core/ui/**` → `package:pokedex/features/**`          | Yes — `test/core/ui/import_boundary_test.dart` |
| Golden test per component, self-baselined under `goldens/`               | Yes — 10 PNGs present, plus parameter-variation tests |
| Parameter variation widget tests (TypeBadge × 18, StatBar × 4)           | Yes — present in the test files |
| `PokemonFilter.generationId` added; DAO WHERE branch added               | Yes    |
| Tech Spec §8.2 updated for `PokemonFilter`                                | Yes — diff includes the §8.2 snippet update |
| All existing tests stay green (optional null field)                       | Yes — by construction (nullable, no default) |
| Commit hygiene: split `refactor(domain)` from `feat(ui)`                  | Pending — PR not yet committed. The changes are staged in the working tree. Honor this when finalizing commits. |
| PR description links Figma screenshots                                    | Pending — check at PR creation time. |

The two pending items are PR-process concerns, not architecture concerns.

---

## 8. Verdict

**Ready to merge from an architecture standpoint.**

The PR is small, layered correctly, dependency-acyclic, and consistent with
the epic plan. The Design System earns its `lib/core/ui/` placement; the
retroactive domain revision is the minimum-surface change it claims to be.
The CI-enforced import boundary is the right shape for the problem.

| Category               | Count |
| ---------------------- | ----- |
| Critical               | 0     |
| Important              | 0     |
| Suggestions            | 3     |

---

## Suggestions (non-blocking)

### S1 — Forward-document the `app/` ↔ `core/` relationship

The current chain `core/ui → app/theme → core/pokemon` is acyclic and
correct, but the directional reasoning isn't captured anywhere outside this
review and the plan. A one-paragraph note at the top of `lib/core/ui/`
(e.g., a `README.md` or a doc comment block in a future `barrel.dart`) would
prevent a future contributor from "fixing" the perceived oddity of `core/`
importing `app/theme/` by inverting it.

**Action**: optional doc note in `lib/core/ui/` or `lib/app/theme/` calling
out the convention. Not required for this PR; nice for PR2's adapter
widgets which will reuse the same chain.

### S2 — DAO test direct coverage for the new `generationId` WHERE branch

The `pokemon_dao_test.dart` fixtures now include rows with non-default
generations (e.g., chikorita with `generationId: 2`), but the diff did not
add a dedicated test case that constructs a `PokemonFilter(generationId: 1)`
(or `generationId: 5`) and asserts the row count. The plan's acceptance
criteria call for "Add tests covering the new WHERE branch" (PR1 plan,
`docs/plan/...:370`).

A two-line case in the `'filters'` group of `pokemon_dao_test.dart`:

```dart
test('by generationId narrows to matching generation', () async {
  expect(await ids(filter: const PokemonFilter(generationId: 2)), [152]);
  expect(await ids(filter: const PokemonFilter(generationId: 5)), isEmpty);
});
```

would close the loop and prevent regression if someone accidentally drops
the WHERE branch in a future refactor.

**Action**: add the direct WHERE-branch test case. Falls under PR1 ACs;
worth catching before merge.

### S3 — Capture the toolchain check for `cached_network_image`

The plan calls for verifying that `cached_network_image ^3.4.1` does not
pull `analyzer ^10` or `^12` transitively
(`dart pub deps --style=tree | grep -i analyzer`) before pinning. This is a
toolchain concern (memory: `project_analyzer9-toolchain`), not an
architecture concern, but if the dep does pull a newer analyzer it will
silently slide the freezed/riverpod codegen onto -dev prereleases — which
*is* an architectural footgun (codegen instability propagates everywhere).

**Action**: run the dep check before merging PR1. If the result is clean,
the current caret pin is fine. If not, pin exact with a comment matching
the existing drift/freezed pin notes.

---

## References

- Plan: `docs/plan/2026-05-26-feat-presentation-layer-plan.md`
- Brainstorm: `docs/brainstorm/2026-05-26-presentation-layer-brainstorm-doc.md`
- Tech Spec: `docs/project/02-tech-spec.md` (§5 state, §8 entities, §10 theme)
- Domain epic plan (for revision-pattern reference):
  `docs/plan/2026-05-26-feat-domain-layer-plan.md`
- Memory: `project_git-flow`, `project_analyzer9-toolchain`,
  `feedback_review-reports-committed`
