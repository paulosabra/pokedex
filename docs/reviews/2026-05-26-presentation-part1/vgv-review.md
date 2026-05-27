# VGV Review — `feature/presentation-part1` (PR1 of presentation epic)

**Scope reviewed**: Design System kit (6 components under `lib/core/ui/components/`), import-boundary lint guard, retroactive `PokemonFilter.generationId` extension, DAO WHERE branch, Tech Spec §8.2 update, `cached_network_image ^3.4.1` dependency, parametric widget tests + co-located goldens.

**Toolchain verification**: `dart analyze lib/core/ui test/core/ui` → No issues. `dart format --set-exit-if-changed` → no changes needed. Very Good CLI `flutter test` → all tests pass.

---

## Summary

PR1 lands cleanly. The Design System kit is faithful to its plan: pure stateless widgets, primitive parameters only, type colors routed through `PokemonTypeTheme`, zero feature-package imports, and a static lint guard that enforces the boundary in CI rather than relying on reviewer vigilance. The retroactive `PokemonFilter.generationId` change is a small, backwards-compatible field addition wired correctly through the DAO and exercised in both the data and domain test layers. Every new component has a dedicated test file with parametric widget tests AND a co-located goldens group (per plan AC), goldens are self-baselined under `test/core/ui/components/goldens/`, and the existing test suite remains green.

The codebase is in good shape and ready to merge. Findings below are mostly suggestions for the next PR in the epic — none are merge blockers. The one **Important** item is a domain-test naming/strength gap where the new `find_pokemon_test.dart` row doesn't assert the intersection it claims to forward; this is a one-line fix.

**Verdict**: Ready to merge with one optional small test improvement.

---

## Pass 1 — Regressions & Breaking Changes

| Check | Result |
| --- | --- |
| Deleted code | Only `lib/core/.gitkeep` removed (legitimately replaced by real files under `lib/core/ui/`). |
| Changed public APIs | `PokemonFilter` gains an `int? generationId` optional field — backwards compatible. No existing call site constructs `PokemonFilter(...)` outside of tests; use cases pass the entity through unchanged. |
| State management impact | N/A — no Riverpod state introduced. DS kit is pure stateless widgets. |
| Tests deleted or weakened | None. Existing `pokemon_dao_test.dart` and `find_pokemon_test.dart` are additive only. |
| Dependencies | `cached_network_image: ^3.4.1` added. Analyzer pin policy unaffected — `pubspec.lock` analyzer line unchanged. |

---

## Pass 2 — VGV Architecture & Conventions

### Layer separation — PASS

- `lib/core/ui/components/*.dart` imports only `flutter/material`, `cached_network_image`, `package:pokedex/app/theme/*`, `package:pokedex/core/pokemon/pokemon_type_id.dart`, and (in `pokemon_card.dart`) the sibling `type_badge.dart`. No `package:pokedex/features/**` import anywhere.
- The boundary is enforced by `test/core/ui/import_boundary_test.dart`, which walks `lib/core/ui/` recursively and fails the build on any `package:pokedex/features/**` import line. Convention-only rules rot; this test makes the rule load-bearing in CI.
- `PokemonTypeId` reuse from `lib/core/pokemon/` is correct — that enum already lives in `core/` precisely so theme/UI can reference it without inverting the layer rule.

### State management — N/A

This PR ships no Riverpod state. The ViewModel + Notifier work lands in PR2. Components are correctly stateless and delegate state ownership upward via callbacks (`onTap`, `onChanged`, `onSubmitted`, `primaryAction`, `titleTrailing`).

### Naming & 5-second rule — PASS

`TypeBadge`, `PokemonCard`, `StatBar`, `SectionHeader`, `SearchField`, `AppBottomSheet` all read true the moment you see the name. `TypeBadgeSize.{small, medium}` clearly indicates a sizing variant. The internal `_BadgeMetrics`, `_CardImage`, `_ImagePlaceholder` are private and named for what they do.

### Null safety & error handling — PASS

- No force-unwrap (`!`) on any nullable in component code outside `app_bottom_sheet.dart:60`, which dereferences `primaryAction!` inside an `if (primaryAction != null)` block — safe.
- `CachedNetworkImage.errorWidget` renders `_ImagePlaceholder`, covering TE-11 (missing image placeholder). `imageUrl.isEmpty` short-circuits to the placeholder before hitting the network.
- `StatBar` clamps `value / max` to `[0.0, 1.0]`, defending against out-of-range input (verified by both the "clamps a value above max" and "clamps a negative value" tests).

### Lifecycle & resource management — PASS

- No streams, controllers, timers, or subscriptions in DS components.
- `search_field_test.dart` correctly disposes the controllers it creates via `addTearDown(controller.dispose)` on both fixtures that allocate one.

### Theming convention — PASS (with one nit)

