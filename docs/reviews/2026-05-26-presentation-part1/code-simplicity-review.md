---
title: "Code Simplicity / YAGNI Review — feature/presentation-part1 (T-18 Design System + domain revision)"
date: 2026-05-26
scope: "lib/core/ui/components/ (6 DS widgets), lib/features/pokemon/domain/entities/pokemon_filter.dart, lib/features/pokemon/data/datasources/pokemon_dao.dart, lib/app/theme/app_colors.dart, plus all corresponding tests"
reviewer: claude-sonnet-4-6 (simplicity agent)
---

## Simplification Analysis

### Core Purpose

This PR has two cohesive deliverables:

1. **Domain revision** — add `int? generationId` to `PokemonFilter` and wire the corresponding WHERE predicate in `PokemonDao._summaryQuery`. This closes the YAGNI finding from the domain-layer simplicity review, which called out the then-dangling `generationId` parameter on `PokemonLocalDataSource`.

2. **Design System kit** — six stateless, primitive-param widgets (`TypeBadge`, `PokemonCard`, `StatBar`, `SectionHeader`, `SearchField`, `AppBottomSheet`) under `lib/core/ui/components/`, plus a CI import-boundary guard. A `textNumber` color token and a corrected `backgroundModal` scrim are also committed as a preparatory theme fix.

---

### Unnecessary Complexity Found

#### 1. `_BadgeMetrics` value class in `type_badge.dart` — private struct for two constants

**File:** `lib/core/ui/components/type_badge.dart` lines 78–88

`_BadgeMetrics` is a private class holding three immutable `const` fields (`padding`, `fontSize`, `radius`). It is only instantiated twice: once per `TypeBadgeSize` case in `_metricsFor`. Because `_metricsFor` is itself called from a single call site in `build`, and both instances are `const`, this adds a named type to communicate what a record or a simple switch expression already communicates. The plan spec (`type_badge.dart`: "TypeBadgeSize → two sizing presets") does not call for a named metrics struct.

**Why it is unnecessary:** The three fields map 1:1 to the destructuring that `build` does (`metrics.padding`, `metrics.fontSize`, `metrics.radius`). An anonymous record or inline switch achieves the same legibility with zero new type surface.

**Suggested simplification:**

```dart
// Replace _BadgeMetrics and _metricsFor with:
final (padding, fontSize, radius) = switch (size) {
  TypeBadgeSize.small  => (const EdgeInsets.symmetric(horizontal: 8, vertical: 2),  10.0, 3.0),
  TypeBadgeSize.medium => (const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 12.0, 4.0),
};
```

Removes the 12-line `_BadgeMetrics` class and the 12-line `_metricsFor` method. Net: −~22 LOC.

---

#### 2. `_CardImage` and `_ImagePlaceholder` split in `pokemon_card.dart` — two classes for four lines of logic

**File:** `lib/core/ui/components/pokemon_card.dart` lines 112–137

`_CardImage` is a private `StatelessWidget` whose entire `build` method is: check `imageUrl.isEmpty`; if so return `_ImagePlaceholder()`; otherwise return `CachedNetworkImage(...)`. `_ImagePlaceholder` renders a single `Center(child: Icon(...))`.

`_CardImage.build` is called from exactly one `SizedBox` inside `PokemonCard.build`. Neither class is referenced anywhere else in the codebase. The plan says "broken-image placeholder" as a behavior requirement, not as an architectural boundary.

**Why it is unnecessary:** The two helpers fragment three logical lines into two widget classes, each with a constructor and a `build` override. Inlining them keeps the branching logic visible in `PokemonCard.build` without scrolling to a separate class.

**Suggested simplification:** Replace the `SizedBox` child in `PokemonCard.build` with:

```dart
SizedBox(
  width: 72,
  height: 72,
  child: imageUrl.isEmpty
      ? const Center(child: Icon(Icons.broken_image, color: AppColors.textWhite, size: 36))
      : CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) =>
              const Center(child: Icon(Icons.broken_image, color: AppColors.textWhite, size: 36)),
        ),
),
```

Removes the two private classes (~25 LOC). The icon is repeated once (two call sites), but a named constant or a helper function with a body smaller than the class overhead achieves DRY if preferred:

```dart
static const Widget _brokenImage =
    Center(child: Icon(Icons.broken_image, color: AppColors.textWhite, size: 36));
```

Net removal either way: ~20–25 LOC.

**Counter-argument acknowledged:** Separate classes make the golden test target (`find.byType(_CardImage)`) more precise. However, the card tests already use `find.byIcon(Icons.broken_image)` and `find.byType(PokemonCard)`, so the test surface does not depend on the class boundary.

---

#### 3. `PokemonCard._capitalize` duplicates `TypeBadge._labelFor`

**Files:** `lib/core/ui/components/pokemon_card.dart` line 108; `lib/core/ui/components/type_badge.dart` line 72

Both widgets implement the same title-casing operation via the same two-expression idiom:

```dart
// pokemon_card.dart
'${value[0].toUpperCase()}${value.substring(1)}'

// type_badge.dart
'${name[0].toUpperCase()}${name.substring(1)}'
```

