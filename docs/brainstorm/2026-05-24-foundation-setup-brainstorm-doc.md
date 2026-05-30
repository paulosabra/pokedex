---
date: 2026-05-24
topic: foundation-setup
---

# Initial Phase — Foundation & Setup (T-01…T-05)

## What We're Building

The foundation phase of the Pokédex Flutter app: a multiplatform scaffold (Android,
iOS, Web, macOS) with the feature-first folder structure from Tech Spec §3, the
dependency/codegen/lint toolchain (T-02), the typed error core `Result<T>` + `Failure`
(T-03), the theme and design tokens including `PokemonTypeTheme` for all 18 types
(T-04), and a PR-gated CI pipeline (T-05). This delivers a CI-green, analyzable,
themable skeleton onto which the data, domain, and UI layers are built — no business
features yet.

This phase produces **no** network/DB/navigation code; those dependencies and their
consumers belong to later layers. Initial Phase is deliberately the thinnest possible base
that locks the toolchain and quality gates in place.

## Why This Approach

The work decomposes along a clean dependency DAG — `T-01 → T-02 → {T-03, T-04, T-05}` —
where the error core, theme, and CI are independent siblings once the project and deps
exist. Slicing PRs along that fan-out gives small, independently reviewable units while
landing the CI gate first so subsequent slices are protected. We add only the
dependencies Initial Phase (and the immediately-following codegen) needs, deferring data-layer
deps, consistent with the project's YAGNI-on-internal-tooling stance. We diverge from
the spec's literal version pins where the toolchain has moved on (latest stable majors:
Riverpod 3, freezed 3), re-expressing the spec contracts in the current API.

Alternatives considered and rejected: a single monolithic foundation PR (large, mixes
concerns, hard to review); adding the full Tech Spec §15 dependency set upfront (unused
deps, forces the drift-vs-codegen analyzer version fork immediately for no benefit);
keeping CI main-only (would leave foundation slice PRs ungated, contradicting T-05's
acceptance criteria).

## Key Decisions

### Cross-cutting (4 forks resolved with the user)

- **Dependency scope = incremental + codegen-ready.** T-02 adds the state/codegen/lint/
  test stack now — `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`,
  `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`,
  `build_runner`, `very_good_analysis`, `mocktail`. **Defer** to their layers:
  `dio`/`retrofit`(+generator), `drift`/`drift_dev`/`drift_flutter`/`sqlite3_*`,
  `go_router`, `connectivity_plus`, `intl`, `cached_network_image`. Rationale: resolves the
  **analyzer-9 dependency constraints once, upfront** (stable freezed 3.2.x +
  riverpod_generator 4.0.x), so later data/domain PRs don't hit a version-solve surprise —
  without dragging in `drift` 2.33 → analyzer-12 → `-dev` codegen prereleases.
  `very_good_analysis` must be on a version compatible with that analyzer-9 line.
  *Honest caveat:* Initial Phase has **no codegen consumer** (Result/Failure are hand-rolled, the
  theme is a plain enum/map), so PR1 only validates dependency resolution + an empty
  `build_runner` run; the generators aren't actually exercised until DTOs (T-08), entities
  (T-14), and DI (T-17). No drift/dio code exists in Initial Phase, so deferring those has zero cost.
- **PR slicing = 3 PRs at DAG seams** (each into `epic/foundation`):
  - **PR1** = T-01 + T-02 + T-05 — scaffold + deps/codegen/lints + CI workflow. CI lands
    first so PR2/PR3 are gated.
  - **PR2** = T-03 — `Result<T>` + `Failure` hierarchy + unit tests.
  - **PR3** = T-04 — theme/tokens + `PokemonTypeTheme` + a **widget** test of color-by-type
    (plain `flutter_test`; no golden tooling — see T-04 note).
  - Rationale: smallest independently-mergeable units at clean seams (user's confirmed
    PR right-sizing preference); the error core and theme are independent siblings.
- **CI triggers = gate feature + epic + develop PRs.** The workflow triggers on
  `pull_request` to `epic/**`, `develop`, and `main` (plus pushes to those), running
  `format → analyze → test` and blocking merge. This makes T-05's "every PR triggers the
  pipeline and blocks merge" literally true, **superseding** the prior main-only
  convention. (Per-environment heaviness — e.g. `flutter build web --release` — is left
  to the Web deploy phase, T-31; Initial Phase CI is format/analyze/test only.)