- Type colors come exclusively from `PokemonTypeTheme.styleOf(...)`. Zero `Color(0xFF...)` literals in `lib/core/ui/components/*.dart`.
- Other colors come from `AppColors` tokens (`backgroundInput`, `backgroundWhite`, `textBlack`, `textGray`, `textWhite`). Convention is tokens-direct, not `Theme.of(context).colorScheme.*` — consistent with the foundation epic's minimal `AppTheme.light` and with `AppTypography`'s direct color references. If the team later adopts `ColorScheme.primary`/`onSurface` semantics this will need a sweep, but for the MVP the direct-token pattern is the standing convention and is applied consistently.

### Linting & formatting — PASS

- `dart analyze lib/core/ui test/core/ui` → No issues found.
- `dart format --set-exit-if-changed` → 13 files, 0 changed.

---

## Pass 3 — Testing Quality

### Per-component coverage

| File | Parametric tests | Goldens | Notes |
| --- | --- | --- | --- |
| `type_badge_test.dart` | label, color, all-18-types loop, size variant | grass/fire/water small + grass medium | All 18 types iterated and asserted; size variant verified via measured `Size`. |
| `pokemon_card_test.dart` | #NNN format, capitalization, primary+secondary, placeholder, onTap | single/dual/placeholder | Tap behaviour verified by closure flip. |
| `stat_bar_test.dart` | label+value, fraction math, clamp >max, clamp <0 | 0/50/100/255 | `closeTo(128/255, 1e-9)` is appropriately tight. |
| `section_header_test.dart` | title-only, trailing tap | with-trailing | |
| `search_field_test.dart` | hint, onChanged, controller binding, onSubmitted | empty + filled | `addTearDown(controller.dispose)` on both fixtures. |
| `app_bottom_sheet_test.dart` | title+child, no-action absent, action tap, trailing tap | full | |
| `import_boundary_test.dart` | scans `lib/core/ui/**` for `package:pokedex/features/` imports | n/a | Recursive `Directory.listSync(recursive: true)`. |

### Test quality — PASS with one **Important** gap

- No tautologies (`expect(true, isTrue)`), no over-verification of mocks, no behaviour-free "does not throw" tests.
- Fraction math and clamps are asserted on the actual computed `widthFactor`, not on render-tree fluff.
- Interactions test outcomes (closure mutation, controller text, captured `submitted`) rather than framework rebuild behaviour.

**Gap**: `find_pokemon_test.dart`'s new "forwards a filter combining generationId with types" test verifies that the use case passes a filter through unchanged, but the test name promises an *intersection* assertion. The mock returns a static `Pokemon` list regardless of input — the test only proves forwarding, not the intersection itself. The DAO test does cover real intersection (`types + height + generationId`), so the data layer is well-covered; the domain test is just labeled aspirationally. See Important #1 for the fix.

### Domain-side coverage of new field — PASS

- `pokemon_filter_test.dart` asserts defaults include `generationId: null` and that `copyWith(generationId: ...)` preserves other fields.
- `pokemon_dao_test.dart` adds two real-row tests: per-generation match + a tri-axis intersection (`types + height + generationId`) returning the single expected row.

### Goldens — PASS

All 14 goldens self-baselined under `test/core/ui/components/goldens/`. The plan AC required co-location in the same `_test.dart` file (not a separate `_golden_test.dart`); each component complies with a `group('goldens', () { ... })` block.

---

## Pass 4 — Simplicity & YAGNI Audit

| Concern | Verdict |
| --- | --- |
| Premature abstractions | None. No base class, no extension methods on widgets, no mixin reuse. `_BadgeMetrics` is a private inline value object used in exactly one place — earns its keep because it bundles three related sizing values per variant. |
| Unused parameters / config | None. Every parameter is exercised in tests. |
| Commented-out code | None. |
| Generic widgets / parameterized "uber-components" | None. Each DS widget does one thing. |
| Code-gen sprawl | `PokemonFilter` regen via `build_runner` produced the expected `generationId` references in `pokemon_filter.freezed.dart`. Clean. |
| File count | 6 component files for 6 distinct visual concepts. Right-sized. |

**Estimated lines removable**: 0. Already minimal.

---

## Findings

### Critical — Must Fix Before Merge

None.

### Important — Should Fix

1. **`test/features/pokemon/domain/usecases/find_pokemon_test.dart:66-99`** — The test name "forwards a filter combining generationId with types" promises an intersection assertion, but the mocked repository returns a static list regardless of input. The test only verifies pass-through.
   - Why: Misleading test names erode confidence in the suite and create false coverage. The DAO test exercises the real intersection, so the domain test should either be **renamed** to "forwards a filter with generationId set" (truthful pass-through verification) or **strengthened** to assert the captured filter argument equals the input:
     ```dart
     final captured = verify(
       () => repository.findPokemon(
         sort: SortCriteria.numberAsc,
         filter: captureAny(named: 'filter'),
       ),
     ).captured.single as PokemonFilter;
     expect(captured.generationId, 2);
     expect(captured.types, {PokemonTypeId.grass});
     ```
   - Fix: Either rename the test to match what it actually verifies, or add the `captureAny` assertion above.

