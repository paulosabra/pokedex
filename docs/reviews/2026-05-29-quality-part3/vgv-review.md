# VGV Code Review — T-30b: Wire PRD §12 analytics events

**Branch:** `feature/quality-part3` · **Reviewer:** VGV Review Agent · **Date:** 2026-05-29
**Scope:** the T-30b working-tree changes only (presentation-layer event wiring on top of the T-30a observability seam). Adapter/seam internals (T-30a) are out of scope except where consumed.

## Summary

This is a clean, conventions-respecting slice that does exactly what the plan §6b asked for and no more. All nine PRD §12 events are wired at the verified call sites, each property is RNF-09-safe (no PII — `search_performed` exposes only `result_count`, filters report presence flags only), and every event has a focused test asserting the event name and its exact parameter map. The standout design decision — keeping the three `lib/core/ui/states/` design-system widgets observability-free by exposing a one-shot `onShown` callback rather than importing the analytics provider — is the *correct* call and a genuine improvement over the plan, which named those files as if they would emit directly. Layer boundaries are respected throughout: the DS layer stays provider-free, the feature layer owns the TE-code mapping and the `screen` tags, and the ViewModel reads the injected services via `ref`. Static analysis is clean on all changed files.

**Verdict: Ready to merge.** No critical issues. The findings below are a small number of low-severity polish items; none block.

> **Note on test execution:** static analysis passes clean on every changed file. The full-suite run via the `very_good test` MCP tool returned exit code 69 (service-unavailable / environmental) regardless of tag filters or optimization flags — this is not attributable to the T-30b changes (the changed test files are well-formed, import cleanly, and analyze without error). The reviewer was unable to get a green/red signal from the runner in this environment; **recommend confirming the suite passes in CI** before merge as the normal gate.

---

## 🔴 Critical — Must Fix Before Merge

None.

---

## 🟡 Important — Should Fix

None that block. The items below are borderline-important polish; treat as reviewer suggestions.

---

## 🔵 Suggestions — Nice to Have

