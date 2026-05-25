# Architecture Review — PR3 (T-04: Theme + Tokens + `PokemonTypeTheme`)

- **Branch:** `feature/foundation-part3` → `epic/foundation`
- **Scope reviewed:** `lib/core/pokemon/pokemon_type_id.dart`, `lib/app/theme/{app_colors,app_typography,app_theme,pokemon_type_theme}.dart`, `lib/app/app.dart`, and the accompanying tests.
- **Standards:** single-package feature-first Clean Architecture; `core/` is a transversal leaf; `app/` is app-level wiring/theme; presentation must never be a dependency of domain. Sources of truth: Tech Spec §2 (dependency rule), §3 (layers), §8.2 (entities), §10 (tokens); Plan "PR3 — Theme".

---

## Dependency Direction & Layer Separation

The full intra-package import graph for the changed files (verified with `grep -rn "^import 'package:pokedex"`):

```
main.dart            → app/app.dart
app/app.dart         → app/theme/app_theme.dart
app/theme/app_theme  → app/theme/{app_colors, app_typography}
app/theme/app_typography → app/theme/app_colors
app/theme/pokemon_type_theme → core/pokemon/pokemon_type_id   ← the only cross-area edge
core/pokemon/pokemon_type_id → (nothing)
```

- **`core/` is a clean leaf.** `grep -rn "import 'package:pokedex/app\|import 'package:pokedex/features" lib/core/` returns nothing. `pokemon_type_id.dart` imports nothing at all (not even Flutter) — it is pure Dart, which is exactly what a `core/` leaf consumable by both `app/theme` and a future `features/*/domain` must be.
- **The one cross-area edge points downward** (`app/theme` → `core/pokemon`), the allowed direction. `core/` never imports `app/` or `features/`, so no cycle is possible. Consistent with Tech Spec §2 ("as setas de dependência apontam sempre para o domínio") and §3's "código realmente transversal … vive em `core/`."
- **No circular dependencies**, no reverse edges, no duplication of shared code.

**Verdict for this section: clean. Zero layer-separation violations.**

---

## Findings

### Critical
None.

### Important
None.

### Minor

1. **`core/pokemon/` is the right call, but name the boundary it implies (`core/pokemon/` ≠ domain entities).**
   `lib/core/pokemon/pokemon_type_id.dart` is sound. The enum is a stable, dependency-free value type with no Flutter import, so it is genuinely transversal — the textbook reason to put something in `core/`. Placing it here instead of `app/theme/` correctly avoids the future `domain → presentation` inversion that would occur if T-14's `Pokemon` entity (`docs/project/02-tech-spec.md:430`) had to import from `app/theme/`. The placement is well-reasoned and the doc comment in the file (`lib/core/pokemon/pokemon_type_id.dart:3-4`) captures the rationale.
   The risk to flag now: `core/pokemon/` must stay reserved for **transversal, dependency-free** pokemon primitives (ids, enums, small value objects). When the richer `Pokemon`/`PokemonDetail` *entity* (Freezed, business semantics, §8.2) arrives in T-14, it belongs in `features/pokemon_list/domain/`, **not** alongside this enum in `core/pokemon/`. Keeping an entity in `core/` would dissolve the feature-first boundary and let every feature reach domain models transversally. Recommendation: in T-14 the enum can stay in `core/pokemon/` (entities import *down* into it — clean) or migrate into the domain barrel; do **not** let `core/pokemon/` accrete domain entities. A guard-rail for the future PR, not a defect in PR3. (Tech Spec §3, §8.2.)

2. **`PokemonTypeStyle` as a `typedef` record (`lib/app/theme/pokemon_type_theme.dart:9`) — the record→class migration for the icon slot is set up correctly, but the record offers no construction control.**
   The plan's migration path (Plan L294–298) is to promote the record to a class in T-18 carrying the icon, "so call sites keep using `.color` / `.backgroundColor`." Since all access is via named fields (`.color`, `.backgroundColor`) and the only construction site is inside `styleOf` (`pokemon_type_theme.dart:50-56`), the migration to a `final class` will be source-compatible at call sites — the design is right. Minor caveat: a record typedef has no private constructor, so any code can synthesize a `(color: …, backgroundColor: …)` literal and pass it as a `PokemonTypeStyle`, bypassing `styleOf`. Today the only caller is the theme's own test, so exposure is nil. When the type gains an icon and validation in T-18, prefer a `final class` with a private/factory constructor so `styleOf` stays the single source. No change required now. (RN-04, Tech Spec §10.3, Plan L294–298.)