- **Font bundling = only the weights the design uses.** Declare the SF Pro Display
  weights referenced by Tech Spec §10.2 — Regular(400), Medium(500), Bold(700), and
  Semibold(600) if a header needs it — out of the 18 files now in `assets/fonts/`.
  Lighter web payload; add more weights later if a Figma frame demands it.
  - _Licensing caveat (acknowledged, user's call):_ SF Pro is Apple-licensed for Apple
    platforms; bundling on Web/Android is outside that license. Acceptable for a
    study/portfolio project. Fallback chain stays Inter/Roboto per §10.

### Per-task scope notes

- **T-01 — Scaffold.** Plain `flutter create .` (NOT the very_good_cli template — avoids
  unused dev/staging/prod flavors). Enable platforms **android, ios, web, macos**
  (macOS is the available Desktop target on this host; `linux/`/`windows/` can't be
  generated here). Create `lib/app/`, `lib/core/`, `lib/features/` per Tech Spec §3.
  Delete the regenerated `test/widget_test.dart`. Minimal README build steps (Principle
  12 seed). *Execution note:* `flutter create` is blocked by the VGV PreToolUse hook —
  the user runs it with a leading `!` bang.
- **T-02 — Deps + codegen + lints.** pubspec with the incremental set above; adopt
  `very_good_analysis` in `analysis_options.yaml` and exclude generated globs
  (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) 1:1 with `.gitignore` (generated code
  is git-ignored). `build_runner` runs clean (no `--delete-conflicting-outputs` — removed
  in build_runner 2.4). `dart format` applied.
- **T-03 — Error core.** Hand-rolled sealed `Result<T>` = `Ok<T>` / `Err<T>` and the
  sealed `Failure` hierarchy from Tech Spec §7.3: `Network`, `Timeout`, `NotFound`,
  `Server`, `RateLimit`, `Parsing`, `Cache`. Each maps 1:1 to a PRD TE code
  (TE-01…TE-09; `Network`→TE-01/02, `Cache`→TE-01). Unit tests cover construction +
  equality. No freezed needed here.
- **T-04 — Theme + tokens.** Typography (SF Pro Display, weights above), base
  `ColorScheme`/`ThemeData` from §10.1 colors, and `PokemonTypeTheme` mapping all 18
  `PokemonTypeId` → (color, backgroundColor) using the §10.3 palette. **Type icons are
  deferred to T-18** (extracted from Figma with the Design System). Background colors for
  the 16 types not exemplified in §10 are pulled via Figma `get_variable_defs` (or
  derived as lighter tints as a documented stopgap). Color-by-type verified with a plain
  `flutter_test` widget test (T-04 acceptance asks only for "um widget de exemplo").
  **Golden tooling (alchemist/golden_toolkit) stays deferred to T-18** — adding it now would
  break the incremental-deps decision. The `PokemonTypeId` enum is introduced here (also used
  by domain in T-14).
- **T-05 — CI.** GitHub Actions, `ubuntu-latest`, Flutter stable 3.44.0. Job order:
  `pub get → build_runner build → dart format --set-exit-if-changed → flutter analyze →
flutter test --coverage`. Codegen runs **before** analyze/test (fresh clone won't
  analyze otherwise). `flutter analyze` is fine on the clean Linux runner (it crashes
  only on the local macOS host — use `dart analyze` locally). Status badge in README.
  CI **collects** coverage but enforces **no hard threshold** in Initial Phase — the §11/§13 targets
  (80% domain/data, 100% mappers/cache) activate when those layers land; gating them now would
  fail an app that only has `Result` + theme. Ensure a trivial smoke test exists so
  `flutter test` in PR1 doesn't fail with "No tests found."

### Local workflow reminders (from prior sessions)

- Run tests via the very_good_cli MCP tool (`flutter test` is hook-blocked); it returns
  only pass/fail — bisect or use throwaway `dart run` scripts to localize failures.
- Local validator is `dart analyze --fatal-infos --fatal-warnings` (host `flutter
analyze` crash). Because foundation slice PRs target `epic/foundation`, run the full
  local check suite before opening each PR — though once the broadened CI (this phase's
  T-05 decision) merges, Actions will also gate `epic/**` PRs.

## Open Questions

- **Background-color source for the 16 non-exemplified types (T-04):** confirm whether to
  pull each from Figma `get_variable_defs` during T-04, or ship derived tints in T-04 and
  reconcile against Figma in T-18 (Design System). Leaning: pull from Figma if the
  variables exist; otherwise derive + reconcile in T-18.
- **CI Flutter version pinning:** pin the Actions runner to exactly 3.44.0, or track
  `stable`? Pinning is reproducible but needs manual bumps. Decide in /plan for T-05.