The implementations are character-for-character identical except for the variable name. They live in two sibling files under the same directory.

**Why it matters:** This is a copy-paste duplication of a non-trivial edge (an empty-string guard exists in `_capitalize` on the card but is absent on `_labelFor` in `TypeBadge` — the latter assumes the enum `name` is never empty, which is correct but inconsistent). Two diverging code paths for the same operation mean a future change (e.g., supporting Unicode title-casing) must be made in two places.

**Suggested simplification:** Extract to a package-private helper in `lib/core/ui/components/_string_utils.dart` (or a top-level private function in a shared file the two components both import). The extraction is one function, three lines. Both classes call it instead of inlining their own copy. Estimated net: −1 LOC (add 3, remove 4 across two files), but eliminates the divergence risk.

**Alternatively**, since `PokemonTypeId.name` is guaranteed non-empty (it is an enum constant), `TypeBadge._labelFor` can safely use `String.capitalize()` from a local extension or just call `_capitalize` exported from the card — either approach eliminates the duplication.

---

#### 4. `PokemonCard` name-style override uses `filterTitle` as base — semantically wrong token

**File:** `lib/core/ui/components/pokemon_card.dart` line 68

```dart
style: AppTypography.filterTitle.copyWith(
  color: AppColors.textWhite,
  fontSize: 18,
),
```

`AppTypography.filterTitle` is the style for "Filter sheet titles" (spec §10.2). Its baseline is 16 px / Bold / `textBlack`. Using it as the source for the card's Pokémon name text (18 px / Bold / `textWhite`) creates a coupling between a card widget and a sheet-typography token. If `filterTitle` is ever resized or recolored to follow a Figma sheet-spec update, `PokemonCard` silently changes too.

`AppTypography.pokemonName` exists (`fontSize: 26, w700, textBlack`) and is the semantically correct token for Pokémon names. The card uses a smaller size (18 px), so a `copyWith(fontSize: 18, color: textWhite)` from `pokemonName` is no more verbose than the current form but reads the right semantic intent.

**Suggested simplification:**

```dart
style: AppTypography.pokemonName.copyWith(fontSize: 18, color: AppColors.textWhite),
```

Zero net LOC change. Eliminates the implicit dependency on `filterTitle`.

