# Architecture Review — T-30a (Part 2: Observability Seam + Bootstrap)

**Reviewer:** VGV Architecture Review Agent
**Date:** 2026-05-29
**Branch:** `feature/quality-part1`
**Scope:** `lib/core/observability/**`, `lib/bootstrap.dart`, `lib/main.dart`, `lib/firebase_options.dart`, `pubspec.yaml`/`pubspec.lock`
**Plan:** `docs/plan/2026-05-28-feat-quality-and-release-plan.md` §6 / §6a — Decisions D-3, D-5, D-6, D-7
**Stack detected:** Flutter 3.44.0 single-package, feature-first layout · Riverpod 3 generators (`@riverpod`) · Freezed 3 · Drift · `very_good_analysis ^10` · mocktail · analyzer-9 pinned codegen line.

---

## Layer Separation

**Rule applied (D-5):** observability is a horizontal `lib/core/` concern. It may depend only on other `lib/core/` modules and external SDKs. It must NOT import `lib/features/**` (presentation/data) or `lib/app/**`. T-30b (presentation) will consume it; this part must not consume presentation.

### Findings

- **Violations found: 0.**

Verified by scanning every import in `lib/core/observability/**` and `lib/bootstrap.dart`:

- No `package:pokedex/features/...`, `package:pokedex/app/...`, or data-layer import appears anywhere in the observability tree (`grep` for `features|app|data` → NONE FOUND).
- The only intra-package import outside `observability/` is `package:pokedex/core/error/failure.dart`, consumed by `error_reporter.dart` and `sentry_error_reporter.dart`. `failure.dart` is a `lib/core/error/` primitive (`sealed class Failure implements Exception`) with **no internal imports** — a leaf in the dependency graph. Depending on it from `core/observability` is a lateral core→core dependency, which is correct and expected: the `ErrorReporter.captureError(..., {Failure? failure})` seam needs the typed-failure vocabulary to tag TE codes.
- `lib/bootstrap.dart` imports only `core/observability/**`, `firebase_options.dart`, and external SDKs (`firebase_core`, `firebase_analytics`, `sentry_flutter`, `flutter_riverpod`). `lib/main.dart` imports `app/app.dart` (the composition root) + `bootstrap.dart` — correct: the entrypoint is allowed to know the app widget.

**Direction confirmation (boundary with T-30b):** the architecture diagram in §6a.1 shows ViewModels/widgets (presentation) depending *inward* on `AnalyticsService` / `ErrorReporter`. The current code defines those interfaces in core with **zero** outward references to the consumers. The presentation→core arrow will be drawn entirely by T-30b. No leak.

**Clean files:** all 14 source files checked clean (3 interfaces/events, 3 sinks, 3 adapters, providers + generated part, bootstrap, main, firebase_options).

---

## State Management Assessment

State management here is the **DI seam itself** (Riverpod providers exposing the observability services), not feature state. Assessed against VGV conventions:

- **`observability_providers.dart` — Correct.**
  - **Naming:** descriptive (`analyticsServiceProvider`, `errorReporterProvider`, `ObservabilityConfig`, `buildAnalyticsSink`, `observabilityOverrides`). No generic `Manager`/`Handler`/`Service`-grab-bag naming. `AnalyticsService` is a precise role name, not a catch-all.
  - **Default = Noop (§4.2) — verified.** `analyticsService(Ref)` returns `const NoopAnalyticsSink()`; `errorReporter(Ref)` returns `const NoopErrorReporter()`. The provider test (`observability_providers_test.dart`) asserts a bare `ProviderContainer` reads `isA<NoopAnalyticsSink>()` / `isA<NoopErrorReporter>()`. This guarantees `flutter test` and any un-bootstrapped scope never emit. Correct and matches the plan's hard requirement.
  - **Immutability:** `ObservabilityConfig` is `@immutable` with all-`final` fields and a `const` constructor; `fromEnvironment()` is a pure read. No mutable state. Correct.
  - **Override lifecycle:** `observabilityOverrides()` returns `overrideWithValue(...)` overrides consumed once by `bootstrap()`'s root `ProviderScope`. Providers are `isAutoDispose: true` (generated). The injected sinks/reporters are stateless singletons (`const` where possible), so there is no disposal hazard. Correct.
  - **Testability seam:** `buildAnalyticsSink` takes `@visibleForTesting` `firebaseAdapter` / `posthogAdapter` factory params so the flag→sink selection logic is unit-testable without a live Firebase app. This is the right call — `FirebaseAnalytics.instance` would throw otherwise. Good engineering; the `@visibleForTesting` annotation correctly scopes the seam.
  - **Complexity match:** composite-sink + flag-driven selection is proportional to the "configure all, use one" requirement (D-7). Not over-engineered (no package split, per D-5); not under-engineered (vendor selection is real). Correct.

