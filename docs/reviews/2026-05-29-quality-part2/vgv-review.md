# VGV Code Review — T-30a Part 2: Observability seam + bootstrap

**Date:** 2026-05-29
**Branch:** `feature/quality-part1` (epic `epic/quality`)
**Scope:** `lib/core/observability/**`, `lib/bootstrap.dart`, `lib/main.dart`, `lib/firebase_options.dart`, `test/core/observability/**`, `test/bootstrap_test.dart`, `pubspec.yaml`/`pubspec.lock`
**Authoritative plan:** `docs/plan/2026-05-28-feat-quality-and-release-plan.md` §6 / §6a (D-3, D-5, D-6, D-7)
**Tooling note:** `dart analyze lib test` → *No issues found*. `dart format` reported clean by author. Tests validated on CI only (local runner broken); **not** executed in this review.

---

## Summary

This is a clean, disciplined, plan-faithful slice. The observability seam is well-factored: split interfaces (D-6), a sealed `AnalyticsEvent` whose 9 variants enforce the RNF-09 property whitelist *at the type level* (no free-form map passthrough), a composite fan-out, three thin vendor adapters with line-level coverage ignores (no directory exclusion, per §6a.6), and a `bootstrap()` that assigns a synchronous fallback reporter before the first `await` (resolves C-2). Naming is excellent, dartdoc is thorough and traceable to plan sections, and the lint suppressions are justified inline. The analyzer-9 pin guardrail (§6a.3) held — deps landed in a dedicated `chore(deps)` commit and no codegen pin moved in the lock.

The implementation is **ready to merge** after addressing a small number of correctness/consistency issues, none of which are blockers in the strict sense but two of which I'd want fixed before this becomes the production crash-reporting path that T-31 ships. The most material gaps: the `Failure`/TE-code is silently dropped on both the guarded-zone path and the Sentry adapter (the one piece of typed context the `ErrorReporter` seam exists to carry), and the seam's two most safety-critical reporters are tested only with `returnsNormally` smoke assertions rather than behavioral spies.

**Verdict: needs minor work (then merge).** No architectural rethink required.

---

## 🔴 Critical — Must Fix Before Merge

*(None that block the seam from being correct and safe for a dark/Firebase-only MVP. The items below are the highest-priority corrections; I have placed the two that affect production crash fidelity at the top of "Important" because T-31 makes this the live error path.)*

---

## 🟡 Important — Should Fix

- **`lib/bootstrap.dart:84-87` — the guarded-zone handler drops the `Failure` and, more importantly, the seam never threads typed failures into the reporter at all.**
  - Why: The entire reason `ErrorReporter.captureError` has a `{Failure? failure}` parameter (D-6, `error_reporter.dart:16`) is to let a reporter tag a crash with its PRD TE code. But `runGuarded`'s handler calls `reporter().captureError(error, stack)` with no failure, `installCrashHandlers` does the same, and `SentryErrorReporter.captureError` ignores the param entirely. The result: the one bit of typed, RNF-09-safe context the split-interface design was built to carry is unreachable in T-30a. That is defensible for *uncaught* zone errors (you genuinely don't have a `Failure` there), but it means the `failure:` parameter is, today, dead surface area exercised only by `ConsoleErrorReporter`. Acceptable for the seam, but flag it so T-30b actually wires `captureError(e, s, failure: ...)` at the §4.3 swallow points — otherwise this parameter quietly rots.
  - Fix: No code change required in T-30a. Add a one-line `// T-30b wires `failure:` at the §4.3 handled-error sites` note near the zone handler so the intent is explicit, and ensure the T-30b AC covers passing the `Failure` through.

- **`lib/core/observability/adapters/sentry_error_reporter.dart:18-22` — `failure` is accepted then discarded, with no tag/context attached to the Sentry event.**
  - Why: When this becomes the live crash path (T-31), a captured exception carrying a known `Failure` (e.g. `RateLimitFailure` → TE-08) will reach Sentry with zero TE context, defeating the value of the typed seam. The dartdoc on the interface explicitly promises "so a reporter can tag it with the PRD TE code."
  - Fix: Inside the ignore block, when `failure != null` attach it as a tag/context, e.g. `Sentry.captureException(error, stackTrace: stackTrace, withScope: (s) => s.setTag('te_failure', failure.message))`. The line stays coverage-ignored (untestable SDK glue) but the promise is kept. If you prefer to defer to T-30b, document that explicitly in the adapter dartdoc rather than leaving a silently-ignored parameter.

