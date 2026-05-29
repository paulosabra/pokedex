# Test Quality Review — T-30a: Observability Seam + Bootstrap

**Date:** 2026-05-29
**Branch:** `feature/quality-part1`
**Scope:** `test/core/observability/**`, `test/bootstrap_test.dart`, `lib/core/observability/**`, `lib/bootstrap.dart`
**Plan ref:** `docs/plan/2026-05-28-feat-quality-and-release-plan.md` §6a.6–§6a.7

> Tests not executed (local runner broken). Review conducted by reading all source
> and test files. The CI gate (`flutter test --coverage` + lcov strip + awk ≥80%)
> is the authoritative runner.

---

## Test Quality Review

### Coverage Summary

- **Test run:** Not executed (local runner broken — reviewed by reading)
- **Coverage:** Not measured; estimated adequate based on ignore-region audit (see §Coverage Interaction)
- **Files with tests:** 5 / 5 targeted implementation files have corresponding test files
- **Missing test files:** None for the seam logic. All three adapters
  (`firebase_analytics_adapter.dart`, `posthog_adapter.dart`,
  `sentry_error_reporter.dart`) are intentionally untested — every testable line is
  inside a `// coverage:ignore-start … // coverage:ignore-end` block. The
  `bootstrap()` top-level orchestration is inside a `// coverage:ignore-start …
  // coverage:ignore-end` block spanning lines 28–74.

#### Coverage Interaction Assessment

The plan's §6a.6 strategy is correctly applied:

- Adapter bodies (`firebase_analytics_adapter.dart` lines 22–26,
  `posthog_adapter.dart` lines 22–27, `sentry_error_reporter.dart` lines 19–21)
  are narrow, one-statement SDK forwards. Their `coverage:ignore` blocks wrap only
  the genuinely untestable `unawaited(sdk.call(...))` line — not entire classes or
  files. This is appropriate narrow exclusion.
- `bootstrap()` (lines 28–74) wraps the entire orchestration body including
  Firebase init, Sentry init, and `runApp` — all of which require live SDKs. The
  exclusion is declared at the top-level function boundary, which is the correct
  unit. The companion `@visibleForTesting` functions `runGuarded` and
  `installCrashHandlers` (lines 76–100) are outside the ignore block and are both
  tested. This is the planned pattern from §6a.6.
- `firebase_options.dart` carries `// coverage:ignore-file`. It is placeholder
  boilerplate analogous to codegen and the rationale is documented inline. The lcov
  strip step only removes four generated globs (`*.g.dart`, `*.freezed.dart`,
  `*.drift.dart`, `*.config.dart`) — `firebase_options.dart` is **not** in those
  globs. However, because the file carries `// coverage:ignore-file`, lcov's own
  ignore processing will exclude it at the line level before the gate's awk check.
  This correctly keeps the file out of the denominator without a directory-level
  exclusion. No plan violation.
- The `observability_providers.g.dart` generated file is stripped by the `*.g.dart`
  glob. No action needed.

**Estimated post-exclusion impact:** The newly-added hand-written lines are almost
entirely covered by the five test files. The uncovered lines (adapter SDK calls +
`bootstrap()` orchestration) are all inside `coverage:ignore` blocks. The 94.8%
pre-T-30a baseline should be maintained or marginally reduced within the 14.8-point
margin; the ≥80% gate should remain green.

---

### Acceptance Criteria (§6a.7) Coverage