### Suggestions — Nice to Have

1. **`lib/core/ui/components/type_badge.dart:72-75`** (`_labelFor`) — Title-casing the enum name (`grass` → `Grass`) hardcodes English labels and will not survive i18n. For PR1 this is acceptable (English MVP per PRD), but when the localization story lands this method becomes the single migration point.
   - Suggestion: Add a `// TODO(i18n):` comment so the migration point is discoverable, or extract a `typeLabel(PokemonTypeId)` helper in `core/pokemon/` ready for an `AppLocalizations` swap later.

2. **`lib/core/ui/components/pokemon_card.dart:64, 69, 70, 75, 86`** — Bare numeric literals for the card name `fontSize: 18`, `Wrap` `spacing/runSpacing: 4`, image cell `width/height: 72`, and corner radius `10`. Other token-driven files in the codebase use `AppTypography.*` / `AppColors.*` exclusively.
   - Suggestion: Either add `AppTypography.pokemonCardName` (size 18 variant on `filterTitle`) or accept these as Figma-driven layout primitives that don't deserve a token. Either way, the file reads slightly inconsistently today.

3. **`lib/core/ui/components/stat_bar.dart:39, 50`** — The `SizedBox(width: 56)` label column and `SizedBox(width: 32)` value column embed layout magic numbers. They are clearly Figma-driven; a brief `// Figma: …` comment would speed future reconciliation.

4. **`docs/project/02-tech-spec.md:475`** — The new `generationId` comment reads `// RN-15 (PR1 revision)`, but RN-15 in the PRD is about MVP data-completeness scoping ("Gen I is guaranteed complete; other generations degrade gracefully") — not about the existence of a generation filter axis. The cumulative-filters rule is RN-08, and the generation use case is UC-05.
   - Suggestion: Change to `// UC-05 / RN-08 (PR1 revision)` for accuracy.

5. **`lib/core/ui/components/type_badge.dart:78-88`** — `_BadgeMetrics` is a private inline value object. With only two variants and three fields, a `switch` returning a record (`({EdgeInsets padding, double fontSize, double radius})`) inline would save the class definition entirely. Minor; current form also fine.

6. **`test/core/ui/import_boundary_test.dart:11`** — `Directory('lib/core/ui')` is relative to the test runner's CWD. The very-good-cli runner runs from the project root, so it works today, but the assumption is implicit. Consider documenting the CWD assumption in a `// expects CWD = project root` comment, or resolve from `Platform.script` to be CWD-agnostic.

---

## Simplicity Assessment

- **Lines that could be removed**: 0.
- **Unnecessary abstractions**: 0. (`_BadgeMetrics` is borderline — see Suggestion #5 — but not a violation.)
- **YAGNI violations**: 0. Every parameter, every helper, every test maps to a concrete use case in the plan.
- **Complexity verdict**: **Already minimal**.

---

## Testing Assessment

- **New code with tests**: All 6 DS components covered + import-boundary test + 3 domain-side test deltas.
- **Test quality**: Meaningful. One naming/strength gap (Important #1).
- **State management test coverage**: N/A (no state introduced).
- **UI component test coverage**: Complete. Parametric tests + co-located goldens per AC.
- **Goldens**: 14 self-baselined goldens, all current.

---

## AC Checklist — PR1

| AC | Status |
| --- | --- |
| All 6 DS components implemented from Figma `get_design_context` | PASS |
| Type colors driven by `PokemonTypeTheme` (RN-04); zero hardcoded `Color(0xFF...)` literals in component files | PASS |
| Components take primitive params; no imports from `features/pokemon/domain/` | PASS |
| Lint guard added (`import_boundary_test.dart`) | PASS |
| Golden test per component, self-baselined under `test/core/ui/components/goldens/`, co-located with widget tests | PASS |
| Parameter variation widget tests (TypeBadge × 18 types, StatBar × 4 buckets) | PASS |
| `PokemonFilter.generationId` added; codegen clean; DAO WHERE branch added | PASS |
| Tech Spec §8.2 updated for `PokemonFilter` | PASS (minor comment-accuracy nit — Suggestion #4) |
| All existing tests stay green | PASS |
| Commit hygiene: at least one `refactor(domain): …` + one or more `feat(ui): …` | DEFERRED to commit phase — verify before push |
| PR description links Figma screenshots for Badge, Text Field, StatBar nodes | DEFERRED to PR creation |
