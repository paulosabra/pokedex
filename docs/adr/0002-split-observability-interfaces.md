# 2. Split observability into `AnalyticsService` and `ErrorReporter`

- **Status:** Accepted
- **Date:** 2026-05-29
- **Deciders:** Paulo Sabra
- **Context task:** T-30a (Quality & Release epic)

## Context

The app needs two distinct observability capabilities (PRD §12, RNF-09):

- **Product analytics** — a fixed set of 9 intentional, anonymized events
  (`list_viewed`, `search_performed`, `pokemon_opened`, …) with whitelisted,
  PII-free properties.
- **Crash / error reporting** — capturing uncaught exceptions and handled
  failures (tagged with their TE code) for diagnosis.

These map to different vendors (Firebase Analytics / PostHog for the former;
Sentry for the latter), different data shapes, and different privacy rules. The
question was whether to expose **one** unified observability interface or
**two** focused ones.

A single `Observability { logEvent(...); captureError(...) }` interface forces
every adapter to implement both halves. A Firebase adapter has no meaningful
`captureError`; a Sentry adapter has no meaningful `logEvent`. The unused half
becomes a no-op — the interface **leaks no-ops**, and a caller can't tell from
the type which capability an implementation actually provides.

## Decision

**Two separate interfaces** in `lib/core/observability/` (D-6):

- `AnalyticsService { void logEvent(AnalyticsEvent event) }`
- `ErrorReporter { void captureError(Object error, StackTrace? stack, {Failure? failure}) }`

Each has its own Riverpod provider (`analyticsServiceProvider`,
`errorReporterProvider`), both defaulting to a **Noop** implementation so
`flutter test` and any un-bootstrapped scope never emit (§4.2). `bootstrap()`
overrides them with the real fan-out: a `CompositeAnalyticsSink` over the
enabled analytics adapters, and the console or Sentry error reporter.

Analytics events are a **sealed `AnalyticsEvent` type** with one constructor per
§12 event and only whitelisted properties — there is no free-form
`Map<String, Object>` passthrough, so RNF-09 (no PII) is enforced at the type
level rather than by convention.

The whole seam lives in a single package directory — **no separate package
split** (D-5), consistent with the app's single-package, feature-first layout
(YAGNI).

## Consequences

**Positive**

- Each adapter implements exactly the capability it has; no leaked no-ops.
- Call sites declare intent precisely: a view-model depends on
  `AnalyticsService`, an error widget on `ErrorReporter`.
- Vendor selection (Firebase on, PostHog/Sentry dark until keyed) is isolated to
  the composite sink and provider wiring; call sites are vendor-agnostic.
- The type-level property whitelist makes "no PII" testable and hard to violate
  accidentally.

**Negative / trade-offs**

- Two interfaces and two providers instead of one — slightly more surface area.
- A future need for a third capability (e.g. structured logging) means a third
  interface rather than a method on an existing one. Accepted: the same
  "different concern → different interface" rule applies and keeps each focused.
