# Architecture Review — Foundation PR1 (T-01 + T-02 + T-05)

- **Branch:** `feature/foundation-part1` → `epic/foundation`
- **Scope:** Scaffold, deps/codegen/lints, CI. Skeleton only — no data/domain/presentation code.
- **Architecture under review:** single-package, feature-first Clean Architecture (`app/` + `core/` + `features/`). Reviewed as such; no monorepo recommendation made.
- **Reviewed (hand-authored):** `lib/main.dart`, `lib/app/app.dart`, the `lib/` tree, `pubspec.yaml`, `.github/workflows/ci.yaml`. Cross-checked `analysis_options.yaml`, `.gitignore`, `pubspec.lock`, `README.md`, `test/app/app_boot_test.dart`. Generated platform folders (`android/`, `ios/`, `web/`, `macos/`, `.metadata`, `.idea/`) ignored per instructions.

---

## Critical

None. There are no layer-separation, dependency-direction, or composition-root defects in this PR. The skeleton is architecturally sound for the data/domain/UI layers to build on.

---

## Important

None. Nothing here will "bite later" at the architectural level. The two items most likely to cause downstream friction — the `PokemonTypeId` placement and the missing `core/` substructure — are both deliberate, documented decisions that are actually the *correct* architectural calls (see Minor and Suggestion). I record the consistency observations below as Minor/Suggestion rather than Important because none of them constrains a later layer or sets up a boundary violation.

---

## Minor

### M-1 — `analysis_options.yaml` exclude globs diverge from the plan (2 of 4)
`analysis_options.yaml` excludes only:
```yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```
The plan (`docs/plan/2026-05-24-chore-foundation-setup-plan.md:155-156`) specifies excluding generated globs **1:1 with `.gitignore`**, listing four: `**/*.g.dart`, `**/*.freezed.dart`, `**/*.mocks.dart`, `**/*.config.dart`.

This is not an architecture defect and not blocking for PR1 (mocktail generates no files; there is no `injectable`/`config.dart` consumer). But the "1:1 with `.gitignore`" invariant the plan sets up is *already* not holding, and `.gitignore` (`.gitignore:47-49`) itself only ignores `*.g.dart` and `*.freezed.dart` — it omits `*.mocks.dart` too. Worth aligning both files now (or consciously dropping `*.mocks.dart`/`*.config.dart` since the toolchain uses `mocktail`, which is codegen-free, and no DI-config generator is planned) so a future reviewer doesn't treat the drift as a regression. `file: analysis_options.yaml`, `file: .gitignore:47-49`.

### M-2 — `app/theme/` not yet present (expected — PR3)
The plan's target tree (`...plan.md:65-75`) shows `lib/app/theme/`. It is absent now. This is correct: T-04/theme lands in PR3. `lib/app/` currently holds only `app.dart`, which sits properly at the composition root. No action — recorded only to confirm the absence is intentional, not an omission. `file: lib/app/`.

---

## Suggestion

### S-1 — Composition root is clean; keep `ProviderScope` out until it has a consumer
`lib/main.dart:4-6` (`runApp(const PokedexApp())`) and `lib/app/app.dart` (`PokedexApp` → `MaterialApp`) form a textbook composition root: `main` is the entrypoint, `app/` owns app-level wiring, and the widget is `const`. The plan defers `ProviderScope` to T-17 (`...plan.md:72`). This is the right call — adding `ProviderScope` now, with zero providers, would be premature wiring. When it lands, place it in `app/` wrapping `PokedexApp` (or just inside it), keeping `main.dart` a one-liner. No change needed now.

### S-2 — `PokemonTypeId` → `core/` is the correct dependency-direction decision
The plan places the shared `PokemonTypeId` enum in `core/pokemon/` rather than `app/theme/` (`...plan.md:73`, `:271-284`, `:414-416`) precisely to avoid a domain→presentation inversion when T-14's domain layer consumes it. This is the architecturally correct resolution: `core/` is a leaf that both `app/theme` (PR3) and `features/*/domain` (T-14) may depend on, so the enum flows *downward* to both. Endorsed. The PR does not introduce the enum yet, so nothing to verify in code — but the decision is sound and should be honored as written when PR3 lands.

