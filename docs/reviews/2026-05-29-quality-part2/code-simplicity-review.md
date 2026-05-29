# Code Simplicity Review — T-30a (Part 2: Observability Seam + Bootstrap)

**Date:** 2026-05-29
**Branch:** `feature/quality-part1`
**Reviewer:** Claude (code-simplicity agent)
**Scope:** `lib/core/observability/`, `lib/bootstrap.dart`, `lib/main.dart`, `lib/firebase_options.dart`, `test/core/observability/`, `test/bootstrap_test.dart`, pubspec deps

---

## Simplification Analysis

### Core Purpose

Bootstrap the app inside a guarded error zone, wire two observability sinks (analytics + crash reporting) whose concrete implementations are selected by compile-time flags, and provide a typed event catalogue that prevents PII leakage into analytics backends.

---

### Unnecessary Complexity Found

None identified. Every file has a clear, narrow purpose that traces back to a concrete requirement in the plan. See the section-by-section justifications below before examining individual findings.

---

### Section-by-Section Assessment

#### 1. `@visibleForTesting` seams: `runGuarded`, `installCrashHandlers`, `buildAnalyticsSink` factories

**Verdict: justified — not over-built.**

`runGuarded` and `installCrashHandlers` are extracted from `bootstrap()` specifically because `bootstrap()` itself contains real Firebase and Sentry SDK calls that cannot execute under `flutter test`. The extraction is the minimal change that makes the zone wiring and crash-hook installation verifiable at all. Both functions are small (6–8 lines), have a single logical purpose, and their tests (`bootstrap_test.dart`) cover a concrete correctness risk — C-2 (a throw before `runApp` must still reach the reporter). Collapsing them back into `bootstrap()` and losing the tests would be a regression against a documented concern, not a simplification.

`buildAnalyticsSink` carries `@visibleForTesting` adapter factories for the same structural reason: `FirebaseAnalytics.instance` throws `StateError` without a live `Firebase.initializeApp()` call, making the truth-table selection logic (§4.2) untestable without a seam. The factory pattern is the lightest possible injection — two optional named parameters, each defaulting to the real constructor — and the tests exercise exactly the six meaningful combinations of `analyticsEnabled × posthogKey`. This is the exact scope the factories need to cover. A heavier solution (a full injectable `ObservabilityFactory` class, or moving adapters behind a platform interface) would be YAGNI.

**No action required.**

#### 2. Sealed `AnalyticsEvent` + 9 subclasses

**Verdict: appropriately minimal.**

The sealed hierarchy is spec-driven, not speculative. All nine events are listed in PRD §12 and mapped to concrete call sites in the plan's §2.4. No additional events are pre-declared, no generic passthrough mechanism exists, and each subclass is as small as the contract allows (named fields + `name` + `parameters`). The `sealed` keyword is load-bearing for two reasons: it guarantees exhaustive `switch` coverage at future T-30b call sites, and it enforces the no-free-passthrough invariant (an event can only carry the specific properties its constructor declares, satisfying RNF-09). The supporting enums `ListOrigin` and `DetailTab` are likewise the minimum needed to express the typed values without falling back to untyped strings. The test coverage in `analytics_event_test.dart` is proportionate — one test per constructor, plus the contract test for non-null parameter values.

**No action required.**

#### 3. `NoopErrorReporter` + `ConsoleErrorReporter` co-located in `error_reporter.dart`

**Verdict: correct placement.**

Co-locating Noop and Console implementations with the `ErrorReporter` interface follows the same pattern as `noop_sink.dart` and `console_sink.dart` for analytics. The difference is that the analytics interface (`analytics_service.dart`) keeps its implementations in a separate `sinks/` directory. This minor asymmetry is worth noting but is not a simplicity problem — it is a consequence of the analytics side having a third concrete type (the composite) that warrants its own directory, while the error reporter side has no equivalent grouping reason. Splitting Noop and Console into separate files under a `reporters/` directory would add structure without adding clarity.

**No action required.**

#### 4. `ObservabilityConfig.firebaseEnabled` computed property

**Verdict: a minor redundancy worth noting.**

`firebaseEnabled` is defined as `bool get firebaseEnabled => analyticsEnabled;` (line 65 of `observability_providers.dart`). It is used in `bootstrap.dart` (line 35) and `buildAnalyticsSink` (line 101). The property is an alias for `analyticsEnabled` with no independent logic, no separate flag gate, and no documented plan to diverge. The comment "Firebase ships on whenever analytics is enabled (§4.1)" confirms this is intentional but also confirms there is no content beyond the alias.

