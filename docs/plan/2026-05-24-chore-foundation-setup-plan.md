---
title: "Initial Phase — Foundation & Setup (T-01…T-05)"
type: chore
date: 2026-05-24
epic: epic/foundation
source_brainstorm: docs/brainstorm/2026-05-24-foundation-setup-brainstorm-doc.md
---

## Initial Phase — Foundation & Setup (T-01…T-05)

## Overview

This plan delivers the **Foundation & Setup** phase of the Pokédex Flutter app: a
multiplatform scaffold (Android, iOS, Web, macOS) with the feature-first folder
structure from Tech Spec §3, the dependency/codegen/lint toolchain (T-02), the typed
error core `Result<T>` + `Failure` (T-03), the theme and design tokens including
`PokemonTypeTheme` for all 18 types (T-04), and a PR-gated CI pipeline (T-05).

The output is a **CI-green, analyzable, themable skeleton** onto which the data,
domain, and UI layers are later built. This phase produces **no** network/DB/navigation
code — those dependencies and their consumers belong to later layers (Camada 1+). It is
deliberately the thinnest possible base that locks the toolchain and quality gates in
place.

The repo is currently **greenfield** (verified 2026-05-24): no `lib/`, no `pubspec.yaml`,
no `.github/`. Only `assets/fonts/` (18 SF Pro Display weights), `LICENSE`, `README.md`,
and `docs/` exist.

## Problem Statement / Motivation

The whole 32-task backlog (113 pts) depends transitively on a working scaffold, a resolved
codegen toolchain, a typed error vocabulary, a centralized theme, and an enforced quality
gate. Without these, every subsequent slice would re-litigate dependency resolution, re-derive
error types ad hoc, and merge without automated checks.

Getting the **dependency/analyzer resolution right once, upfront** is the highest-leverage
decision: the mid-2026 Flutter ecosystem has a hard 3-way analyzer split (see
_Toolchain decisions_ below). Resolving it now — on the **stable** freezed/riverpod_generator
line — means later data/domain PRs don't hit a version-solve surprise.

## Proposed Solution

### Slice into 3 PRs along the DAG seams

The DAG is `T-01 → T-02 → {T-03, T-04, T-05}` — a fan-out where the error core, theme, and CI
are independent siblings once project + deps exist. Each PR targets **`epic/foundation`**.

| PR      | Tasks              | Branch                     | Why this seam                                                           |
| ------- | ------------------ | -------------------------- | ----------------------------------------------------------------------- |
| **PR1** | T-01 + T-02 + T-05 | `feature/foundation-part1` | Scaffold + deps/codegen/lints + **CI lands first** so PR2/PR3 are gated |
| **PR2** | T-03               | `feature/foundation-part2` | `Result<T>` + `Failure` hierarchy + unit tests (independent sibling)    |
| **PR3** | T-04               | `feature/foundation-part3` | Theme/tokens + `PokemonTypeTheme` + widget test (independent sibling)   |

> **Rationale:** smallest independently-mergeable units at clean seams (the confirmed PR
> right-sizing preference). CI lands in PR1 so it gates PR2 and PR3. T-03 and T-04 don't
> depend on each other and can be developed/reviewed in parallel once PR1 merges.