| AC | Status | Notes |
|----|--------|-------|
| `AnalyticsService` and `ErrorReporter` are separate interfaces; `AnalyticsEvent` defines all 9 constructors | **Pass** | `analytics_service.dart`, `error_reporter.dart` are distinct. `analytics_event_test.dart` exercises all 9 constructors individually. |
| `bootstrap()` installs crash capture: FlutterError + PlatformDispatcher + guarded zone; init-throw → fallback reporter | **Pass with gap** | `runGuarded` and `installCrashHandlers` are tested. However, the test does not verify that `runGuarded` composes correctly with the fallback reporter prior to any async init work — see Finding I-1. |
| Sentry vs manual hook ownership is single (no double-install); documented | **Pass** | `bootstrap.dart` comment documents the ownership split. No test is practical here (Sentry init requires live SDK), and `bootstrap()` is inside the ignore block. Acceptable. |
| No PII (RNF-09); Firebase ad signals disabled; test asserts no-PII whitelist | **Partial — see C-1** | `analytics_event_test.dart` correctly asserts `search_performed` does not expose `term`/`query`. However, the AC also requires "Firebase ad signals disabled" to be asserted; no test verifies that `bootstrap()` calls `setConsent` with `adStorageConsentGranted: false`. This is in the ignore block so it cannot be tested directly, but the plan's AC is not closed. |
| Sink selection matches §4.2 truth table; NoopSink under `flutter test` | **Pass with gap** | Three of five table rows are exercised; the `flutter test → Noop` and `debug → Console` rows are confirmed. However, the `release/prod` row (Console absent when `kReleaseMode=true`) cannot be flipped on the VM. The test group docstring acknowledges this but does not add an explicit assertion; see Finding I-2. |
| Missing/empty `SENTRY_DSN`/`POSTHOG_KEY` → adapter dark **and logs a notice** | **Partial — see I-3** | The `PostHog dark` `developer.log` branch exists in `buildAnalyticsSink` (line 107) but no test captures or asserts the log message. `Sentry dark` is in the ignore block so untestable, but `PostHog dark` is testable. |
| `firebase_options.dart` committed (web) | **Pass** | File exists with placeholder values and `coverage:ignore-file`. |
| `pubspec.lock` analyzer/codegen pins unchanged | **Out of scope for this review** | Dependency audit is a CI/lock-file concern, not a test quality concern. |
| No directory-level coverage exclusion for `adapters/` | **Pass** | Confirmed: only line-level `coverage:ignore-start … coverage:ignore-end` blocks inside method bodies. No `lcov --remove` entry for an `adapters/` path. |

---

### Analytics Event Test Quality (`analytics_event_test.dart`)

**Overall: Good. Meaningful assertions throughout.**

- All 9 events are tested individually with exact `parameters` map equality — not
  just `isNotNull` or `isNotEmpty`. These are strong behavioral assertions.
- **RNF-09 assertion** is present and meaningful: the test checks
  `event.parameters.keys` does not contain `'term'` or `'query'`. This is a true
  negative assertion that would catch a future regression where a developer adds a
  raw query field. The test name reads like a specification.
- **`all parameter values are non-null`** test (line 74–90) exercises all 9 events
  in a loop. The assertions `isNotEmpty` and `everyElement(isNotNull)` are
  meaningful as a Firebase/PostHog contract check.
- **Finding S-1 (Suggestion):** `DetailTab.stats` is never tested for its
  serialized string value. The dedicated `DetailTabChanged` test uses
  `DetailTab.evolution`; the bulk test uses `DetailTab.about`. `DetailTab.stats`
  → `'stats'` is implicitly covered by `enum.name` behavior, but an explicit entry
  would make the spec complete.
- **Finding S-2 (Suggestion):** `ListOrigin.cold` is only exercised in the bulk
  non-null test, not in the dedicated `ListViewed` mapping test (which uses
  `ListOrigin.warm`). An additional assertion `expect(event.parameters['origin'], 'cold')` for `ListOrigin.cold` in the dedicated test would close the gap.
- No tautological assertions. No implementation mirroring.

---

### Sink Test Quality (`sinks/sinks_test.dart`)

**Overall: Adequate for the scope; one weak assertion on console and noop.**

- **`CompositeAnalyticsSink` fan-out test**: strong — uses two `_RecordingSink`
  instances and asserts both received the exact event, including order. The empty-list
  no-op test confirms the safe default. Good.
- **`NoopAnalyticsSink`**: tested with `returnsNormally`. This is a smoke test for a
  trivially-empty method body. Not tautological (it would catch a throw), but it
  cannot fail on logic regressions. Acceptable for a no-op.
- **`ConsoleAnalyticsSink`**: tested with `returnsNormally`. Same verdict as
  `NoopAnalyticsSink`. The actual logging behavior (`developer.log` output) is not
  captured. This is acceptable because `developer.log` output is not meaningfully
  assertable in unit tests without a custom zone or log handler. The test's purpose
  is crash-free execution, which it confirms.
