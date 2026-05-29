# Architecture Review — PR3 (T-30b): Wire PRD §12 analytics events

**Branch:** `feature/quality-part3` · **Reviewer role:** VGV architecture
**Scope:** the 7 PR3-touched `lib/` files (3 design-system error widgets, 2
feature widgets, 2 screens, 1 ViewModel) + the new
`presentation/analytics/error_te_code.dart`.
**Stack:** Flutter 3.44.0, Riverpod (codegen), MVVM over a clean
data/domain/presentation feature layering with a `lib/core/` shared toolkit
(network, error, observability seam, UI/design-system). Layer rules read from
the project memory and `docs/plan/2026-05-28-feat-quality-and-release-plan.md`
§6a.1 (mermaid) and §6b.

---

## Layer Separation

The PR introduces one cross-layer concern: the presentation layer consuming the
`lib/core/observability/` seam. The relevant rules are:

1. **Design-system widgets (`lib/core/ui/`) must stay free of observability and
   Riverpod.** A DS widget that imported `analyticsServiceProvider` would couple
   the portable toolkit to the app's DI container and analytics vocabulary.
2. **Presentation never imports the data layer directly** — it goes through
   domain use-cases / repositories.
3. **`lib/core/error/` (domain-adjacent typed `Failure`) must not learn about
   presentation concerns** (TE codes, analytics).

### Findings

- **DS layer stays observability-free — CONFIRMED.** `grep` across
  `lib/core/ui/` finds the strings `observability`/`riverpod` only inside
  doc-comments explaining *why* the widgets avoid the dependency. The three
  error widgets (`offline_error_widget.dart`, `generic_error_widget.dart`,
  `stale_cache_banner.dart`) import only `package:flutter/material.dart`,
  `state_view.dart`, and theme files. No `flutter_riverpod`, no
  `observability_providers`. Clean.

- **Presentation → data: no new violation.** The only
  `features/pokemon/data/...` imports in the presentation tree live in the three
  `coordinators/*.dart` files, which are **not** touched by PR3 (confirmed via
  `git status`). They are pre-existing and out of scope. All 7 PR3 files import
  only `core/observability`, `core/error`, `core/ui`, `app/theme`, domain
  entities, and other presentation files. No data-layer leak.

- **`lib/core/error/failure.dart` stays presentation-free — CONFIRMED.** The
  TE-code switch lives in `presentation/analytics/error_te_code.dart`, not in
  the `Failure` hierarchy. `failure.dart` mentions TE codes only in
  doc-comments; the mapping logic is not in the domain. This is the correct
  direction (see Decision 2 below).

**Violations found: 0.** All 7 changed files + the new file are clean.

---

## State Management Assessment

### `PokemonListViewModel` (Riverpod `@riverpod` notifier) — Correct

- **Side-effect, never a gate.** Every emission (`ListViewed`, `SearchPerformed`,
  `FilterApplied`, `SortChanged`, `GenerationSelected`, `ErrorShown`) is a
  fire-and-forget `_analytics.logEvent(...)` *after* the `state = AsyncData(...)`
  mutation, or alongside a `_reportFailure(...)`. No control-flow branch depends
  on an analytics return value (the interface returns `void` and is documented
  "never throws into the caller"). Observability cannot alter UI behaviour. This
  is the single most important property for this PR and it holds throughout.

- **`ref.read`, not `ref.watch` — Correct.** `_analytics` and `_reportFailure`
  read the providers (`AnalyticsService get _analytics => ref.read(...)`). A
  notifier emitting a one-shot event must not rebuild when the sink identity
  changes; `ref.read` is the right call. The sink is resolved lazily per use, so
  a `bootstrap()` override installed after first build is still honoured.

- **Handler organisation — Correct.** `_reportFailure` centralises the
  crash-sink call (failure + `StackTrace.current` + TE tag) so the four handled
  `Err` sites (`loadMore`, browse-refresh, discovery-refresh, `_enterDiscovery`)
  stay DRY. The formerly-swallowed `loadMore` `Err` now both reports and emits
  `ErrorShown` — matching plan §4.3 (the "was silently swallowed" row) and AC
  "error_shown fires for every state in the §4.3 table."

- **Semantics match the plan's intent.** `search_performed` fires only when
  `current.query.isNotEmpty` (a filter/sort-only discovery is not a "search"),
  honouring RNF-09 by emitting only `resultCount`. `generation_selected` fires
  only on a positive selection (clearing is not an event). `list_viewed`
  distinguishes cold (first build) from warm (`_enterBrowse`). These are correct
  modelling choices, not over-engineering.