The alias has marginal value: it names the intent at the call site (`if (config.firebaseEnabled)` reads more specifically than `if (config.analyticsEnabled)`). However, if Firebase and analytics ever do diverge they would need separate `--dart-define` flags, not just a renamed property — the alias would be deleted, not modified. The alias therefore provides call-site readability today at the cost of a layer of indirection that cannot evolve meaningfully.

**Suggestion (non-blocking):** inline `config.analyticsEnabled` at both call sites and remove `firebaseEnabled`. Save 3 lines. The comment explaining the coupling can move to the call site in `buildAnalyticsSink` if the intent needs to be documented.

#### 5. `PostHog dark` log branch in `buildAnalyticsSink`

**Verdict: one-sided logging — minor inconsistency.**

Lines 106–108 of `observability_providers.dart` log a notice when PostHog is dark (analytics on, no key). Firebase has no equivalent notice when it is off (`!config.firebaseEnabled`). The plan says "a dark vendor logs a one-line notice rather than silently disappearing," but this rule is only applied to PostHog. On the analytics-off path, Firebase disappears silently. This is a small documentation inconsistency, not a simplicity problem. No additional code is needed — the PostHog log could be removed to make the behaviour uniform (all-silent), or a Firebase notice added. Either direction is fine; the current asymmetry is mildly confusing when reading the debug log.

**Suggestion (non-blocking):** for consistency, either add a `developer.log('Firebase dark (ANALYTICS_ENABLED=false)', ...)` in the `!config.firebaseEnabled` branch, or remove the PostHog notice and let both vendors go dark silently. The all-silent path is simpler.

#### 6. `_runApp` private helper in `bootstrap.dart`

**Verdict: justified extraction.**

`_runApp` (lines 62–73) is called from two places inside the `coverage:ignore` block: the Sentry branch and the dark-path branch. The extraction avoids repeating the `ProviderScope(overrides: [...]) / runApp(...)` call twice and is the only way to avoid the duplication without restructuring the if/else. Given the body is 6 lines and is called twice, the extraction is warranted.

**No action required.**

#### 7. `firebase_options.dart` placeholder

**Verdict: appropriate for the current phase.**

The file is clearly documented as a placeholder pending `flutterfire configure` and is excluded from coverage. It correctly throws for non-web platforms, matching the shape `flutterfire configure` generates. No code is wasted here.

**No action required.**

#### 8. `_RecordingSink` duplication across test files

**Verdict: minor, low-priority test-code duplication.**

`_RecordingSink` is defined identically in two test files: `test/core/observability/sinks/sinks_test.dart` (lines 9–14) and `test/core/observability/observability_providers_test.dart` (lines 11–16). In both cases it is a 6-line private class. The duplication is not dangerous and the files are in different test groups, but a shared `test/core/observability/helpers.dart` (or promoting to a package-visible test helper) would remove the duplication. This is a test-quality concern, not a production-code concern.

**Suggestion (low priority):** extract `_RecordingSink` into a shared test helper at `test/core/observability/recording_sink.dart` and import it from both tests. Saves 6 lines.

#### 9. `SentryErrorReporter` does not use the `failure` parameter

**Verdict: acceptable gap, documented for T-30b.**

`SentryErrorReporter.captureError` receives a `Failure?` but only passes the raw exception to `Sentry.captureException` (line 20 of `sentry_error_reporter.dart`). The `failure` field — which carries the PRD TE code — is silently dropped. The plan notes "the failure→TE mapping is a caller concern wired in T-30b (§4.3)," which partially covers this, but the Sentry adapter is the only place where a TE-tagged hint could be sent to Sentry as a tag or fingerprint. If this is intentionally deferred, it should be marked with a `// TODO(T-30b)` comment. If it is an oversight, the adapter should add the hint now since it is trivial (`Sentry.captureException(error, stackTrace: stackTrace, hint: Hint.withMap({'te_code': failure?.message}))`). The body is already coverage-excluded, so no test changes would be needed.

**Important:** add a `// TODO(T-30b)` comment on the `failure` parameter in `SentryErrorReporter.captureError`, or pass a Sentry `Hint` with the TE code now. The current silent drop makes the `failure` parameter useless to Sentry, which reduces the diagnostic value of the adapter.