- **`test/core/observability/error_reporter_test.dart:9-34` & `test/core/observability/sinks/sinks_test.dart:36-45` — `returnsNormally` smoke tests on the reporters/sinks assert no behavior.**
  - Why: VGV's bar is "verify behavior, not that it doesn't throw." `NoopErrorReporter`/`NoopAnalyticsSink` "swallow everything" is asserted only by *not throwing* — a reporter that logged to a backend would also pass. `ConsoleErrorReporter` logging "without a failure" vs "tagged with its failure" are two tests that assert the **same** thing (`returnsNormally`) and never check that the failure tag actually changes the output. These are the two most safety-relevant classes in the seam (crash capture + the no-emit-under-test guarantee), and they're the weakest-tested.
  - Fix: For the Noop classes, assert the *no-side-effect* contract behaviorally — e.g. spy the collaborator or, minimally, assert a recording fake receives nothing. For `ConsoleErrorReporter`, capture `dart:developer` log output (or inject a logging seam) and assert the message differs with/without a `Failure`. At minimum, collapse the two identical `ConsoleErrorReporter` tests into one honest "does not throw" smoke test and add a real behavioral assertion for the failure-tag branch — otherwise the second test is duplicate coverage masquerading as a distinct case.

- **`lib/bootstrap.dart:48-59` — Sentry path nests `SentryFlutter.init`'s own zone/hooks *inside* the outer `runZonedGuarded`, creating two zone error owners.**
  - Why: §6a.4 and the dartdoc promise "single hook ownership, no double-install." `installCrashHandlers` is correctly skipped on the Sentry path — good. But `SentryFlutter.init` installs its own `PlatformDispatcher.onError`/`FlutterError.onError` *and* runs `appRunner` while the whole thing is still wrapped in the outer `runZonedGuarded(body, (e,s) => reporter().captureError(...))`. After the Sentry handover, an async error in the running app can surface to **both** Sentry's handler and the outer zone handler (now pointing at `SentryErrorReporter`), i.e. the same error captured twice. This is the exact double-ownership the plan calls out, just relocated from the manual hooks to the zone. The fallback-before-await design is otherwise correct and well done.
  - Fix: Either (a) don't wrap the Sentry branch in the outer `runZonedGuarded` (let Sentry own its zone entirely — run the dark path guarded, the Sentry path under Sentry's own zone), or (b) make the outer zone handler a no-op once Sentry has taken over (e.g. guard on a `sentryActive` flag). Document the chosen ownership boundary in the dartdoc since the AC requires it be documented. Worth verifying behaviorally on CI before T-31 flips Sentry live.

- **`lib/core/observability/observability_providers.dart:104-108` — the "dark vendor logs a notice" guarantee (§4.1, AC §6a.7) is implemented for PostHog but **not** for a dark Firebase or a dark Sentry from this builder.**
  - Why: The AC states "Missing/empty `SENTRY_DSN`/`POSTHOG_KEY` ⇒ adapter dark **and logs a notice**." Sentry's notice lives in `bootstrap.dart:55` (good). PostHog's notice is here (good). But there is no symmetric notice for the common case where `analyticsEnabled` is true yet *no* vendors are keyed in release (empty composite) — the §4.2 "effectively off" path goes silent. Minor, but the plan explicitly wants "no silent no-op."
  - Fix: The PostHog branch already covers its case. Confirm whether the empty-composite-in-release case warrants a notice; if so add a one-liner, otherwise note in the dartdoc that an empty composite is an intentional, logged-elsewhere state. Low effort, closes the AC literally.

- **`lib/core/observability/sinks/console_sink.dart` / `noop_sink.dart` — file name does not match the primary export (`ConsoleAnalyticsSink` / `NoopAnalyticsSink`).**
  - Why: VGV/`very_good_analysis` convention is file-name-matches-primary-export. `console_sink.dart` → `ConsoleSink` would match; the class is `ConsoleAnalyticsSink`. The composite file is consistent (`composite_analytics_sink.dart` → `CompositeAnalyticsSink`), which makes the two odd ones out conspicuous. Since `dart analyze` passes, `very_good_analysis` evidently doesn't hard-enforce this here, but it's a real consistency nit within the very directory it appears in.
  - Fix: Rename files to `console_analytics_sink.dart` / `noop_analytics_sink.dart` (matching `composite_analytics_sink.dart`), or rename the classes to `ConsoleSink` / `NoopSink`. Prefer the former — the `*AnalyticsSink` names read better at call sites and match the composite. Update the 3 importers.