- **`pokemon_list_view_model.dart:127-129` — `error_shown` for swallowed `loadMore` uses `teCodeFor(failure)` directly, while the refresh paths only `_reportFailure` without emitting `error_shown`.**
  This is intentional and correct per §4.3 (the swallowed `loadMore` failure has no user-visible widget, so the VM must emit `error_shown` itself; the refresh failures *do* surface a visible widget — the stale-cache banner — which emits `error_shown` from its own `onShown`). The asymmetry is right, but it is subtle. Consider a one-line comment at the `refresh()` `Err` branches noting "the banner's `onShown` emits `error_shown`; here we only report the handled failure" to spare the next reader the cross-file trace. (The `loadMore` branch already has an excellent comment; the refresh branches say "report the handled failure" but don't explicitly say *why no `error_shown` here*.)

- **`pokemon_detail_screen.dart:650-671` — the offline branch hardcodes `'TE-01'` while the generic branch uses `teCodeForError(error)`.**
  Both are correct (`NetworkFailure`/`CacheFailure` → TE-01 in `teCodeFor`, so the literal matches the mapper). The hardcoded literal is defensible because the offline branch has *already* pattern-matched `error is NetworkFailure || error is CacheFailure`, making `teCodeForError` redundant there. But it does duplicate knowledge that lives in `error_te_code.dart`. Minor: passing `teCodeForError(error)` to *both* branches would remove the literal and keep the mapping single-sourced, at the cost of one redundant call on a known-offline path. Low priority — current form is readable and the comment chain is clear.

- **`pokemon_list_view_model.dart:61-63` — `_reportFailure` stamps `StackTrace.current` at the report site, not the failure's origin.**
  Since `Failure` is a sealed value type (not thrown at the report site), `StackTrace.current` captures the VM method frame, not where the network/cache error arose. For a *handled* failure this is acceptable diagnostic context (it tells you which VM path swallowed it), and the typed `failure:` argument carries the real signal. No change needed; flagging only so it's a conscious choice rather than an accident.

- **`pokemon_detail_screen.dart:491-493` — `_handleTick` calls `setState(() {})` on every tab-animation frame and also invokes `_maybeReportTabChange()` each tick.**
  Pre-existing behavior (the pokeball ornament tracks the animation continuously), and `_maybeReportTabChange` is guarded cheaply by `_reportedIndex`, so the analytics emission is correctly once-per-settled-tab. No action; noting that the per-frame `setState` is a rendering concern that predates this PR, not something T-30b introduced.

- **`observability_providers.dart:59-61` — `TODO(paulosabra)` for `posthogHost`.**
  Out of T-30b scope (lives in the T-30a file) and correctly deferred to T-31 with a tracked owner. No action in this PR.

---

## Regressions & Breaking Changes (Pass 1)

- **Widget type changes are additive and safe.** `PokemonCard` (StatelessWidget → ConsumerWidget) and the three DS state widgets (StatelessWidget → StatefulWidget) change their internal structure but **preserve their public constructor contracts** — every new parameter (`onShown`) is optional and nullable, so all existing callers compile unchanged. The DS widgets gained `onShown` with a `?.call()` in `initState`; absent the callback they behave exactly as before.
- **No deleted code, no weakened tests.** Existing detail-screen tab tests (`tapping the Stats tab swaps to StatsTab`, etc.) are retained; the analytics group is purely additive.
- **No public API signatures changed** in the observability seam (T-30a) — this slice only *consumes* `AnalyticsService.logEvent`, `ErrorReporter.captureError`, and the nine `AnalyticsEvent` constructors.
- **No dependency changes** in this slice (firebase/sentry/posthog landed in T-30a).
- **`error_shown` for the formerly-swallowed `loadMore` failure is a behavior addition, not a regression** — the failure was previously invisible; it is now reported + emitted. Correctly tested (`swallowed loadMore failure reports captureError and emits error_shown`).

---

## VGV Architecture & Conventions (Pass 2)

### Layer separation — PASS (and improved over the plan)

The headline architectural decision is the right one. The plan's §6b.1 table lists `offline_error_widget.dart`, `generic_error_widget.dart`, and `stale_cache_banner.dart` under "Events wired … `error_shown`", which reads as if the DS widgets would emit directly. The implementation instead introduces a provider-free `onShown` callback seam: the widget fires `onShown` once in `initState`, and the **caller** — which is in the feature/presentation layer and knows both the `screen` tag and the TE code — owns the `logEvent` call. This keeps `lib/core/ui/` with **zero observability imports** (verified: the three files import only `flutter/material`, `state_view`, and theme), preserving the DS layer's independence. This is a textbook application of "duplication/indirection at the boundary beats a wrong dependency." Each widget documents the rationale in its doc comment. Endorsed.

- `PokemonCard` and `_StageCard` correctly read `analyticsServiceProvider` via `ref` (they are `ConsumerWidget`s); domain imports stay out of `lib/core/ui/` because the feature-side `PokemonCard` adapter is the one touching the provider, not the DS `core.PokemonCard`.
- The TE-code mapping lives in the **feature** presentation layer (`features/pokemon/presentation/analytics/error_te_code.dart`), not in `lib/core/` — appropriate, since the failure→TE policy is a product concern, and it keeps the core seam policy-free.

### State management — PASS

- ViewModel reads services through `ref.read(...)` lazily via getters (`_analytics`, `_reportFailure`), consistent with the existing Riverpod-3 generator style. No business logic leaked into widgets — the `error_shown`/`captureError` decisions for swallowed/handled failures live in the VM where they belong.
- Events fire at semantically correct moments: `list_viewed{cold}` only after a successful first render (a failed first page throws before the emit); `list_viewed{warm}` only on the browse re-entry; `search_performed` only when `query.isNotEmpty` after an `Ok` (so a filter/sort-only discovery doesn't masquerade as a search); `generation_selected` only on a positive selection. These guards are correct and individually tested.
- `_TabsState` correctly seeds `_reportedIndex` from the controller's initial index so the initial tab never counts as a change, and reports on settle (guarded by index equality), not per frame. Listener is removed in `dispose`. Resource management is clean.

### Naming & clarity — PASS

- `teCodeFor` / `teCodeForError`, `ListOrigin.cold/warm`, `DetailTab`, `ErrorShown`, `_reportFailure`, `_maybeReportTabChange`, `onShown` — all pass the 5-second rule.
- File `error_te_code.dart` matches its primary export (snake_case convention upheld).

### Null safety & error handling — PASS

- No force-unwraps introduced in logic paths. `_Tabs.build` uses `_controller!` but `_controller` is assigned in `didChangeDependencies` (which always runs before `build`), so it is non-null by construction — acceptable and pre-existing.
- `teCodeForError` handles the non-`Failure` / null error case explicitly (→ TE-07), exercised by tests.
- The `teCodeFor` switch is **exhaustive over the sealed `Failure` hierarchy** with no `default`, so adding a new `Failure` subtype is a compile error until a code is assigned — exactly the "keep analytics honest as the surface grows" property the doc comment claims. Verified against `failure.dart`: all 7 subtypes (`NetworkFailure`, `CacheFailure`, `NotFoundFailure`, `TimeoutFailure`, `ServerFailure`, `RateLimitFailure`, `ParsingFailure`) are covered.

### Lint suppressions — PASS

No new suppressions introduced by T-30b. (The `// ignore: invalid_use_of_internal_member` lines in the VM are pre-existing `copyWithPrevious` calls, not part of this slice.)

---

## Testing Quality (Pass 3)

**This is the strongest part of the PR.** Coverage is complete across all nine events, and the tests verify *behavior and exact payloads*, not implementation.

- **Recording fakes over mocks (`recording_observability.dart`).** The choice is well-justified in the file's own doc comment: `AnalyticsEvent`s are value-like with no `==`, so capturing them and asserting on `name`/`parameters` is clearer than matcher-based `verify` and needs no `registerFallbackValue`. `RecordingErrorReporter` captures the typed `failure` so tests can assert `isA<RateLimitFailure>()`. This is the right tool; it avoids the "mock everything, test nothing" anti-pattern.
- **Per-event property assertions (RNF-09 enforced in tests):** `search_performed` test explicitly asserts `{'result_count': 3}` and comments "the term never appears"; `filter_applied` asserts the presence-flag map; `pokemon_opened` asserts `id` + `primary_type` including the **skeleton → `unknown`** edge case. Each event's exact parameter map is pinned.
- **Failure paths covered, not just happy paths:** swallowed `loadMore` (asserts both `error_shown{TE-08}` AND `captureError` with typed failure), browse-refresh failure (asserts handled-failure capture), offline vs generic detail errors (TE-01 vs TE-07), offline/generic/stale list errors (TE-01/TE-07/TE-02).
- **Negative assertions:** `detail_tab_changed` asserts `isEmpty` for the initial tab before any tap; `generation_selected` asserts clearing does **not** emit a second event. These guard against over-emission — the failure mode a naive implementation would hit.
- **State-transition fidelity:** the `cold` → `warm` `list_viewed` test drives a real filter-then-clear transition and asserts the ordered `['cold', 'warm']` origins, exercising the actual `_enterBrowse` path rather than calling it directly.
- **`error_te_code_test.dart`** covers every subtype, the delegation path, and both non-Failure fallbacks (`'boom'` and `null`).

No tautologies, no assertion-free tests, no over-`verify`. Test quality bar: met.

**Coverage caveat:** the reviewer could not execute the suite in this environment (runner exit 69, environmental). The tests *appear* complete and correct by inspection; CI should be the gate of record.

---

## Simplicity & YAGNI Audit (Pass 4)

- **Lines that could be removed:** essentially none. The slice is tightly scoped to event wiring.
- **Unnecessary abstractions:** none. `error_te_code.dart` is two small pure functions, not a class hierarchy — appropriate. The `onShown` seam is a single nullable callback, not a listener/observer framework — minimal.
- **YAGNI violations:** none introduced. PostHog-host and other deferrals live in T-30a, correctly out of scope.
- **Right-sized:** no new providers, no new packages, no new state shape. The StatelessWidget→StatefulWidget conversions add exactly the `initState` needed for a once-per-mount fire — the minimum mechanism for "emit when this error first appears."
- **Complexity verdict: Already minimal.** The only readability tax is the cross-file reasoning about which site owns each `error_shown` emission (VM for swallowed `loadMore`; widget `onShown` for visible errors); the suggested comment at the refresh branches would fully retire it.

---

## Plan adherence (§6b)

| §6b AC | Status | Notes |
| --- | --- | --- |
| All 9 §12 events emit from §2.4 sites | ✅ | Verified each call site. |
| Each event has a test asserting RNF-09-safe properties | ✅ | Per-event parameter-map assertions; recording-fake pattern (the plan named `ProviderContainer.overrideWith` + mocktail; the equivalent recording-fake approach is used and is arguably cleaner — endorsed deviation). |
| Handled failures reported with TE code | ✅ | `_reportFailure` passes typed `failure:`; reporter records it. |
| `error_shown` fires for every §4.3 state incl. stale banner (TE-02) + swallowed loadMore | ✅ | All three covered by tests. |
| Adds no files to `lib/core/observability/` | ✅ | New files live under `features/.../analytics/` and `test/helpers/`. |
| DS widgets named in plan emit `error_shown` | ⚠️→✅ | **Deviation, for the better:** DS widgets stay observability-free via `onShown`; the caller emits. This is the correct layering and should be preserved. |

---

## Files reviewed

- `lib/features/pokemon/presentation/analytics/error_te_code.dart` (new)
- `lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart`
- `lib/features/pokemon/presentation/widgets/pokemon_card.dart`
- `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart`
- `lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart`
- `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart`
- `lib/core/ui/states/{offline_error_widget,generic_error_widget,stale_cache_banner}.dart`
- `test/helpers/recording_observability.dart` (new)
- `test/features/pokemon/presentation/analytics/error_te_code_test.dart` (new) + analytics additions to VM/card/detail/evolution/list-screen tests
- Context: `lib/core/observability/{analytics_event,error_reporter,observability_providers}.dart`, `lib/core/error/failure.dart`