**Alternatives rejected:** a single monolithic foundation PR (large, mixes concerns, hard to
review); adding the full Tech Spec §15 dependency set upfront (unused deps; forces the
drift-vs-codegen analyzer fork immediately for no benefit); keeping CI main-only (would leave
foundation slice PRs ungated, contradicting T-05's acceptance criteria).

### Target folder structure (created in T-01, populated across the phase)

```text
lib/
├── main.dart                       # runApp(const PokedexApp())
├── app/
│   ├── app.dart                    # MaterialApp + theme wiring (ProviderScope added in T-17)
│   └── theme/                      # T-04: ThemeData, tokens, PokemonTypeTheme
├── core/
│   ├── error/                      # T-03: result.dart, failure.dart
│   └── pokemon/                    # T-04: pokemon_type_id.dart (shared enum — theme now, domain in T-14)
└── features/                       # empty placeholders until Camada 1+ (kept with .gitkeep)
```

> Only the directories the foundation phase actually fills are created with real files.
> `core/network/`, `core/database/`, `core/utils/`, `core/widgets/`, and the per-feature
> trees from §3 are introduced **by the slices that need them** (YAGNI on scaffolding).
> `lib/app/router/` is **not** created here — go_router lands in T-17.

---

## PR1 — Scaffold + deps/codegen/lints + CI (T-01 + T-02 + T-05)

### T-01 · Scaffold (`chore(setup)`)

**Approach:** plain `flutter create .` (NOT the very_good_cli template — avoids unused
dev/staging/prod flavors), enabling platforms **android, ios, web, macos**. macOS is the
available Desktop target on this host; `linux/`/`windows/` can't be generated here.

> **Execution note (hook):** `flutter create` is **blocked** by the VGV PreToolUse hook.
> The user runs it with a leading `!` bang in their prompt. Suggested command:
> `! flutter create . --org com.paulosabra --platforms=android,ios,web,macos`

**Files / actions:**

- Run `flutter create` (user, via `!` bang) to generate platform folders + base `pubspec.yaml`.
- **Delete** the regenerated `test/widget_test.dart` (it references the default counter app).
- Create `lib/app/`, `lib/core/`, `lib/features/` (feature-first per §3). Add `.gitkeep` to
  empty dirs so they're tracked.
- Replace generated `lib/main.dart` with a minimal `runApp` + `lib/app/app.dart` shell
  (plain `MaterialApp` with `home: const Scaffold()` placeholder; theme wired in T-04/PR3).
- Update minimal `README.md` build steps (clone → `flutter pub get` → `dart run build_runner build`
  → `flutter run -d <device>`), seeding Principle 12. Document the **local** gotchas:
  `dart analyze` instead of `flutter analyze` (host crash), tests via `flutter test`.
- Add `.DS_Store` and font cleanup (see T-02 `.gitignore`).

**Acceptance (backlog T-01):**

- [ ] App runs on Android/iOS, Web, and macOS (`flutter run` without errors).
- [ ] Feature-first structure created (`app/`, `core/`, `features/`).
- [ ] Minimal README with build steps.

### T-02 · Deps + codegen + lints (`chore(deps)`)

**Dependency scope = incremental + codegen-ready.** Add only the state/codegen/lint/test
stack now; **defer** data-layer deps to their layers.

| Add now (T-02)                               | Defer to layer                                                       |
| -------------------------------------------- | -------------------------------------------------------------------- |
| `flutter_riverpod`, `riverpod_annotation`    | `dio`, `retrofit` (+`retrofit_generator`) → T-06/07                  |
| `riverpod_generator`, `build_runner` (dev)   | `drift`, `drift_dev`, `drift_flutter`, `sqlite3_flutter_libs` → T-09 |
| `freezed_annotation`, `json_annotation`      | `go_router` → T-17                                                   |
| `freezed`, `json_serializable` (dev)         | `connectivity_plus` → T-06/T-13                                      |
| `very_good_analysis` (dev), `mocktail` (dev) | `intl`, `cached_network_image` → UI layer                            |

> **Toolchain decisions (resolved 2026-05-22, re-applied here):** the mid-2026 ecosystem has a
> hard 3-way analyzer split:
>
> - `custom_lint` (latest) → analyzer **8.x** only ⇒ `riverpod_lint` is **dropped** (incompatible).
> - stable `freezed` 3.2.x + `riverpod_generator` 4.0.x → analyzer **9**.
> - latest `drift` 2.33 → analyzer **10–12** (only satisfiable by `-dev` freezed/riverpod_generator).
>
> We stay on the **analyzer-9 / stable-codegen** line (matches "latest STABLE majors").
> Because **no drift code lands in the foundation phase**, deferring drift has zero cost. The
> exact resolved versions are produced by `pub get`; **`riverpod_analyzer_utils 1.0.0-dev.9` is
> unavoidable** even on the stable path (stable `riverpod_generator 4.0.x` depends on it).
> The executor confirms latest-stable-compatible-with-analyzer-9 at `pub get` time rather than
> hard-pinning from this doc (versions may have moved since 2026-05-22).

**Files / actions:**

- `pubspec.yaml`: declare the incremental dep set above (caret on latest stable majors,
  Riverpod 3 / freezed 3). Re-express the §15 contracts in the current API; flag deltas
  (Tech Spec said Riverpod 2.x — we use 3.x).
- `pubspec.yaml`: declare fonts — **only the 4 weights the design uses** out of the 18 in
  `assets/fonts/`: SF Pro Display **Regular(400)**, **Medium(500)**, **Semibold(600)**,
  **Bold(700)** (per §10.2 Application Title Bold, Pokemon Type Medium, etc.). Fallback chain
  stays Inter/Roboto per §10.
  - _Licensing caveat (acknowledged, user's call):_ SF Pro is Apple-licensed for Apple
    platforms; bundling on Web/Android is outside that license. Acceptable for a
    study/portfolio project.
- `analysis_options.yaml`: `include: package:very_good_analysis/analysis_options.yaml`;
  **exclude generated globs** (`**/*.g.dart`, `**/*.freezed.dart`, `**/*.mocks.dart`,
  `**/*.config.dart`) 1:1 with `.gitignore`.
- `.gitignore`: ignore generated code (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`),
  `.DS_Store`, and standard Flutter/Dart entries. **Commit `pubspec.lock`** (this is an app,
  not a package) — pins package resolution so CI on the floating `stable` channel stays
  reproducible (only the SDK itself floats).
- Remove the 14 unused font weights from `assets/fonts/` (keep Regular/Medium/Semibold/Bold)
  and delete the stray `assets/fonts/.DS_Store`. _(Lighter web payload; add weights later if a
  Figma frame demands.)_
- Add a **real** boot smoke test `test/app/app_boot_test.dart`: a `testWidgets` that pumps
  `PokedexApp` and expects `find.byType(MaterialApp)`. This prevents `flutter test` "No tests
  found" in PR1 _and_ asserts the app actually composes (not a tautological `expect(1, 1)`); it
  stays permanently as a composition guard.
- Run `dart run build_runner build` (no `--delete-conflicting-outputs` — removed/ignored in
  build_runner 2.4). The foundation phase has **no codegen consumer** (Result/Failure are
  hand-rolled; theme is a plain enum/map), so this generates nothing — but it confirms the
  **builder graph instantiates** (generator versions co-load without conflict), which `pub get`
  alone does not verify, and it satisfies the backlog T-02 acceptance criterion. The step must
  **fail on non-zero exit**. It becomes load-bearing at T-08 (first DTO codegen), which is also
  why it stays in the persistent CI workflow now rather than being added later.
- `dart format .`.

**Acceptance (backlog T-02, re-expressed for build_runner 2.4):**

- [ ] `dart run build_runner build` runs without errors (no `--delete-conflicting-outputs`).
- [ ] `dart analyze --fatal-infos --fatal-warnings` returns 0 issues locally (host
      `flutter analyze` crash workaround); `flutter analyze` returns 0 on the CI Linux runner.
- [ ] `dart format` applied (`dart format --set-exit-if-changed .` passes).

### T-05 · CI pipeline (`ci`)

**CI triggers = gate feature + epic + develop + main PRs.** This supersedes the prior
main-only convention so T-05's "every PR triggers the pipeline and blocks merge" is literally
true for foundation slice PRs into `epic/foundation`.

**File:** `.github/workflows/ci.yaml`

- **Triggers:** `pull_request` to `epic/**`, `develop`, `main` (+ `push` to those).
- **Runner:** `ubuntu-latest`. **Flutter SDK:** `subosito/flutter-action` with
  **`channel: stable`** _(decision: track stable — auto-updates; float risk mitigated by the
  committed `pubspec.lock` pinning package resolution; codegen runs before analyze so a
  transitive shift surfaces fast)_.
- **Job order (codegen before analyze/test — a fresh clone won't analyze otherwise):**
  1. `flutter pub get`
  2. `dart run build_runner build`
  3. `dart format --set-exit-if-changed .`
  4. `flutter analyze` _(fine on the clean Linux runner; crashes only on the local macOS host)_
  5. `flutter test --coverage`
- **Coverage:** CI **collects** coverage but enforces **no hard threshold** in this phase. The
  §11/§13 targets (80% domain/data, 100% mappers/cache) activate when those layers land —
  gating them now would fail an app that only has `Result` + theme.
- Per-environment heaviness (`flutter build web --release`) is **left to the Web deploy phase
  (T-31)**; foundation CI is format/analyze/test only.
- **README:** add a CI status badge.

**Acceptance (backlog T-05):**

- [ ] A PR (into `epic/**`/`develop`/`main`) automatically triggers the pipeline.
- [ ] A lint/format/test failure blocks merge (quality gate).
- [ ] Status badge visible in README.

---

## PR2 — Error core: `Result<T>` + `Failure` (T-03, `feat(core)`)

**Approach:** hand-rolled sealed types (no freezed needed — these are tiny, and freezed has no
consumer yet). Re-express Tech Spec §7.3 / §8.1 in current Dart sealed-class syntax.

**Files:**

- `lib/core/error/result.dart`:
  ```dart
  sealed class Result<T> { const Result(); }
  final class Ok<T>  extends Result<T> { const Ok(this.value); final T value; }
  final class Err<T> extends Result<T> { const Err(this.failure); final Failure failure; }
  ```
- `lib/core/error/failure.dart`: sealed `Failure` hierarchy from §7.3, each carrying a `message`
  field (§7.3 default messages). **Equality contract:** hand-roll `==`/`hashCode` including
  `message` (props = `[runtimeType, message]`) — keeps the brainstorm's "hand-rolled, no extra
  deps" intent; `equatable` is an acceptable one-line alternative if the executor prefers. The
  mapping to PRD TE codes is **many-to-one, not 1:1** (see table + note).

  | `Failure`          | PRD TE code(s) | Trigger (later, T-06)              |
  | ------------------ | -------------- | ---------------------------------- |
  | `NetworkFailure`   | TE-01 / TE-02  | `DioExceptionType.connectionError` |
  | `TimeoutFailure`   | TE-06          | connect/receive timeout            |
  | `NotFoundFailure`  | TE-03          | HTTP 404                           |
  | `ServerFailure`    | TE-07          | HTTP 5xx                           |
  | `RateLimitFailure` | TE-08          | HTTP 429                           |
  | `ParsingFailure`   | TE-09          | `FormatException`/serialization    |
  | `CacheFailure`     | TE-01          | local cache miss/error             |

  > **Mapping is many-to-one.** `TE-01` is shared by `NetworkFailure` (offline, no cache) and
  > `CacheFailure` (cache miss); `NetworkFailure` also covers `TE-02` (offline + stale cache).
  > `TE-04`/`TE-05`/`TE-10`/`TE-11` (empty-search, empty-filter, partial-data, missing-image) are
  > **UI/empty states, not `Failure`s** — handled in the presentation layer, not modeled here.

- `test/core/error/result_test.dart`, `test/core/error/failure_test.dart`: cover construction,
  the `Ok`/`Err` switch exhaustiveness, and `Failure` equality — including **inequality** of
  same-type/different-`message` and of different `Failure` subtypes (not just equality of
  identical instances). **`core/error/` is pure Dart and must reach ~100% line coverage in this
  PR** even though no global coverage gate is active yet (the foundation's own code is fully
  covered).

**Acceptance (backlog T-03):**

- [ ] `Result<T>` covers typed success and error.
- [ ] Each `Failure` maps to its originating PRD TE code(s) — TE-01…TE-09 (many-to-one;
      TE-04/05/10/11 are UI states, not Failures).
- [ ] Unit tests cover construction + equality/inequality of the types.
- [ ] `core/error/` reaches ~100% line coverage.

---

## PR3 — Theme + design tokens + `PokemonTypeTheme` (T-04, `feat(theme)`)

**Approach:** centralize §10 tokens. Introduce the `PokemonTypeId` enum in `core/` (consumed by
the theme now and by domain in T-14). **No golden tooling** (alchemist/golden_toolkit) — it stays
deferred to T-18; adding it now would break the incremental-deps decision. Verify color-by-type
with a plain `flutter_test` widget test (T-04 acceptance asks only for "um widget de exemplo").

**Files:**

- `lib/core/pokemon/pokemon_type_id.dart`: `enum PokemonTypeId { grass, poison, fire, water,
electric, bug, normal, flying, ground, fairy, fighting, psychic, rock, ghost, ice, dragon,
dark, steel }` (18 types, §8.2). **Placement deviation (deliberate):** §8.2 and backlog T-14
  list this enum under _domain_, but the theme (PR3) needs it before the domain layer exists
  (T-14), and putting it in `app/theme/` would invert the dependency rule (domain → presentation).
  It lives in `core/` — a leaf both `app/theme` and `features/*/domain` may depend on — so T-14
  **consumes it from `core/` with no migration**.
- `lib/app/theme/pokemon_type_theme.dart`: map `PokemonTypeId → (Color color, Color
backgroundColor)` for **all 18 types**.
  - `color` = exact §10.3 badge hexes (all 18 are specified).
  - `backgroundColor` = exact §10.3 values where given (Grass `#8BBE8A`, Fire `#FFA756`); **for
    the other 16, derive a provisional tint** as `Color.lerp(typeColor, const Color(0xFFFFFFFF),
0.5)!` (50% toward white). This is a documented stopgap that does **not** reproduce the exact
    Figma exemplars (it can't — they aren't a uniform white-lerp), which is precisely why T-18
    reconciles against the Figma `Background Type / *` variables. Mark each derived entry with a
    `// provisional tint — reconcile in T-18` comment.
  - **Type icons are deferred to T-18** (extracted from Figma with the Design System) — the value
    type is `(Color color, Color backgroundColor)` for now, NOT the §10.3 `(cor, corDeFundo,
ícone)` triple. **Migration path:** T-18 promotes this to a small typed class (e.g.
    `PokemonTypeStyle`) carrying the icon, rather than widening the record in place — this avoids a
    silent record-shape breaking change across call sites.
- `lib/app/theme/app_colors.dart`: §10.1 base colors (Text Black `#17171B`, Gray `#747476`,
  White `#FFFFFF`; Background Default Input `#F2F2F2`, White `#FFFFFF`, Modal overlay).
- `lib/app/theme/app_typography.dart`: §10.2 text styles on SF Pro Display
  (Application Title Bold 32, Pokemon Name Bold 26, Description Regular 16, Filter Title Bold 16,
  Pokemon Number Bold 12, Pokemon Type Medium 12).
- `lib/app/theme/app_theme.dart`: base `ColorScheme` + `ThemeData` from §10.1 + the typography.
- Wire the theme into `lib/app/app.dart` (`MaterialApp(theme: AppTheme.light)`).
- `test/app/theme/pokemon_type_theme_test.dart`: a widget test rendering a sample widget colored
  by `PokemonTypeTheme` and asserting the resolved color changes by type (RN-04).

**Acceptance (backlog T-04):**

- [ ] `ThemeData` defined with §10.1 base colors + SF Pro Display typography.
- [ ] `PokemonTypeTheme` covers all 18 types with §10.3 colors (+ derived bg tints for the 16).
- [ ] Theme applied globally; color-by-type verified in an example widget test.

---

## Technical Considerations

- **Architecture impact:** establishes the `app/` + `core/` skeleton and the dependency
  direction (everything points to domain; data implements domain interfaces). Foundation adds
  no cross-layer imports — `core/error` is leaf, `app/theme` is leaf.
- **Codegen with no consumer:** PR1's `build_runner` run confirms the **builder graph
  instantiates** (generators co-load without a version conflict) — it is not exercised on real
  annotations until DTOs (T-08), entities (T-14), and DI (T-17). It generates nothing now; this is
  intentional and called out so a future reviewer isn't surprised. The CI step stays from PR1
  because it is load-bearing the moment T-08 lands (git-ignored generated code must be regenerated
  on a fresh clone before analyze).
- **Generated code is git-ignored**, and `analysis_options.yaml` excludes the same globs 1:1.
  CI must run codegen **before** analyze/test (fail-fast); a fresh clone won't analyze otherwise.
- **`pubspec.lock` committed** to stabilize the floating `stable` SDK channel (package
  resolution pinned; only the Dart/Flutter SDK version floats).
- **Performance:** trimming fonts to 4 weights (~9 MB vs ~40 MB) materially reduces the future
  web payload.
- **Security:** none in scope — no secrets, network, or user data this phase.

## Edge cases & developer/CI-flow completeness

- **"No tests found"** in PR1 → mitigated by the real `test/app/app_boot_test.dart` boot test.
- **Fresh-clone CI** can't analyze without generated files → codegen step ordered first.
- **Local `flutter analyze` crash** (host-specific, Flutter 3.44.0) → use
  `dart analyze --fatal-infos --fatal-warnings` locally; CI keeps `flutter analyze` on Linux.
  The two entrypoints can differ, so **CI's `flutter analyze` is the source of truth** — a rule it
  surfaces that `dart analyze` misses would pass locally but fail CI.
- **`flutter create` regenerates `test/widget_test.dart`** → delete it (again) after scaffold.
- **`linux/`/`windows/` not generatable on this macOS host** → enable android/ios/web/macos only.
- **`stable` channel float** → committed `pubspec.lock` pins packages; if a new stable still
  breaks resolution, pin `flutter-version` as a fallback (documented in the workflow comment).
- **Hook-blocked CLI:** `flutter create` (user runs via `!` bang); tests run via the very_good
  MCP tool, which returns pass/fail only (bisect or throwaway `dart run` scripts to localize).

## Acceptance Criteria (phase-level rollup)

- [ ] PR1 merged: app runs on android/ios/web/macos; deps resolve; `build_runner` clean;
      `dart analyze` 0 issues; `dart format` clean; CI workflow gates `epic/**` PRs; badge in README.
- [ ] PR2 merged: `Result<T>` + 7 `Failure` types (TE mapping, many-to-one) with passing unit
      tests + ~100% coverage of `core/error/`.
- [ ] PR3 merged: theme + tokens + `PokemonTypeTheme` (18 types) with a passing color-by-type
      widget test; theme applied globally.
- [ ] All three PRs green in CI before merge into `epic/foundation`.

## Success Metrics

- CI is green on `epic/foundation` and gates every foundation slice PR.
- A new dev can clone → `pub get` → `build_runner build` → `flutter run` from the README in one sitting.
- Zero analyzer warnings/infos; `dart format` clean.
- The analyzer-9/stable-codegen line is locked in `pubspec.lock` with no `-dev` builds except the
  unavoidable `riverpod_analyzer_utils 1.0.0-dev.9`.

## Dependencies & Risks

- **DAG:** PR1 (T-01→T-02→T-05) must land before PR2/PR3. PR2 and PR3 are parallelizable after PR1.
- **Risk — `stable` channel drift:** a future Flutter stable could shift transitive analyzer/codegen
  versions. _Mitigation:_ committed `pubspec.lock`; fallback to pinning `flutter-version` in CI.
- **Risk — analyzer fork regression:** naively bumping `drift` to 2.33 in a later slice would drag
  freezed + riverpod*generator onto `-dev` builds. \_Mitigation:* documented here and in memory; drift
  isn't in this phase.
- **Licensing:** SF Pro bundled on Web/Android is outside Apple's license (accepted for portfolio).

## Local workflow reminders (execution)

- **Scaffold/platform add** (`flutter create …`): hook-blocked → user runs with a leading `!` bang.
- **Run tests:** very_good_cli MCP tool (`flutter test` is hook-blocked); it returns only pass/fail.
  To localize a failure: throwaway `dart run` script for pure-Dart logic; **bisect** for
  `flutter_test` files (move/trim test files, re-run, read exit status).
- **Not blocked (run freely):** `flutter analyze` (CI), `dart analyze` (local), `dart format`,
  `dart run build_runner build`, `flutter pub get`.
- **Before each PR** (until T-05's broadened CI merges, there is no CI): run the full local suite —
  `dart format --set-exit-if-changed .`, `dart analyze --fatal-infos --fatal-warnings`, very_good test.
- **Per VGV build convention:** commit review reports under `docs/reviews/` per slice.

## References & Research

- **Source brainstorm:** `docs/brainstorm/2026-05-24-foundation-setup-brainstorm-doc.md`
- **Backlog:** `docs/project/04-backlog.md` — T-01 (L106), T-02 (L115), T-03 (L124), T-04 (L133),
  T-05 (L142); DAG (L36-77).
- **Tech Spec:** `docs/project/02-tech-spec.md` — folders §3 (L87), `Result`/`Failure` §7.3/§8.1
  (L382-417), theme/tokens §10 (L542-592), CI §14 (L719-730), deps §15 (L734-745).
- **PRD:** `docs/project/01-prd.md` — TE error codes §8 (L356-372).
- **Institutional learnings (memory):** analyzer-9 vs drift-2.33 fork & `flutter analyze` host
  crash & build_runner 2.4 `--delete-conflicting-outputs` removal (`analyzer9-toolchain`);
  GitFlow base = `develop` for epics, CI now gates `epic/**` (`git-flow`); latest-stable-majors +
  plain `flutter create` + YAGNI scaffolding (`flutter-deps-scaffolding`); hook-blocked
  create/test + `!` bang + MCP test tool (`vgv-cli-hooks`).
- **Decisions resolved in /plan (this doc):** type background colors → derive tints now, reconcile
  in T-18; CI Flutter version → track `stable` channel (mitigated by committed `pubspec.lock`).
- **Related PRs:** prior Epic 0 PR1 (2026-05-22) that originally resolved the analyzer-9 pins
  (repo since reset to greenfield — pins must be re-applied, not reused).

### Technical-review findings incorporated (2026-05-24)

Three review agents ran on this plan. **Plan-splitting: no split** — the 3-PR DAG slicing is
right-sized (PR1 must bundle scaffold+deps+CI so the gate exists for PR2/PR3). Applied fixes:

- **`PokemonTypeId` → `core/`** (was `app/theme/`): avoids the domain→presentation dependency
  inversion when T-14 consumes it. Deliberate, documented deviation from §8.2's literal placement.
- **TE mapping reworded** from "1:1" to **many-to-one** (TE-01 shared; TE-04/05/10/11 are UI states).
- **`Failure` equality** contract pinned (props = `[runtimeType, message]`, hand-rolled; tests
  assert inequality); **`core/error/` ~100% coverage** required this PR.
- **Type-background tint** formula pinned: `Color.lerp(typeColor, white, 0.5)`, provisional → T-18.
- **Smoke test** upgraded from tautological `expect(1,1)` to a real `testWidgets` boot assertion.
- **Icon-slot migration** noted: T-18 promotes the record to a `PokemonTypeStyle` class (no in-place
  record widening).
- **`flutter analyze` (CI) is the source of truth** vs local `dart analyze` (host-crash workaround).
- **Kept (disagreed with simplicity agent):** the CI `build_runner` step — it's persistent
  infrastructure, load-bearing from T-08, and a backlog T-02 acceptance criterion; clarified that it
  validates the builder graph and must fail on non-zero exit.