- **`bootstrap.dart` ownership model — Correct (C-2 resolved).** See Dependency Direction + the dedicated analysis below.

---

## Dependency Direction

- **Direction violations: 0.**
- **Circular dependencies: 0.**

Internal observability graph (all arrows point toward leaves):

```
bootstrap.dart ─┬─> observability_providers.dart ─┬─> adapters/* ─┐
                │                                  ├─> sinks/*     ├─> analytics_service.dart ─> analytics_event.dart
                │                                  └─> error_reporter.dart ─> core/error/failure.dart
                ├─> sentry_error_reporter.dart ────────────────────┘
                └─> firebase_options.dart
main.dart ─> bootstrap.dart + app/app.dart
```

- Interfaces (`analytics_service.dart`, `error_reporter.dart`) sit at the bottom and depend only on `analytics_event.dart` / `core/error/failure.dart`. Adapters and sinks depend *down* onto the interfaces. The composition layer (`observability_providers.dart`, `bootstrap.dart`) depends *down* onto everything. No file depends on a file that depends on it.
- `analytics_event.dart` is a pure leaf (only `package:meta`). `failure.dart` is a pure leaf (only `package:meta`). Healthy.
- No duplication: the single `ObservabilityConfig` is the one source of truth for the `--dart-define` surface, consumed by both providers and bootstrap.

**Clean dependencies:** all observability modules, bootstrap, main.

### Bootstrap ownership model (C-2) — detailed verification

The plan's single-owner requirement is the highest-risk architectural claim in this part. Verified against `bootstrap.dart`:

1. **Synchronous fallback before any `await` — confirmed.** Line 30 assigns `ErrorReporter reporter = const ConsoleErrorReporter();` *before* `runGuarded(...)` is awaited. The zone's error handler is `() => reporter` (passed as a lazy thunk), so even if `Firebase.initializeApp` / `SentryFlutter.init` throws, the zone has a live, non-null target. The `bootstrap_test.dart` `runGuarded routes an error thrown during init to the reporter` test exercises exactly this path (throws inside the body, asserts the spy captured it). AC met.

2. **Single hook ownership — confirmed, no double-install.**
   - **Keyed (Sentry) path:** `SentryFlutter.init(..., appRunner: () => _runApp(config, reporter = const SentryErrorReporter(), builder))`. Sentry installs its own `FlutterError.onError` + `PlatformDispatcher.onError` internally via `appRunner`. The code does **not** call `installCrashHandlers` on this path. Correct.
   - **Dark path:** `installCrashHandlers(reporter)` is called **only** in the `else` branch, then `_runApp`. Manual hooks own the framework/platform error routing here. Correct.
   - The two paths are mutually exclusive (`if (config.sentryDsn.isNotEmpty) {...} else {...}`). No path installs both. **No double-ownership.**

3. **Lazy reporter handover — subtle but correct.** `runGuarded` receives `() => reporter` (a closure over the captured local), not `reporter` by value. On the Sentry path, `reporter` is reassigned to `SentryErrorReporter()` *inside* `appRunner` before any post-init zone error could fire, so a late uncaught error routes to Sentry, not the stale console fallback. This is the intended design and it holds.