3. **`AppTheme.light` maps §10.2 styles to Material text roles, but widgets are also told to reference `AppTypography` directly — pick one canonical path before screen work.**
   `lib/app/theme/app_theme.dart:17-24` wires six §10.2 styles onto Material `TextTheme` roles, while the doc comment (`app_theme.dart:11-12`) says "widgets may also reference `AppTypography` styles directly." Both are defensible, but two access paths to the same tokens invite drift once T-18 builds real screens (one screen reads `Theme.of(context).textTheme.titleMedium`, another reads `AppTypography.filterTitle`). A presentation-convention question, not a layering violation. Recommendation: choose one canonical access path for T-18 screen code and record it in the UI/theme convention. (Tech Spec §10.2.)

### Suggestion

4. **The §10.3 "altura" (height-filter) palette and per-type *icon* are correctly out of scope for PR3 — keep them out of `core/`.**
   Tech Spec §10.3 bundles a height-category palette (Short/Medium/Tall) alongside the type palette. PR3 rightly implements only the type colors (RN-04) and derives the 16 unspecified backgrounds via `Color.lerp(color, white, 0.5)` with an honest comment (`lib/app/theme/pokemon_type_theme.dart:46-49`). When the height palette and the per-type icon arrive (filters feature / T-18), they are presentation concerns and belong in `app/theme/` (icons) or the filters feature, **not** `core/pokemon/`. PR3 sets this up well; this is a marker so the leaf does not become a dumping ground.

5. **Consider a thin `app/theme/theme.dart` barrel before T-18.**
   Screen code in T-18 will import several theme files. A single barrel (`export 'app_colors.dart'; export 'app_typography.dart'; …`) keeps presentation imports stable and one-directional and avoids each widget reaching into individual theme files. Purely ergonomic; no architectural impact.

---

## Package / Structure Checks

- **Single responsibility per file:** `app_colors` (color tokens), `app_typography` (text styles), `app_theme` (ThemeData assembly), `pokemon_type_theme` (per-type resolution) — clean separation, no grab-bag. PASS.
- **Composition root (`lib/app/app.dart`):** correct. `PokedexApp` is a `StatelessWidget` building `MaterialApp(theme: AppTheme.light, home: const Scaffold())`; `main.dart` only calls `runApp`. Theme is injected at the root (global, satisfying T-04 acceptance). `ProviderScope` is intentionally deferred to T-17 per the plan — no premature wiring. PASS.
- **Leaf/independence:** `core/pokemon` and `core/error` are independent leaves; `app/theme` depends only down into `core/`. PASS.
- **Tests beside source** under `test/app/theme/` and `test/core/`. The color-by-type widget test (`test/app/theme/pokemon_type_theme_test.dart`) imports only `app/theme` + `core/pokemon`, mirroring the production dependency direction (no test-only back-edges). PASS.
- **Tokens centralized in `app/theme/` per §10.** PASS. `SF Pro Display` fonts are declared in `pubspec.yaml` and present under `assets/fonts/`, so the typography references resolve.
- **Lints:** package inherits `very_good_analysis`; theme holders consistently use `abstract final class … _();` (non-instantiable static holders). PASS.

---

## Deviation Assessment (the key decision)

The deliberate deviation — `PokemonTypeId` in `core/pokemon/` rather than under domain per §8.2 — is **architecturally sound and the correct choice for the foundation phase**:

- It honors the non-negotiable dependency rule. The alternative (enum in `app/theme/`) would force T-14's domain entity `Pokemon { List<PokemonTypeId> types }` (`docs/project/02-tech-spec.md:430`) to import from presentation — a real inversion.
- `core/` is the defined home for transversal, framework-agnostic code, and this enum qualifies (zero imports, pure Dart). Both `app/theme` (now) and `features/*/domain` (T-14) may depend on it from above with no cycle.
- It is a documented, intentional departure from §8.2's *literal* placement, recorded in the file and the plan (L280–285, L414–415). §8.2 lists the enum next to entities for narrative convenience; nothing in §2/§3 requires a transversal enum to physically live in a feature's domain folder, and no migration is forced on T-14.

Caveat carried forward as Minor #1: keep `core/pokemon/` for primitives only; do not let it absorb domain entities later.

---

## Verdict

**Architecture is clean — ready to merge.** Zero critical/important issues; the `PokemonTypeId → core/` decision is correct and well-documented, dependency direction is one-way with `core/` a verified leaf, the composition root is wired correctly, and the record→class icon migration is set up to be source-compatible for T-18. The minor items are forward-looking guard-rails for T-14/T-18, not blockers.