**Note:** This is a semantic correctness issue, not a runtime bug. `pokemonNumber` in `AppTypography` uses `textBlack` but the Figma spec now has `textNumber` (`AppColors.textNumber`, added in this very PR's theme fix commit). The card renders `_formatNumber(id)` with `AppTypography.pokemonNumber` — that style should likely use `AppColors.textNumber` once the presentation layer is wired. This is a follow-up note, not a PR1 blocker (the color token is new and no downstream consumers are wired yet).

---

#### 5. `import_boundary_test.dart` — `Directory` path is relative, which breaks when tests run from a non-root cwd

**File:** `test/core/ui/import_boundary_test.dart` lines 10–12

```dart
final root = Directory('lib/core/ui');
```

The `dart test` runner is typically invoked from the project root, so this works in practice. However, if any tooling (e.g., a very-good-cli MCP wrapper invoked from a different working directory, or an IDE test runner) resolves `Directory` relative to the process cwd, the `root.existsSync()` assertion at line 13 will fail with the obscure message "expected lib/core/ui to exist for the design system" rather than a cwd-related error.

**Suggested simplification:**

```dart
// Resolve relative to this test file's location (always reliable):
final root = Directory(
  path.join(path.dirname(Platform.script.toFilePath()), '..', '..', 'lib', 'core', 'ui'),
);
// Or, more simply, rely on the project root convention already used everywhere:
final root = Directory(path.join(Directory.current.path, 'lib', 'core', 'ui'));
```

Alternatively, the test can be rewritten to not rely on `Directory` at all by using `dart:io`'s `File` with a package-root-relative path, consistent with how other test helpers in this project locate fixtures. The `reason:` message should also explain the cwd assumption so failures are diagnosable.

This is low severity — it works under all current CI invocations — but the fragility is unnecessary.

---

### Code to Remove

| File | Lines / Region | Reason | Estimated LOC |
|---|---|---|---|
| `lib/core/ui/components/type_badge.dart` | 54–88 (`_metricsFor` + `_BadgeMetrics`) | Replace with inline switch expression | −22 |
| `lib/core/ui/components/pokemon_card.dart` | 112–137 (`_CardImage` + `_ImagePlaceholder`) | Inline into `PokemonCard.build` | −20 |
| `lib/core/ui/components/pokemon_card.dart` | 108 (`_capitalize`) + `type_badge.dart` 72 (`_labelFor`) | Consolidate to one shared helper | −1 net |

**Total estimated reduction: ~40–43 LOC**

---

### Simplification Recommendations

#### 1. Inline `_BadgeMetrics` / `_metricsFor` into a switch expression in `TypeBadge.build`
- **Current:** 12-line private class + 12-line factory method for two constant tuples.
- **Proposed:** Pattern-matched record destructuring inside `build`.
- **Impact:** −22 LOC; removes an unnecessary type; the two sizing presets remain clearly labelled by the `TypeBadgeSize` case names.

#### 2. Inline `_CardImage` / `_ImagePlaceholder` into `PokemonCard.build`
- **Current:** Two private `StatelessWidget` subclasses for four lines of image-or-placeholder logic.
- **Proposed:** Conditional expression + optional `static const` icon widget inside `PokemonCard`.
- **Impact:** −20 LOC; logic is visible at the single call site; tests do not depend on the class boundaries.

#### 3. Extract the title-case helper shared between `TypeBadge` and `PokemonCard`
- **Current:** Same one-liner duplicated with a subtle difference (empty-string guard present in one, absent in the other).
- **Proposed:** A single package-private `_titleCase(String s)` function, or a `String` extension, imported by both.
- **Impact:** Eliminates divergence risk at near-zero net LOC cost.

#### 4. Fix the semantic token in `PokemonCard` name style
- **Current:** `AppTypography.filterTitle.copyWith(fontSize: 18, color: textWhite)` — borrows a sheet-typography base for a card name.
- **Proposed:** `AppTypography.pokemonName.copyWith(fontSize: 18, color: textWhite)`.
- **Impact:** Zero LOC delta; removes a silent cross-concept dependency.

#### 5. Anchor `import_boundary_test.dart`'s `Directory` to an absolute path
- **Current:** `Directory('lib/core/ui')` — relative to process cwd.
- **Proposed:** `Directory(path.join(Directory.current.path, 'lib', 'core', 'ui'))` or a `Platform.script`-relative resolution.
- **Impact:** +2 LOC; makes the failure mode diagnosable when cwd is unexpected.

---

### YAGNI Violations

None found in this PR. The domain revision (`generationId` on `PokemonFilter` + DAO WHERE branch) directly resolves the YAGNI finding from the domain-layer review, which noted that the generation-filter capability had been pre-implemented at the datasource-interface level with no call site. PR1 correctly moves `generationId` into `PokemonFilter` (where it belongs as a domain concept) and removes it from the raw interface signature — the fix lands exactly where the previous reviewer requested it.

The six DS components implement exactly what the plan specifies: no extra sizing variants, no icon parameters not yet called for, no theme-extension hooks. `AppBottomSheet.primaryAction` is nullable/optional and is exercised by the Filters sheet in PR2 — it is not speculative.

---

### Items That Are Not Simplification Targets

**`_capitalize` guard on empty string in `PokemonCard`.** The empty-string branch (`value.isEmpty ? value : ...`) is defensive but not wrong — the card's `name` parameter is a raw `String` and callers could pass an empty value in tests. Worth noting in the consolidation recommendation (item 3 above), but not a standalone issue.

**`Flexible(child: child)` in `AppBottomSheet`.** This wraps the caller's `child` in a `Flexible` so oversized content doesn't overflow a constrained sheet. The behavior is load-bearing (the sheet is rendered inside `showModalBottomSheet`, which gives a bounded height), not defensive padding.

**`const AppColors._()` / `const AppTypography._()` private constructors.** Boilerplate required for `abstract final class` in Dart to prevent instantiation. Not removable.

**`SafeArea(top: false)` in `AppBottomSheet`.** The `top: false` is intentional (drag handle must extend to the sheet edge, not indent below the status bar). A comment would make this clearer, but the behavior is not extra code.

**`Material(color: Colors.transparent) + InkWell` wrapper in `PokemonCard`.** The ink-splash ripple requires a `Material` ancestor. The `Colors.transparent` preserves the `DecoratedBox` background. This is the correct Flutter idiom; the two-widget pattern is not over-engineering.

**`onTap == null` early return in `PokemonCard`.** Avoids wrapping a non-interactive card in a `Material` + `InkWell` unnecessarily. The check is a single line; the benefit (no spurious Material ancestor for read-only uses) is real.

**Six separate component test files.** The plan mandates "one test file per component" and the AC explicitly requires it. The duplication of the `_pump` / `_pumpBadge` helper across test files is a test-side concern — slight but acceptable given the plan's one-file-per-component constraint.

---

### Final Assessment

**Total potential LOC reduction:** ~40–43 lines (all in the component files; domain changes are minimal and correct).

**Complexity score:** Low — the DS kit is lean, idiomatic Flutter, and closely tracks the plan. No premature abstractions, no speculative parameters, no unnecessary generics.

**Critical issues:** 0

**Important issues:** 1 (semantic token mismatch in `PokemonCard` name style — uses `filterTitle` as the base where `pokemonName` is semantically correct; silent cross-concept dependency introduced).

**Suggestions:** 4 (inline `_BadgeMetrics`, inline `_CardImage`/`_ImagePlaceholder`, extract shared title-case helper, anchor the boundary-test `Directory` to an absolute path).

**Recommended action:** Needs minor work. The important fix (token semantics) is a one-word change. The four suggestions reduce surface area meaningfully but are not blocking. The domain revision is well-executed and closes the prior YAGNI finding correctly.