- **Finding I-2 (Important):** The test group comment states "debug → Console always
  present" but neither `sinks_test.dart` nor `observability_providers_test.dart`
  asserts that `ConsoleAnalyticsSink` is **actually present in the composite** when
  `kReleaseMode` is false. Since `kReleaseMode` is always `false` on the VM during
  tests, a test that calls `buildAnalyticsSink` with any config and then verifies
  the returned composite contains a `ConsoleAnalyticsSink` instance would be both
  meaningful and always passable. Without it, a developer could accidentally remove
  the `if (!kReleaseMode)` guard and no test would catch it.

---

### Error Reporter Test Quality (`error_reporter_test.dart`)

**Overall: Adequate. Covers both implementations.**

- `NoopErrorReporter` tested with `returnsNormally` — appropriate for a
  trivially-empty body.
- `ConsoleErrorReporter` is tested in two paths: without a `failure` and with a
  `failure` carrying a `NetworkFailure`. This exercises the conditional branch in
  the log message (`failure == null ? 'error' : 'error (${failure.message})'`). The
  assertions use `returnsNormally`, which is correct since the output is
  `developer.log`.
- **Only `NetworkFailure` is tested** as the `failure` argument. The production
  code accepts any `Failure?`. While the branch is binary (`null` vs non-null), a
  second concrete failure type (e.g., `CacheFailure`) would confirm the `message`
  accessor is stable across the sealed hierarchy.
- **Finding S-3 (Suggestion):** Add a test for `ConsoleErrorReporter` with a
  `null` `stackTrace` to confirm the nullable stack trace is handled (the
  implementation passes it through to `developer.log` which accepts null). Currently
  the `stack` variable is assigned `StackTrace.current` (non-null) in both tests.

---

### Observability Providers Test Quality (`observability_providers_test.dart`)

**Overall: Good architecture (injected fakes, ProviderContainer teardown). Two gaps.**

- **`ObservabilityConfig.fromEnvironment` defaults**: tests all five fields
  including `firebaseEnabled` derivation (`analyticsEnabled` defaults to false →
  `firebaseEnabled` false). Precise equality checks on each field. Strong.
- **`buildAnalyticsSink` truth table**: three scenarios covered using injected
  `_RecordingSink` fakes for both Firebase and PostHog adapters. The `firebaseAdapter`
  and `posthogAdapter` factories are `@visibleForTesting` parameters, which is the
  correct seam. Assertions are on recorded events (behavioral), not mock call
  counts (implementation). No over-verification.
- **`ProviderContainer` teardown** with `addTearDown(container.dispose)` is present
  in both provider tests. Correct.
- **Finding I-2 (repeat):** Truth table row "debug run, analytics off → ConsoleSink"
  (§4.2 second row): tests confirm Firebase and PostHog are absent when analytics is
  off, but no assertion checks that `ConsoleAnalyticsSink` was included in the
  composite. An event dispatched through `buildAnalyticsSink(_config())` reaches the
  console in production, but this is never verified in a test.
- **Finding I-3 (Important):** The `buildAnalyticsSink` test for "analytics on, no
  key" (line 59) exercises the branch that calls `developer.log('PostHog dark …')`.
  This branch is live testable code (outside any `coverage:ignore`), but the log
  emission is never asserted. While the `developer.log` content is not a behavioral
  contract, the plan's §6a.7 AC states "Missing/empty POSTHOG_KEY ⇒ adapter dark
  **and logs a notice**." A test using `dart:developer`'s zone logging or simply
  verifying the branch is reached (the existing test structure already does this
  implicitly because `posthog.events` is empty) partially satisfies this, but the
  "logs a notice" behavior itself has no assertion.