- **Minor (Suggestion).** `_screen` is a `static const String 'pokemon_list'`
  while the detail screen uses its own `_screenName` literals. Two screens, two
  conventions, no shared `enum`/constant. Low-risk, but a typo in one literal
  would silently mis-bucket analytics. Consider a single source for screen names
  if the event surface grows. Not blocking.

### `_TabsState` (`ConsumerState` in detail screen) — Correct

- Emits `DetailTabChanged` from `_maybeReportTabChange`, guarded by
  `_reportedIndex` (seeded from the controller's initial index) so the
  first-shown tab is not counted and the listener does not fire on every
  animation frame — only when the settled index actually changes. Reads via
  `ref.read` inside a callback. Lifecycle is correct: the animation listener is
  removed in `dispose`. Good.

### `_Error` / `_Body` (detail + list screens) — Correct

- The `error_shown` emission is owned by the presentation caller, which knows
  both the `screen` name and the TE code. `_Body._reportErrorShown` and
  `_Error.reportShown` wrap `ref.read(analyticsServiceProvider).logEvent(...)`
  and are passed as the DS widgets' `onShown` callback. The TE code is derived
  by `teCodeForError(error)` (generic path) or passed literally (`'TE-01'`
  offline, `'TE-02'` stale banner) — exactly the split the mapping file
  documents.

### `PokemonCard` / `_StageCard` (Consumer feature widgets) — Correct (see Decision 3)

- Both read `analyticsServiceProvider` via `WidgetRef` and emit
  (`PokemonOpened`, `EvolutionNavigated`) immediately before `context.push(...)`.
  The emission does not gate navigation (it is a plain statement before the
  push). Skeleton rows report `primary_type: 'unknown'` rather than throwing on
  an empty `types` list — a correct defensive choice.

---

## Dependency Direction

The dependency graph for the new wiring flows one way and matches §6a.1:

```
presentation (VM, screens, feature widgets)
    -> core/observability (AnalyticsService, ErrorReporter, AnalyticsEvent, providers)
    -> core/error (Failure)            [via error_te_code.dart]
    -> core/ui/states (DS error widgets, via onShown callback seam)
    -> domain entities / use-cases
```

- **`core/observability` depends on neither presentation nor the pokemon
  feature.** It defines the interfaces; presentation consumes them. Correct
  inversion.
- **`core/ui/states` depends on neither observability nor presentation.** The
  `onShown` `VoidCallback` is a pure Flutter type; the dependency points *into*
  the DS widget from the presentation caller, never out. The DS widget remains
  portable.
- **`error_te_code.dart` depends only on `core/error/failure.dart`.** It is
  imported by three presentation files and nothing in `core/` or `data/`
  (confirmed by `grep`). No reverse or circular edge.
- **No circular dependency** introduced by any of the 7 files.

**Direction violations: 0. Circular dependencies: 0.**

---

## Package Structure

This is a single-package app (`pokedex`), so "package structure" maps to
module/directory structure under `lib/`.

- **New `presentation/analytics/` directory.** Holds a single file,
  `error_te_code.dart` (2 functions, ~30 lines). A one-file directory normally
  invites "fold it into an existing module," but here the placement is
  *deliberate and justified*: it groups the analytics-mapping concern under the
  feature's presentation layer, away from the domain `Failure`, and gives the
  T-30b plan a natural home for any future presentation-side analytics mapping.
  Acceptable. (See Decision 2.)
- **`dart analyze` on the 4 most-affected files: "No issues found!"** Lints
  pass; `very_good_analysis` standards hold.
- **No new dependency added to `pubspec.yaml`** — T-30b is a wiring-only PR
  (plan: "adds no files to `lib/core/observability/`," and adds no deps). Correct
  scope discipline.
- **Tests exist** for all touched units (the `test/` tree carries matching
  `*_test.dart` for VM, both screens, both feature widgets, plus a new
  `test/helpers/recording_observability.dart` harness). Test correctness is
  out of scope for an architecture review but the structure is present.

---

## Evaluation of the Four Flagged Decisions

### Decision 1 — `onShown` callback seam vs. the plan's literal "emit in the widget"

Plan §6b.1 names `offline_error_widget.dart`, `generic_error_widget.dart`,
`stale_cache_banner.dart` as the `error_shown` emission *site*. The
implementation instead gives each widget an optional `onShown` `VoidCallback`
fired once in `initState`, and the **presentation-layer screens own the
emission**.

**Verdict: superior design; endorse the deviation.** Had the DS widgets emitted
directly, they would have to import `analyticsServiceProvider` (Riverpod) and
the `AnalyticsEvent` vocabulary, and they would have to *know their own TE code
and screen name* — but TE-01-vs-TE-02 is a UI-state distinction the widget
cannot make (the same `OfflineErrorWidget` shell is reused with different copy),
and the screen name is caller context. The callback seam keeps the toolkit
portable, pushes the screen/TE knowledge to the only layer that has it, and
fires exactly once via `initState` (idempotent per mount). This is precisely the
"if you need something from a lower layer in a higher one, invert it" principle.
It also aligns with the project memory note that the user favours the reviewer's
quality fix over literal plan adherence. The plan's "site" should be read as
"the widget mount is the *trigger*," which the callback honours. One caveat
(Suggestion): `initState`-fired callbacks run during the first build phase; the
callbacks here only call `ref.read(...).logEvent(...)` (no `setState`, no
provider mutation), so there is no build-phase-mutation hazard — confirmed safe.

### Decision 2 — `error_te_code.dart` in `presentation/analytics/` not `core/error/`

`failure.dart` deliberately keeps TE codes out of the domain (doc-comments
reference them, but no field/method emits them). The Failure→TE mapping is a
**presentation/analytics concern**: TE codes exist for the PRD's user-facing
error catalogue and the `error_shown` event, not for domain logic.

**Verdict: correct placement.** Putting `teCodeFor` in `core/error/` would pull
an analytics/presentation vocabulary down into the shared error module and make
every consumer of `Failure` transitively aware of TE strings. Keeping it in
`presentation/analytics/` preserves the domain's purity and points the
dependency the right way (`error_te_code` → `failure`, never the reverse). The
`switch` is exhaustive over the sealed `Failure` hierarchy, so adding a future
failure type is a compile error here until a code is assigned — a strong
correctness guard. The TE-02 "stale but cached" case is intentionally *not*
derived here (no `Failure` subtype uniquely identifies it; it is a UI-state
distinction) and is passed literally at the banner site — consistent with §4.3.

### Decision 3 — feature widgets converted to `Consumer`/`ConsumerWidget`

`PokemonCard` (`ConsumerWidget`), `_StageCard` (`ConsumerWidget`), `_Tabs`
(`ConsumerStatefulWidget`) read `analyticsServiceProvider` to emit on tap/tab
change.

**Verdict: layer-correct.** These are **presentation-layer feature widgets**
(`lib/features/pokemon/presentation/widgets/...`), not DS components — the
DS-vs-feature split is honoured by the existing `PokemonCard` adapter pattern
(the feature `PokemonCard` already wraps `core.PokemonCard` and was already a
`ConsumerWidget`). Reading a provider from a presentation widget is the standard
Riverpod pattern and matches §6b's note "widgets get them via `ProviderScope`."
The emission is a statement before `context.push`, never a gate. No data-layer
import is pulled in. The only mild trade-off is that interaction-level events now
live in widget callbacks rather than the VM; that is acceptable here because
these are navigation intents the VM does not own (the card/stage push routes
directly via `go_router`), so routing the event through the VM would add
indirection without benefit.

### Decision 4 — ViewModel `ref.read` + fire-and-forget after state mutation

**Verdict: correct.** Covered under State Management above. `ref.read` (not
`watch`) is right for one-shot side-effects; emission after the `state =`
mutation guarantees analytics never sits on the UI's critical path; the
`void`-returning, never-throwing interface contract means a sink failure cannot
propagate into the VM. The `_reportFailure` + `ErrorShown` pairing on handled
`Err` paths makes previously-invisible failures observable without changing user
behaviour.

---

## Verdict

**Architecture is clean — ready to merge (architecture dimension).**

- Layer separation: 0 violations. The DS layer is verifiably observability-free;
  presentation introduces no data-layer import; the domain `Failure` stays
  TE-code-free.
- Dependency direction: one-way, no cycles.
- State management: Riverpod usage is idiomatic; observability is a true
  side-effect that never gates UI behaviour.
- All four flagged decisions are sound; the `onShown` callback seam (Decision 1)
  is a genuine improvement over the plan's literal wording and should be kept.

**Critical: 0 · Important: 0 · Suggestions: 2** (unify screen-name constants
across VM/detail/list; optionally consolidate analytics-mapping if the surface
grows). Neither suggestion blocks merge.
