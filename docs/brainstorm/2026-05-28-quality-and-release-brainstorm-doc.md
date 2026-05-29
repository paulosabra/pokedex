---
date: 2026-05-28
topic: quality-and-release
---

# Final Phase — Quality & Release (T-29 · T-30 · T-31 · T-32)

## What We're Building

The MVP's data, domain, and presentation layers are merged. This epic closes the
backlog by turning a feature-complete app into a **shippable, observable,
verifiably-tested, documented** product. It is the "Fase Final — Qualidade &
Release" of the backlog and spans four tasks, delivered as **four independent
PR parts off `epic/quality`**, in dependency order:

1. **T-29 — Test pyramid & coverage gate.** Add the missing top of the pyramid
   (`integration_test` E2E for the two critical flows: _search → open detail_ and
   _paginate the list_), and make coverage honest and enforced — exclude
   generated code (`*.g.dart`, `*.freezed.dart`) from the lcov report and add a
   **≥80% hand-written coverage gate** to CI.
2. **T-30 — Observability seam.** Introduce a **split** observability layer:
   `AnalyticsService` (product events, PRD §12) and `ErrorReporter` (crashes /
   TE-coded failures). Wire the PRD §12 event call sites. Ship **three real
   vendor adapters scaffolded** — Firebase (live by default), Sentry and PostHog
   (configured and testable, but dark until keyed) — selected by a **composite
   sink driven by `--dart-define` flags**, defaulting to a console sink in debug.