4. **Testable seams extracted from untestable orchestration.** `runGuarded` and `installCrashHandlers` are `@visibleForTesting` top-level functions; the untestable `bootstrap` body (real Firebase/Sentry/`runApp`) is wrapped in `// coverage:ignore-start/end`. This matches §6a.6 (line-level ignore, no directory exclusion). Both extracted seams have direct tests. Good separation.

---

## Package Structure

Single-package project (D-5: no package split for observability — YAGNI, consistent with feature-first layout). Assessed as a **module** within `lib/core/`:

- **`lib/core/observability/` — Complete.**
  - [x] Single, clear responsibility: instrumentation seam. Cleanly subdivided: interfaces at root, `sinks/` (analytics fan-out variants), `adapters/` (vendor glue). Logical and navigable.
  - [x] Interfaces split per D-6: `AnalyticsService` (product analytics) and `ErrorReporter` (crash reporting) are separate files/abstractions. The `one_member_abstracts` lint is suppressed with a documented rationale (polymorphic DI seam, many impls — not a callback). Justified.
  - [x] UI vs business logic separation: no widgets in this module; it is pure logic + DI. Correct.
  - [x] No unnecessary dependencies: only `core/error` laterally + external SDKs. Firebase/Sentry/PostHog imports are isolated to their respective adapter files (+ providers/bootstrap composition), not scattered.
  - [x] Test directory exists and mirrors source: `test/core/observability/{analytics_event_test, error_reporter_test, observability_providers_test, sinks/sinks_test}.dart` + `test/bootstrap_test.dart`. Coverage of seam logic is thorough: truth-table selection, RNF-09 whitelist, fan-out, Noop-under-test default, init-throws fallback, crash-hook routing.
  - [x] Linting: inherits `package:very_good_analysis/analysis_options.yaml`; generated `*.g.dart` excluded from analyzer. Per-file `// ignore` are documented.

- **`lib/firebase_options.dart` — Complete (with caveat).** Placeholder shape matches `flutterfire`-generated output; web-only with an `UnsupportedError` for other platforms; `coverage:ignore-file` applied as codegen-style boilerplate. Header clearly documents it must be regenerated before the T-31 prod deploy. Acceptable for T-30a (it is load-bearing only when `ANALYTICS_ENABLED=true`, which no debug/test path sets). Flagged below as a release-blocker reminder for T-31, not a T-30a defect.

### Dependency-resolution guardrail (§6a.3) — analyzer-9 pins held

Confirmed from `pubspec.lock` that adding the 4 observability SDKs did **not** perturb the pinned codegen line:

| Package | Required pin | Resolved in lock | Status |
| --- | --- | --- | --- |
| `analyzer` | 9.0.0 | **9.0.0** | held |
| `_fe_analyzer_shared` | (analyzer-9 line) | 92.0.0 | held |
| `source_gen` | (^4) | 4.2.3 | held |
| `drift_dev` | 2.31.0 (exact) | **2.31.0** | held |
| `freezed` | 3.2.5 (exact) | **3.2.5** | held |
| `riverpod_generator` | 4.0.3 (exact) | **4.0.3** | held |
| `firebase_core` | ^4.9.0 | 4.9.0 | resolved |
| `firebase_analytics` | ^12.4.1 | 12.4.1 | resolved |
| `sentry_flutter` | ^9.20.0 | 9.21.0 | resolved (patch bump, in-range) |
| `posthog_flutter` | ^5.25.1 | 5.25.1 | resolved |

All four analyzer-9 codegen pins (analyzer, drift_dev, freezed, riverpod_generator) are exactly where the plan fences them. The new SDKs are runtime deps and did not drag the analyzer line to a `-dev` build. AC met. (`sentry_flutter` floated 9.20.0→9.21.0 within its caret; harmless and unrelated to the codegen line.)

---

## Boundary with T-30b (no event emissions)

Confirmed this part ships the seam but **no emissions**:

- `AnalyticsEvent` defines all **9** constructors (`ListViewed`, `SearchPerformed`, `FilterApplied`, `SortChanged`, `GenerationSelected`, `PokemonOpened`, `DetailTabChanged`, `EvolutionNavigated`, `ErrorShown`) — matches PRD §12 / plan §2.4 one-for-one.
- No `logEvent(...)` / `captureError(...)` *call site* exists in `lib/features/**` or `lib/app/**` (those edits are T-30b's). The boundary is compile-enforced: T-30a *defines* the constructors; T-30b *calls* them. Verified there are no producer call sites in this changeset.
- **RNF-09 enforcement is type-level (D-3 / §6a.5):** every event exposes only whitelisted, non-PII fields via typed constructors; there is no free-form `Map<String, Object>` passthrough. `SearchPerformed` exposes `result_count` only — `analytics_event_test.dart` explicitly asserts the params contain neither `term` nor `query`. Firebase consent is anonymized in `bootstrap()` (ad/ad-personalization/ad-user-data signals off, analytics-storage on) using the named-boolean API (the load-bearing API correction from §2.3). Correct.

---

## Observations (non-blocking, for awareness)

These are not layering/architecture violations; recorded so they are not lost.

- **[Suggestion] `SentryErrorReporter` discards the `failure` argument.** `captureError(error, stackTrace, {Failure? failure})` imports `Failure` but never tags the Sentry event with the TE code (the body only calls `Sentry.captureException(error, ...)`). The `failure`→TE tagging is described as a "caller concern wired in T-30b" in the `ErrorShown` doc, but the *reporter* is where a Sentry tag/context would naturally attach. Not a T-30a defect (the body is `coverage:ignore` SDK glue and the seam is honored), but worth a TODO so the TE code actually reaches Sentry when T-30b wires it. Track in T-30b.
- **[Suggestion] `CompositeAnalyticsSink.logEvent` has no per-sink try/catch.** If one sink throws, the fan-out loop aborts and later sinks miss the event; the throw would also propagate to the caller despite the `AnalyticsService` doc promising "never throws into the caller." In practice the only real sinks are `unawaited(...)` SDK forwards (won't throw synchronously) and the console/noop sinks, so the risk is low today. Consider wrapping each `sink.logEvent(event)` in a guard when live vendors are exercised. Non-blocking for T-30a.
- **[Suggestion] `firebase_options.dart` is a committed placeholder.** Correct for T-30a, but it is a hard release-blocker for T-31: production analytics with `PLACEHOLDER_*` values will fail to initialize. The header documents this and §11 of the plan lists the `flutterfire configure` action item. Ensure the T-31 PR regenerates it before the go-to-prod gate.

---

## Verdict

**Architecture is clean. Ready to merge (T-30a scope).**

- Layer separation: 0 violations. Observability is correctly isolated in `lib/core/`, depends only laterally on the `core/error` leaf, and leaks no presentation/data/app imports.
- Dependency direction: 0 violations, 0 cycles. The presentation→core consumption arrow is deferred to T-30b exactly as planned.
- Bootstrap ownership (C-2): single-owner model holds — sync fallback before any await, mutually exclusive Sentry-vs-manual hook installation, lazy reporter handover. Tested.
- State/DI seam: Noop default verified; immutable config; testable selection seam; correct override lifecycle.
- Analyzer-9 codegen pins (analyzer 9.0.0 / drift_dev 2.31.0 / freezed 3.2.5 / riverpod_generator 4.0.3): all held after adding 4 SDKs.
- No event emissions ship; all 9 constructors defined; RNF-09 enforced at the type level.

**Critical: 0 · Important: 0 · Suggestions: 3** (Sentry `failure` tagging, composite fan-out resilience, firebase_options placeholder regeneration) — none block this merge; the first two are T-30b/follow-up items, the third is a T-31 release-gate reminder.

> Note: the task states the local test runner is broken; this review was performed by reading source and tests only. Test *existence and assertions* were verified by reading the files, but their *passing* was not executed.