---

## 🔵 Suggestions — Nice to Have

- **`lib/core/observability/observability_providers.dart` holds five distinct responsibilities** (`ObservabilityConfig`, two `@riverpod` providers, `buildAnalyticsSink`, `observabilityOverrides`). The plan deliberately merged `observability_config.dart` in here (§6a.2) to avoid a one-consumer file — that call is sound and I'd keep it. Just flagging that `ObservabilityConfig` is the one piece another file (`bootstrap.dart`) constructs directly; if it ever grows a second consumer, split it out then. No action now.

- **`lib/core/observability/observability_providers.dart:89-97` — the `@visibleForTesting` adapter factories are a clean, justified seam** (real `FirebaseAnalytics.instance` would throw without a live app). This is exactly the right tradeoff and the test file exploits it well. No change; called out as a positive.

- **`firebase_options.dart` placeholder is handled responsibly** — the header is explicit, `coverage:ignore-file` is justified, non-web platforms throw a helpful message. Approved as an interim per the user's sign-off. Ensure the T-31 checklist (plan §11) blocks production on regenerating this.

- **`analytics_event.dart` `parameters` getters allocate a fresh map each call.** Trivial, and not worth `const`-ifying given they're built per-emit at low frequency. Mentioned only for completeness — leave as is (YAGNI).

- **`bootstrap.dart` whole-function `coverage:ignore-start/end`** (lines 28, 74) is appropriate — the orchestration is genuinely untestable and the testable pieces (`runGuarded`, `installCrashHandlers`, `buildAnalyticsSink`) are extracted and unit-tested. This is the right application of §6a.6, in contrast to a directory exclusion.

---

## Simplicity Assessment

- **Lines that could be removed:** ~10 (collapse the two identical `ConsoleErrorReporter` `returnsNormally` tests; the `failure:` param is currently inert outside Console but is correct seam surface, so keep it).
- **Unnecessary abstractions:** None. The split interfaces (D-6), composite, and adapter factories all earn their keep — each interface has 3+ implementations and the factories exist for a concrete testability reason. The `one_member_abstracts` suppressions are correctly justified (polymorphic DI seam, not a callback).
- **YAGNI violations:** None. PostHog-on-web is *deferred* (no-op + documented rationale, §6a.5) rather than speculatively built — exemplary restraint. No premature config file, no `env/*.json` tree, no package split (D-5 honored).
- **Complexity verdict:** **Already minimal.** This is a textbook right-sized seam.

---

## Testing Assessment

- **New code with tests:** ✅ All seam files have corresponding tests. `analytics_event_test.dart` is thorough (per-event name+parameters, explicit RNF-09 negative assertions on `term`/`query`, non-null contract). `observability_providers_test.dart` covers the full §4.2 truth table (off / on-no-key / on+key) with recording fakes and asserts provider defaults + overrides — strong. `sinks_test.dart` covers composite fan-out order and empty-composite. `bootstrap_test.dart` covers the C-2 init-throw → fallback path and both crash hooks with a spy, restoring globals in `addTearDown` — well done.
- **Test quality:** **Mostly meaningful, two weak spots.** The event, truth-table, and bootstrap tests verify real behavior. The reporter/sink `returnsNormally` smoke tests (see Important) verify only non-throwing and include a duplicate pair. Tighten those.
- **State management test coverage:** ✅ Complete — the two Riverpod providers' defaults and override behavior are both asserted via `ProviderContainer` with proper `addTearDown(container.dispose)`.
- **UI component test coverage:** N/A — this slice ships no widgets (seam + bootstrap only, by design; events wire in T-30b).
- **AC traceability (§6a.7):** Split interfaces ✅ · 9 events ✅ · `bootstrap()` fallback-capture + test ✅ · single hook ownership ⚠️ (manual hooks single, but outer zone + Sentry may double-capture — see Important) · no-PII whitelist + test ✅ · §4.2 sink selection + NoopSink-under-test ✅ · dark-vendor notice ⚠️ (Sentry/PostHog yes, empty-composite no) · `firebase_options.dart` committed ✅ (placeholder, signed off) · lockfile pins unchanged + separate deps commit ✅ · no directory-level coverage exclusion ✅.