3. **T-31 — Web deploy on Vercel.** Build Flutter Web in **GitHub Actions** and
   publish the **prebuilt artifact** to Vercel (avoiding a Flutter-SDK clone
   inside Vercel's build). `vercel.json` provides SPA rewrites _and_ the COOP/COEP
   headers that Drift's WASM cache requires. Preview on PR, production on `main`.
4. **T-32 — Final docs & CHANGELOG.** Expand the README to a
   clone→build→test→deploy runbook, generate a CHANGELOG from the Conventional
   Commit history, and record the non-obvious decisions as lightweight ADRs in
   `docs/`.

Net outcome: a public, deep-linkable web URL backed by a green CI that gates
format, analyze, an enforced coverage floor, and an E2E flow; an instrumentation
seam that ships with Firebase on and two more vendors a flag away; and docs that
let a new developer run the project in a day.

## Why This Approach

Four tasks, one through-line: **make quality and release _mechanical and
enforced_ rather than aspirational.** Each part was scoped against the
project's standing principles — YAGNI on internal abstractions, faithful
modelling of external reality, and "no silent gaps."

### T-29 — Coverage honesty before coverage volume

The repo sits at **75.1% line coverage**, nominally short of the 80% target. But
the shortfall is almost entirely **generated code**: `app_database.g.dart`
(31.8%, ~1,200 lines), `pokemon_dao.g.dart` (43.2%), and DTO `*.g.dart` files
(~57–61%). Hand-written domain/data code is already well covered.

Three options were weighed:

- **Write tests to drag generated code over 80%** — rejected. Testing generated
  Drift/Freezed/Retrofit output tests the code generator, not our logic. It
  inflates the number while teaching us nothing and rotting on every codegen run.
- **Lower the target** — rejected. The 80% bar is a Tech Spec §13 / Principle 11
  commitment and a useful ratchet.
- **Exclude generated code from the lcov report, then enforce ≥80% on what
  remains** _(chosen)_ — this measures the thing we actually control. Combined
  with the existing strong unit/widget suite, hand-written coverage clears 80%
  with little or no new unit tests, and the gate stays meaningful over time.

On top of the gate, T-29 adds the **one tier the pyramid is missing**: real
`integration_test` E2E for _search → detail_ (UC-02/06) and _pagination_
(UC-01). These exercise the Riverpod graph, go_router, and the Drift cache
end-to-end on a real engine — coverage the widget tests (with overridden
providers) structurally cannot give. The pyramid stays correctly shaped: many
unit, some widget/golden, **few** E2E.

### T-30 — A faithful seam, three real adapters, one live

The app has no analytics today (only a dev-time Dio logging interceptor). The
guiding memory note — _defer internal abstractions, but model external reality
faithfully_ — plus RNF-09 (no personal data) shaped the design:

- **Split, not unified.** `AnalyticsService.logEvent(...)` and
  `ErrorReporter.captureError(...)` are separate interfaces because product
  analytics (Firebase, PostHog) and crash reporting (Sentry) are genuinely
  different concerns. A unified interface would force every adapter to no-op half
  its surface — a leaky abstraction. The split also maps cleanly onto the
  existing `Result`/`Failure` types: `ErrorReporter` consumes the TE-coded
  `Failure` that the UI already surfaces, and `error_shown` falls out naturally.
- **Three vendors scaffolded, Firebase live.** The user will use Firebase but
  wants Sentry and PostHog _configured and testable_ now. So we build all three
  adapters (`FirebaseAnalyticsAdapter` + `PostHogAdapter` behind
  `AnalyticsService`; `SentryErrorReporter` behind `ErrorReporter`), plus a
  `ConsoleSink` (debug default) and `NoopSink`.
- **Composite sink + `--dart-define`.** A multiplexing sink fans each event to
  every _enabled_ adapter; which are enabled is decided at startup from
  `--dart-define` flags / DSN keys (e.g. `SENTRY_DSN`, `POSTHOG_KEY`,
  `ANALYTICS_ENABLED`). Debug builds default to the console sink; Firebase ships
  on; Sentry and PostHog are wired but dark until a key is supplied — flipping
  them on is a flag, not a code change. This satisfies "configure all, use one"
  without dead-but-shipped vendor code paths becoming the default.

RNF-09 ("no personal data") shapes the **event design** — anonymous, aggregate
properties only (e.g. `search_performed` carries a result count, never the raw
term). It does **not**, by itself, bless every vendor default: Firebase
Analytics' out-of-the-box collection sets app-instance/device identifiers and
ad-related signals, which is in tension with RNF-09. Reconciling that (disable
ad-id collection, anonymize, or gate behind consent) is an explicit decision
flagged in Open Questions — not something this design assumes away.

The seam lives in `lib/core/observability/` (consistent with the existing
single-package, feature-first layout — no premature package split). Event call
sites are the PRD §12 list, wired from the ViewModels/coordinators where the
intent already lives.

Alternatives rejected: a **single unified interface** (leaky, as above); wiring
**only a real provider with no seam** (couples UI to a vendor SDK, untestable);
and **deferring T-30 entirely** (loses the instrumentation the PRD calls for in
v1, and the seam is cheap now while the call sites are fresh).

### T-31 — Build in CI, deploy a prebuilt artifact

The Tech Spec §12.2 reference has Vercel run a `build.sh` that `git clone`s the
Flutter SDK and builds in-place. That works but is **fragile**: it risks
Vercel's build time/size limits on every deploy, and it pins to `stable` rather
than the project's **3.44.0**. The §12.3 note already flags the alternative.

Chosen path: **GitHub Actions builds, Vercel hosts.** CI (already running
Flutter 3.44.0 + codegen) runs `flutter build web --release`, then pushes the
**prebuilt `build/web`** to Vercel via the Vercel CLI (`vercel deploy --prebuilt`
or equivalent, with `vercel.json` carrying the runtime config). Benefits: the
exact pinned SDK builds the artifact, build logs live next to the test logs, and
Vercel just serves static files. PRs get preview URLs; `main` promotes to
production.

`vercel.json` carries two load-bearing pieces:

- **SPA rewrites** (`/(.*) → /index.html`) so deep links like `/pokemon/25`
  resolve to the go_router client (without them, direct access 404s — an explicit
  T-31 acceptance criterion).
- **COOP/COEP headers** (`Cross-Origin-Opener-Policy: same-origin`,
  `Cross-Origin-Embedder-Policy: require-corp`). Drift's WASM worker needs
  `SharedArrayBuffer`, which browsers gate behind these headers. They must be set
  at the CDN layer — `index.html` `<meta>` can't grant cross-origin isolation.
  Without them the web cache degrades or fails. (PokeAPI sends open CORS, so the
  API calls themselves are unaffected.)

### T-32 — Docs that match the now-shippable reality

The README is thin (clone/codegen/run/quality only). T-32 brings it up to a full
runbook (architecture overview, the `--dart-define` flags from T-30, the deploy
flow from T-31), generates a **CHANGELOG from the Conventional Commit history**,
and records the non-obvious calls as lightweight ADRs in `docs/` (e.g. _why
GitHub-Actions-builds-Vercel-hosts_, _why split observability interfaces_, _why
exclude generated code from coverage_). T-32 depends on T-31 so the deploy story
is real before it's documented.

## Key Decisions

- **Scope: all four tasks, four PR parts off `epic/quality`**, in order
  T-29 → T-30 → T-31 → T-32. Closes the MVP backlog completely.
- **Coverage: measure honesty, enforce a floor.** Exclude `*.g.dart` /
  `*.freezed.dart` from lcov; add a **≥80% gate** to CI. Rationale: testing
  generated code measures the generator, not us.
- **E2E: add the missing pyramid tier, keep it thin.** `integration_test` for
  _search → detail_ (UC-02/06) and _pagination_ (UC-01) only. Rationale: real
  engine coverage of the Riverpod + router + Drift path that overridden-provider
  widget tests can't reach.
- **Observability: split interfaces.** `AnalyticsService` (events) +
  `ErrorReporter` (crashes). Rationale: product analytics and crash reporting are
  different concerns; a unified interface leaks no-ops.
- **Vendors: three scaffolded, Firebase live.** Firebase + PostHog behind
  `AnalyticsService`; Sentry behind `ErrorReporter`; plus console + no-op sinks.
  Rationale: user uses Firebase but wants all three configured/testable.
- **Vendor selection: composite sink + `--dart-define`.** Fan-out to all enabled
  adapters; enablement driven by flags/keys; debug defaults to console. Rationale:
  "configure all, use one" with a flag-flip, not a code change.
- **Deploy: GitHub Actions builds, Vercel hosts the prebuilt artifact.**
  Rationale: builds with the pinned 3.44.0, dodges Vercel build limits, keeps
  logs co-located. PR preview, `main` production.
- **`vercel.json` is load-bearing:** SPA rewrites (deep links) **and** COOP/COEP
  headers (Drift WASM `SharedArrayBuffer`). Rationale: both are functional
  requirements, not polish.
- **Observability code lives in `lib/core/observability/`** — no package split.
  Rationale: consistent with the single-package feature-first layout; YAGNI.
- **Docs last, after deploy is real (T-32 depends on T-31).** README runbook +
  generated CHANGELOG + lightweight ADRs. Rationale: document the working system.

## Open Questions

- **Post-exclusion coverage is unmeasured.** The ≥80% target assumes that
  excluding generated code lifts hand-written coverage over the floor — a
  plausible inference from the 75.1% blended number, but not yet computed. If the
  hand-written figure lands below 80%, T-29's fallback is targeted unit tests on
  the lowest-covered _hand-written_ files (not generated code). Measure first in
  `/plan`, then size the gap.
- **RNF-09 vs Firebase default collection.** Decide how to reconcile Firebase
  Analytics' default identifier/ad-signal collection with RNF-09: disable
  ad-id/IDFA collection, anonymize, or gate behind a consent prompt. Affects the
  Firebase init in T-30 and what the deployed web build sends on first load.
- **Coverage gate mechanism:** which tool enforces the ≥80% floor in CI —
  `very_good test --coverage --min-coverage 80` (VGV-native, also handles the
  exclusion via `coverage:ignore`/`--exclude`), a `lcov`-based step, or a
  `dart_code_metrics`/custom script? To pin in `/plan`.
- **`--dart-define` surface:** exact flag names and whether to introduce a
  `--dart-define-from-file` (e.g. `env/dev.json`, `env/prod.json`) so keys aren't
  passed inline in CI. Secrets (Firebase config, Sentry DSN, PostHog key) flow via
  GitHub Actions secrets — confirm the mapping in `/plan`.
- **Firebase init on Web:** does Firebase Analytics on Flutter Web need
  `firebase_options.dart` (FlutterFire CLI) committed, and do we add iOS/Android
  config now or web-only for the MVP deploy? The deploy target is Web; mobile
  Firebase config could be deferred.
- **Sentry scope:** crash/error reporting only, or also performance tracing /
  release health? MVP leans error-only; confirm.
- **E2E in CI on web vs. mobile target:** `integration_test` typically runs on a
  device/emulator. Do we run the E2E flows headless on a Linux emulator in CI, or
  gate them to a separate (non-blocking-to-start) workflow? Affects CI runtime.
- **CHANGELOG tooling:** `git-cliff`, `release-please`, `standard-version`, or a
  one-shot generated `CHANGELOG.md` seeded from existing history? Pick in `/plan`.
- **Vercel project linkage:** does a Vercel project/token already exist, or does
  T-31 include first-time project creation + `VERCEL_TOKEN`/`ORG_ID`/`PROJECT_ID`
  secrets setup?