### S-3 — `features/` and `core/` as `.gitkeep` placeholders is consistent with YAGNI scaffolding
`lib/core/.gitkeep` and `lib/features/.gitkeep` are empty placeholders; `core/network`, `core/database`, `core/utils`, `core/widgets`, and per-feature `domain/`+`data/`+`presentation/` trees are deferred to the slices that need them (`...plan.md:77-80`). This matches the documented YAGNI-on-scaffolding decision and is the right level of restraint for a foundation PR. No premature directories were created. Confirmed clean. `file: lib/core/.gitkeep`, `file: lib/features/.gitkeep`.

### S-4 — Dependency set respects layer direction; no data-layer deps leaked upward
`pubspec.yaml:10-31` declares only state/codegen/lint/test deps (`flutter_riverpod`, `riverpod_annotation`/`_generator`, `freezed`/`_annotation`, `json_*`, `very_good_analysis`, `mocktail`, `build_runner`). No `dio`, `drift`, `go_router`, or `connectivity_plus` — those land with their consuming layers (`...plan.md:120-126`). At the package level this keeps the data layer's transitive deps out of the foundation, so nothing in `app/`/`core/` can accidentally take a data-layer dependency before that layer exists. The exact pins on `freezed: 3.2.5` and `riverpod_generator: 4.0.3` (`pubspec.yaml:23-30`) correctly lock the analyzer-9/stable-codegen line. Good.

### S-5 — CI codegen-before-analyze ordering protects the layered build going forward
`.github/workflows/ci.yaml:31-46` orders `pub get` → `build_runner build` → format → `flutter analyze --fatal-infos --fatal-warnings` → `flutter test --coverage`. Generated code is git-ignored (`.gitignore:47-49`), so regenerating before analyze is structurally required once T-08 introduces real codegen. Ordering this now — while it's a no-op — means the gate is already correct when DTOs/entities/DI arrive. `pubspec.lock` is committed (verified: not git-ignored), pinning resolution against the floating `stable` channel. Architecturally this is the right foundation for reproducible cross-layer builds. Note the boot test (`test/app/app_boot_test.dart`) asserts real composition (`find.byType(MaterialApp)`), not a tautology — a genuine composition guard.

---

## Dependency Direction (summary)

- **Layer-separation violations:** 0. No file imports across a forbidden boundary. `lib/main.dart` imports only `package:flutter/material.dart` + `package:pokedex/app/app.dart`; `lib/app/app.dart` imports only `package:flutter/material.dart`. Both clean.
- **Circular dependencies:** none possible — only one source file pair exists, flowing `main → app`.
- **Reverse dependencies:** none. `core/` and `features/` are empty; no upward import can exist yet.
- **Package-level direction:** clean — no data-layer package deps present to point the wrong way (S-4).

## Package / Structure Checklist

- [x] Dependency manifest present, correct name (`pokedex`), `publish_to: none` (app, not package) — `pubspec.yaml:1-3`.
- [x] Lint config follows project standard (`very_good_analysis`) — `analysis_options.yaml:1`.
- [x] Test directory exists with a real composition test — `test/app/app_boot_test.dart`.
- [x] Single clear responsibility per directory; `app/` = wiring, `core/` = shared leaves, `features/` = feature trees.
- [x] UI/business-logic separation preserved by the feature-first layout (not yet exercised — no features).
- [x] No unnecessary cross-layer dependencies.
- [~] Generated-globs exclusion not yet 1:1 across `analysis_options.yaml` / `.gitignore` (M-1).

---

## Verdict

**Architecture is clean — ready to merge.** Zero critical/important issues; one minor glob-alignment nit (M-1) worth tidying but non-blocking, and four suggestions that confirm the deliberate decisions are the architecturally correct ones.