- **Finding C-1 (Critical):** The AC "Firebase ad signals disabled; test asserts
  the no-PII whitelist" (§6a.7 bullet 4) is only half-satisfied. The
  `search_performed` no-PII assertion covers the event property whitelist. However,
  the Firebase consent call (`setConsent(adStorageConsentGranted: false, ...)`) is
  inside the `// coverage:ignore` block and cannot be tested directly. **The plan
  text says "test asserts" this**, not "the code asserts" it. Given the ignore block
  is correctly placed, the resolution is to either: (a) add a comment to the AC
  noting it is verified by code review rather than a test, acknowledging the
  constraint, or (b) move the `setConsent` call out of `bootstrap()` into a
  testable function with `@visibleForTesting` (similar to `installCrashHandlers`).
  As written, the AC is technically unmet.
- **Finding I-4 (Important):** `observabilityOverrides` (line 115 of
  `observability_providers.dart`) calls `buildAnalyticsSink(config)` without the
  `firebaseAdapter`/`posthogAdapter` factory injection. In tests, `_config()` has
  `analyticsEnabled: false`, so `makeFirebase()` is never called — the test passes
  today. But if someone writes a test that passes an analytics-enabled config to
  `observabilityOverrides`, `FirebaseAnalytics.instance` would throw without a live
  Firebase app. The `observabilityOverrides` function should accept the same
  `@visibleForTesting` factory parameters as `buildAnalyticsSink`, or the test
  should document the precondition that the config must have `analyticsEnabled:
  false` for safe use in tests.

---

### Bootstrap Test Quality (`bootstrap_test.dart`)

**Overall: Good. Covers the two testable extraction points. One behavioral gap.**

- `TestWidgetsFlutterBinding.ensureInitialized()` is correctly called at the top
  level to ensure Flutter binding is ready before `PlatformDispatcher` is accessed.
- **`runGuarded` test**: throws a `StateError` inside the guarded zone body and
  asserts `spy.errors` contains the error. This directly tests the C-2 requirement
  (uncaught zone errors reach the fallback reporter). The `await` on `runGuarded`
  is correct; without it, the assertion would run before the zone error handler
  fires. Meaningful assertion.
- **`installCrashHandlers` test**: installs handlers, fires both `FlutterError.onError`
  and `PlatformDispatcher.instance.onError`, asserts both reach the spy. Verifies
  `PlatformDispatcher.onError` returns `true` (the `handled` flag). Teardown
  correctly restores previous handlers. This is a complete, well-structured test.
- **Finding I-1 (Important):** The `runGuarded` test verifies an error thrown
  **inside** the zone body reaches the reporter. But the C-2 scenario in the plan
  is specifically about an error thrown **before** `runApp` (e.g., during Firebase
  init) being caught by the fallback reporter that was assigned **before** the zone.
  The current test passes `() => reporter` as the `reporter` factory, so the spy is
  already constructed before the zone runs — the lazy-read pattern is not exercised.
  A complementary test that mutates the reporter via the closure (simulating the
  `reporter = SentryErrorReporter()` assignment on the Sentry path) would verify
  the lazy-capture contract: that a zone error occurring after a reporter swap
  reaches the **new** reporter, not the initial one.
- **Finding S-4 (Suggestion):** There is no test for the case where `runGuarded`
  itself receives a non-async error (i.e., a synchronous throw from `body`). The
  body is `Future<void> Function()`, so a `throw` becomes an async error in the
  zone. This is correctly covered by `() async => throw boom`. No gap here — this
  note is informational.

---

### Anti-Patterns Found

| Location | Anti-Pattern | Issue | Fix |
|----------|-------------|-------|-----|
| `sinks_test.dart:40–44` | Smoke assertion only | `ConsoleAnalyticsSink` and `NoopAnalyticsSink` are tested only with `returnsNormally` — no assertion that the event was processed or dropped | Acceptable for no-ops; document intent in comment so a reader understands the test is a crash-guard, not a behavioral assertion |
| `observability_providers_test.dart:97–110` | Type-only assertion | `observabilityOverrides` test asserts `isA<CompositeAnalyticsSink>()` but not that the composite contains the expected sinks | Low severity for a providers-wiring test, but the assertion could be strengthened by dispatching an event and checking a recording fake receives it |
| `observability_providers_test.dart:119` (production code) | Missing injection seam | `observabilityOverrides` calls `buildAnalyticsSink(config)` without exposing the `@visibleForTesting` factory params, making analytics-enabled configs unsafe to use in provider tests | Expose the factory params in `observabilityOverrides` or document the safe-test precondition |