#### 10. `posthogHost` in `ObservabilityConfig` is stored but never used in T-30a

**Verdict: YAGNI flag — low severity.**

`ObservabilityConfig` stores and documents `posthogHost` (lines 56–58 and 39–44), and `PostHogAdapter` uses `Posthog().capture(...)` without passing the host anywhere. PostHog initialization with a custom host is a T-30b or T-31 concern — the `posthog_flutter` SDK requires calling `Posthog.setup(key, options)` somewhere during startup to apply a custom host. As implemented, the field is read from `--dart-define` and stored but never consumed. Since `PostHogAdapter` calls `Posthog()` directly (which uses whatever was configured at init time), the custom host only applies if PostHog is initialized elsewhere, which T-30a does not do.

This is not a simplicity problem per se (the field is one line), but it is a correctness risk: developers reading the config will assume `posthogHost` is applied, when in fact it is not hooked up. Either hook it up (add a `Posthog.setup(...)` call in `bootstrap()`) or annotate the field with `// TODO(T-31): pass to Posthog.setup() in bootstrap`.

**Important:** document that `posthogHost` is not yet applied to `PostHogAdapter`, or apply it now. The current state is silent dead config.

---

### Code to Remove

| File | Lines | Reason | Estimated LOC reduction |
|---|---|---|---|
| `observability_providers.dart` | 65 | `firebaseEnabled` alias for `analyticsEnabled` | 3 lines |
| `sinks/sinks_test.dart` | 9–14 | `_RecordingSink` duplicated from `observability_providers_test.dart` | 6 lines (test only) |
| `observability_providers.dart` | 106–108 | PostHog dark notice (if going all-silent for consistency) | 3 lines |

Total production LOC removable: ~3 lines (the alias). Optionally ~3 more (dark notice), and 6 test-only lines.

---

### Simplification Recommendations

1. **Remove `firebaseEnabled` alias** (non-blocking)
   - Current: `bool get firebaseEnabled => analyticsEnabled;` + two call sites using `config.firebaseEnabled`
   - Proposed: inline `config.analyticsEnabled` at both call sites; add an inline comment at `buildAnalyticsSink` if the Firebase-always-follows-analytics invariant needs documenting
   - Impact: -3 LOC, one less layer of indirection, no loss of clarity

2. **Normalize dark-vendor logging** (non-blocking)
   - Current: PostHog logs a notice when dark; Firebase does not
   - Proposed: either add a symmetric Firebase notice, or remove the PostHog notice (simpler)
   - Impact: ±0 to -3 LOC; consistency improvement

3. **Extract shared `_RecordingSink` test helper** (low priority)
   - Current: identical 6-line class in two test files
   - Proposed: `test/core/observability/recording_sink.dart`, imported in both
   - Impact: -6 test LOC, single definition to maintain

---

### YAGNI Violations

None. Every component in scope has a concrete, imminent consumer either in T-30a itself or in T-30b (which is the next PR in the same epic). No forward-speculative abstractions or extensibility points without immediate use cases were found.

---

### Correctness Concerns (not YAGNI, but worth flagging)

These are not simplicity issues but emerged during the review and affect correctness:

1. **`SentryErrorReporter` drops `Failure`** — the `failure` parameter is received but not forwarded to Sentry. This reduces diagnostic value. Add a `TODO(T-30b)` or forward the hint now. (Important)

2. **`posthogHost` is stored but never applied** — `ObservabilityConfig` reads `POSTHOG_HOST` from `--dart-define` but `PostHogAdapter` does not use it. This is silent dead configuration that will confuse readers. Add a `TODO(T-31)` comment or hook up `Posthog.setup()` now. (Important)

---

### Final Assessment

Total potential LOC reduction: ~1% (3 production lines from the `firebaseEnabled` alias; 6 test lines from the recording-sink duplication)

Complexity score: **Low** — the implementation is well-scoped, directly traceable to plan decisions, and avoids speculative abstraction throughout.

Recommended action: **Ready to merge with two documentation/correctness annotations** — add `TODO` comments on the `failure` drop in `SentryErrorReporter` and the unused `posthogHost` field. The `firebaseEnabled` alias and logging asymmetry are minor quality nits, not blockers.