---

### RNF-09 No-Term Assertion — Detailed Assessment

The RNF-09 `search_performed` assertion in `analytics_event_test.dart` (lines 12–21):

```dart
expect(event.parameters.keys, isNot(contains('term')));
expect(event.parameters.keys, isNot(contains('query')));
```

**Verdict: Meaningful, not tautological.** The assertion checks that specific
forbidden keys are absent. A future developer adding `'search_term': query` to
`SearchPerformed.parameters` would cause this test to fail with a clear message.
The test name correctly reads as a specification.

**Gap:** The assertion does not check for other potential PII vectors such as
`'text'`, `'input'`, or `'keyword'`. While not required by the current plan, the
test could be strengthened with a positive assertion: `expect(event.parameters.keys,
{'result_count'})` — asserting the exact, exhaustive set of keys rather than only
the two forbidden ones. This would catch any new free-text field regardless of its
name. This is a suggestion, not a critical finding.

---

### §4.2 Truth Table Coverage Assessment

The §4.2 table has five rows:

| Row | Context | Tested? | Notes |
|-----|---------|---------|-------|
| 1 | `flutter test` → Noop only | **Yes** | `providers` group, "default sinks are no-ops" |
| 2 | debug, analytics off → Console | **Partial** | Firebase/PostHog absence asserted; Console presence not asserted |
| 3 | debug, analytics on + Firebase | **Partial** | Firebase presence asserted via recording fake; Console presence not asserted |
| 4 | release/prod, analytics on + Firebase (no Console) | **Not testable** | `kReleaseMode` is always false on VM; acknowledged in docstring |
| 5 | preview, analytics off or preview keys | **Partially** | Covered by row 1 and row 3 equivalents; no distinct preview scenario |

The critical untestable row (4) is correctly acknowledged in the group description.
The partial rows (2, 3) are the I-2 finding — Console presence is never positively
asserted in any test.

---

### Coverage Ignore Region Appropriateness

| File | Ignore scope | Appropriate? | Reasoning |
|------|-------------|-------------|-----------|
| `bootstrap.dart` lines 28–74 | `bootstrap()` full body | **Yes** | Contains real Firebase init (`Firebase.initializeApp`), Sentry init (`SentryFlutter.init`), and `runApp` — all require live SDKs. `runGuarded` and `installCrashHandlers` are extracted outside and tested. |
| `firebase_analytics_adapter.dart` lines 22–26 | `unawaited(_analytics.logEvent(...))` | **Yes** | Single SDK call inside a method; the adapter class and method declaration are visible to coverage; only the body call is excluded. |
| `posthog_adapter.dart` lines 22–27 | `if (kIsWeb) return;` + SDK call | **Borderline** | The `kIsWeb` guard is testable logic (always `false` on VM → branch is always skipped in tests), but it wraps an untestable SDK call. Excluding both together is pragmatic but slightly over-broad. Acceptable given PostHog is dark for MVP. |
| `sentry_error_reporter.dart` lines 19–21 | `unawaited(Sentry.captureException(...))` | **Yes** | Single SDK call; same reasoning as Firebase adapter. |
| `firebase_options.dart` | Entire file | **Yes** | Config boilerplate analogous to codegen; not hand-written logic. |

**Overall:** No directory-level exclusion is present. The ignore blocks are narrow
and justified. This meets the §6a.7 AC and the §6a.6 strategy.

---

### Findings Summary

#### Critical (1)

**C-1:** The plan's §6a.7 AC "Firebase ad signals disabled; test asserts the no-PII
whitelist" is half-closed. The event property whitelist is asserted
(`search_performed` has no `term`/`query` key). But the Firebase `setConsent` call
that disables ad signals (`adStorageConsentGranted: false`, `adPersonalizationSignalsConsentGranted: false`, `adUserDataConsentGranted: false`) is inside the `bootstrap()` ignore block and has **no corresponding test**. The AC text says "test asserts" this behavior. Either the AC needs a note that this is verified by code review (not a test) due to the SDK constraint, or `setConsent` should be extracted into a `@visibleForTesting` function analogous to `installCrashHandlers`.

#### Important (4)

**I-1:** `runGuarded` test does not exercise the lazy-reporter-capture contract
(mutating `reporter` inside the zone and asserting a later error reaches the updated
reporter). This is the core of the C-2 "fallback before await" design, yet only
the simple case (static spy) is tested.

**I-2:** `ConsoleAnalyticsSink` presence in the composite is never positively
asserted. Truth table rows 2 and 3 confirm the absence of unwanted sinks but not
the presence of the expected console sink. A regression removing the
`if (!kReleaseMode)` guard would go undetected.

**I-3:** The "PostHog dark and logs a notice" branch (`developer.log(...)` at
`observability_providers.dart:107`) is outside any `coverage:ignore` block and is
reached in the "analytics on, no key" test, but the log emission itself has no
assertion. The plan's §6a.7 AC includes "logs a notice"; this behavior is untested.

**I-4:** `observabilityOverrides` calls `buildAnalyticsSink(config)` without the
`@visibleForTesting` factory injection, creating a latent test-safety hazard if
`analyticsEnabled: true` is ever passed from a test. The function should either
accept factories or document the constraint.

#### Suggestions (4)

**S-1:** `DetailTab.stats` serialized string (`'stats'`) is not individually
asserted in `analytics_event_test.dart`.

**S-2:** `ListOrigin.cold` → `'cold'` mapping is not individually asserted in the
dedicated `ListViewed` test (only in the bulk non-null loop).

**S-3:** `ConsoleErrorReporter` is not tested with a `null` stackTrace argument.

**S-4:** The RNF-09 `SearchPerformed` assertion checks two forbidden key names
(`term`, `query`) rather than asserting the exhaustive expected key set
(`{'result_count'}` only). A future free-text field with a different name would
pass the current assertion.

---

### Recommendations

1. **Resolve C-1 (Firebase ad signals AC):** Extract the `setConsent` call into a
   `@visibleForTesting` function (e.g., `applyFirebaseConsent`) mirroring the
   `installCrashHandlers` pattern. Write a test that calls it with a mock
   `FirebaseAnalytics` (using mocktail) and asserts `setConsent` was called with
   `adStorageConsentGranted: false`, `adPersonalizationSignalsConsentGranted: false`,
   and `adUserDataConsentGranted: false`. This closes the only unambiguously-open
   §6a.7 AC.

2. **Address I-2 (Console presence):** In `observability_providers_test.dart`, add
   an assertion that dispatching an event through `buildAnalyticsSink(_config())`
   records that event in a `_RecordingSink` substituted for
   `ConsoleAnalyticsSink` via a third factory parameter, or — more simply — cast the
   returned `CompositeAnalyticsSink._sinks` via a test-accessible getter and verify
   it contains exactly one `ConsoleAnalyticsSink` instance.

3. **Address I-1 (lazy reporter capture):** Add a `runGuarded` test variant where
   the reporter factory closure returns different instances over time (a mutable
   variable), and verify the second error (thrown after the variable is updated)
   reaches the second reporter — not the first. This directly validates the
   C-2 design intent.

4. **Address I-3 (notice logging):** Capture the `developer.log` output using a
   custom `Zone` with a `zoneSpecification.print` override, or document that the
   log emission is covered by code inspection only (and note the limitation inline
   in the test). Either approach closes the AC gap.

5. **Minor hardening (S-1, S-2, S-4):** Add `DetailTab.stats` to the
   `DetailTabChanged` test; add `ListOrigin.cold` to the dedicated `ListViewed` test;
   replace the two `isNot(contains(...))` RNF-09 assertions with a single
   `expect(event.parameters.keys, {'result_count'})` exhaustive check.

---

### Verdict

**Fix 1 critical and 4 important issues before merging.**

The test suite is structurally sound — fakes over mocks, `ProviderContainer`
teardown, `@visibleForTesting` extraction points, and no tautological assertions.
However, the most important acceptance criterion in the plan (Firebase ad signals
disabled per RNF-09) has no test, and the Console-presence invariant that protects
the debug telemetry path is never asserted. These two gaps, plus the lazy-reporter
and notice-logging gaps, mean the suite does not fully close the §6a.7 ACs as
written.
