# Architecture Review — PR4 (T-31: web deploy + C-1 router fix)

- **Branch:** `feature/quality-part4`
- **Base:** `770328f` (Merge #20 / T-30b — satisfies O-1)
- **Reviewer:** Architecture Review Agent (VGV standards)
- **Date:** 2026-05-29
- **Scope:** `lib/app/router/app_router.dart`, `lib/app/router/route_error_screen.dart`, `vercel.json`, `.github/workflows/deploy.yml`, `integration_test/app_test.dart`, `test/app/router/route_error_screen_test.dart`

This project is a single-package Flutter app (not a VGV multi-package monorepo). Layer boundaries are enforced by directory convention under `lib/`: `app/` (composition / shell), `features/<feature>/{data,domain,presentation}`, and `core/` (cross-cutting: `ui` design system, `observability`, `error`). VGV layered-architecture rules are applied to those directory boundaries.

---

## Layer Separation

Verdict: **clean.** No cross-layer import violations in any changed file.

### `lib/app/router/route_error_screen.dart` (NEW)

Imports:

- `package:flutter/material.dart`, `package:flutter_riverpod`, `package:go_router` — framework.
- `package:pokedex/app/theme/app_colors.dart` — app layer (same layer).
- `package:pokedex/core/observability/analytics_event.dart` — core.
- `package:pokedex/core/observability/observability_providers.dart` — core.
- `package:pokedex/core/ui/states/generic_error_widget.dart` — core (design system).

App-layer code depending on `core/` is the correct, allowed direction (app → core). There is **no** import of `features/**` or any `data`/`domain` symbol. No data-layer leakage. The screen consumes the design-system `GenericErrorWidget` rather than re-implementing error chrome, which is exactly the reuse the DS layer exists for.

### `lib/app/router/app_router.dart` (MODIFIED)

Imports `route_error_screen.dart` (app) and the two feature presentation pages (`pokemon_list_screen`, `pokemon_detail_screen`). The router is the **composition root** — its job is to wire feature screens into routes, so app → feature-presentation here is the intended direction for a composition layer, not a violation. It does not reach into `features/**/data` or `features/**/domain`.

Clean files: all four source/test files plus the two infra files checked clean.

---

## State Management Assessment

State management is Riverpod (riverpod_annotation + flutter_riverpod). `RouteErrorScreen` is the only stateful-ish unit introduced; the router provider is modified.

### `RouteErrorScreen` — Correct

- **Naming:** descriptive and intention-revealing (`RouteErrorScreen`), route-level not feature-specific. Good.
- **Widget type:** `ConsumerWidget` — correct. It needs `ref` only to read `analyticsServiceProvider` inside the `onShown` callback; no local mutable state, so `ConsumerWidget` (not `ConsumerStatefulWidget`) is the right minimal choice. The once-only-on-mount semantics are owned by `GenericErrorWidget`'s `initState`, so the screen correctly delegates lifecycle rather than re-implementing it.
- **Business logic location:** none in the widget. The only "logic" is `context.go('/')` (navigation affordance) and firing an analytics event through a provider. No data access, no repository calls, no domain logic in the UI. Correct.
- **Data access:** the widget reads `analyticsServiceProvider` (a core observability seam), not a data source. Correct — and consistent with how `pokemon_list_screen` / `pokemon_detail_screen` emit `error_shown`.
- **Provider lifecycle:** `analyticsServiceProvider` is `read` (not `watch`) inside a callback — correct, since the analytics sink should not rebuild the widget and the call is fire-and-forget. No provider is created/disposed by this widget.

### `router` provider (MODIFIED) — Correct

- `@Riverpod(keepAlive: true)` with `ref.onDispose(router.dispose)` — correct lifecycle. The `keepAlive` choice (preserve back-stack across rebuilds) is documented and sound.
- The `int.tryParse` guard and `errorBuilder` both funnel to `RouteErrorScreen`. The parse-and-branch lives in the route `builder` (composition), which is the right place for route-param coercion — it is not domain logic. Returning a const widget for the null case is clean.

No over- or under-engineering. The complexity matches the problem (a not-found page with one analytics side effect and one navigation affordance).

---

## Dependency Direction

Verdict: **clean.** One-way flow preserved.

```
app/router/app_router  ──▶ app/router/route_error_screen   (intra-app)
                       ──▶ features/.../presentation/pages  (composition root → feature UI)
app/router/route_error_screen ──▶ core/ui (design system)
                              ──▶ core/observability (analytics seam)
                              ──▶ app/theme (intra-app)
```

- No reverse edges: `core/**` does not import `app/**` or `features/**`; `core/ui/states/generic_error_widget.dart` depends only on `core/ui/states/state_view.dart` (intra-core) and stays observability-free — the `onShown` callback seam keeps the DS widget portable. Verified.
- No circular dependency: app depends on core and feature-presentation; neither core nor feature-presentation depends back on app.
- No duplicated shared code: the route error page reuses the existing DS `GenericErrorWidget` and the existing `ErrorShown` event + `analyticsServiceProvider`, rather than copying error UI or inventing a parallel analytics path.

---

## error_shown Contract Consistency (T-30b)

Verdict: **sound and consistent.**

T-30b established that every full-screen error state emits `error_shown` exactly once on mount, via the DS widgets' `onShown` seam, with `te_code` + `screen` properties. Cross-checking the existing emitters:

- `pokemon_list_screen` — `screen: 'pokemon_list'`, TE codes via `teCodeForError`.
- `pokemon_detail_screen` — `screen: 'pokemon_detail'`, TE codes via `teCodeForError`.
- `pokemon_list_view_model` — `screen: 'pokemon_list'`, `teCodeFor(failure)`.
- `stale_cache_banner` — TE-02.

`RouteErrorScreen` follows the same shape: `const ErrorShown(teCode: 'TE-03', screen: 'route_error')` fired through `GenericErrorWidget.onShown` → `analyticsServiceProvider.logEvent`. This is fully consistent with the contract:

1. **Mechanism:** uses the same `onShown` once-on-mount seam (`GenericErrorWidget.initState`), not a custom path. The unit test asserts `hasLength(1)` — once-only verified.
2. **TE code:** `TE-03` is the correct PRD code. The feature mapping `teCodeFor` already maps `NotFoundFailure → 'TE-03'`, and `GenericErrorWidget`'s own doc-comment lists it as a TE-03 surface. A route that does not exist is semantically "not found" → TE-03. Correct.
3. **`screen` value:** `'route_error'` is a new, distinct screen identifier. This is appropriate — a route-not-found page is genuinely a different surface from `pokemon_list` / `pokemon_detail`, so it should not borrow either of their names. A consumer of the analytics funnel can now distinguish "error on the list" from "user hit a dead URL."

One minor consistency observation (suggestion, not a defect): the feature screens centralize their screen name in a private `static const _screenName` / `_screen` and several reuse a shared `teCodeFor`/`teCodeForError` helper. `RouteErrorScreen` likewise uses a private `static const _screenName = 'route_error'` and hardcodes `'TE-03'` inline. Hardcoding the TE code here is reasonable because the route case is unconditionally not-found (there is no `Failure` object to map), so pulling in `teCodeFor` would add a dependency on `features/.../presentation/analytics/error_te_code.dart` — which would be a **bad** app → feature import. Inlining the literal is the correct trade-off and preserves layer hygiene. No change needed.

---

## Deploy Topology

Verdict: **trigger design is correct** — non-`main` branches cannot promote to production.

### Trigger analysis (`.github/workflows/deploy.yml`)

```yaml
on:
  push:
    branches: [main]   # production only
  pull_request:        # preview only
```

- **Production gate:** `--prod` and `TARGET_ENV=production` are both derived from `github.ref == 'refs/heads/main'`. Production promotion requires the `push` event on `main`. A `push` to `epic/**` or `develop` does **not** match `branches: [main]`, so the workflow does not even start for those pushes. This satisfies the plan's §7.4 requirement and aligns with the git-flow (feature → epic → develop → main): only the final landing on `main` ships production.
- **Preview path:** `pull_request` (no branch filter) means every PR — including PRs that target `epic/quality`, `develop`, or `main` — gets an isolated preview with `--prod` empty and `TARGET_ENV=preview`. Because `github.ref` on a `pull_request` event is `refs/pull/<n>/merge` (never `refs/heads/main`), the `PROD`/`TARGET_ENV` guards correctly resolve to preview. **No PR can promote to production**, even a PR into `main`. This is the desired property: production is reserved exclusively for the post-merge `push` on `main`.
- **No overlap with CI:** `ci.yaml` triggers on `epic/**`, `develop`, `main` (push + PR) and owns build/test/coverage/e2e; it contains no Vercel/promote step (the "production deploy targets" mention is only a comment describing the web stack). `deploy.yml` owns promotion and excludes `epic/**`/`develop` from production. The two workflows have clean, non-conflicting responsibilities. Correct separation.

### Secret-handling improvement over the plan (positive deviation)

The plan's §7.4 sketch interpolated secrets directly into the run-command string via `${{ format(...secrets.SENTRY_DSN...) }}`. The implementation instead exports `SENTRY_DSN` / `POSTHOG_KEY` through the step `env:` and assembles a bash array (`defines+=(--dart-define=SENTRY_DSN="$SENTRY_DSN")`). This avoids GitHub Actions script-injection on secret values and keeps each `--dart-define` a single argv entry regardless of value contents. This is a sound, security-positive divergence from the plan and is consistent with VGV's "apply the reviewer's quality fix over literal plan adherence" stance. No action needed; flagged as a good call.

### Other topology notes

- `concurrency: deploy-${{ github.ref }}` with `cancel-in-progress` serializes per-ref so a newer push supersedes an in-flight deploy — avoids racing two builds to promotion. Sound.
- Atomicity (I-5): `vercel build` then `vercel deploy --prebuilt` as separate steps; a failed `flutter build web` or `vercel build` exits non-zero before deploy, so a broken build cannot promote. Matches the plan's acceptance criterion.
- Reproducibility: `flutter pub get --enforce-lockfile`, pinned `flutter-version: 3.44.0`, pinned `vercel@54.6.1`. Matches the analyzer-9/codegen pin strategy in MEMORY. Sound.
- `vercel.json` SPA rewrite (`/(.*) → /index.html`) is what makes deep links reachable and is precisely why the C-1 router fix is needed in the same PR — the two changes are correctly co-located. COOP/COEP headers are present for Drift-WASM SharedArrayBuffer (the C-5 concern). `index.html` is marked `must-revalidate` so a new deploy is picked up. All consistent with §7.3.

### Observation (suggestion, infra not architecture)

`deploy.yml` references `VERCEL_PROJECT_ID` / `VERCEL_ORG_ID` / `VERCEL_TOKEN` secrets and assumes first-time `vercel link` + secret provisioning (plan D-8 runbook). This is out of band of the code and noted only so the reviewer/PR author confirms the one-time setup + README handoff (§7.5 acceptance items) are done before merge to `main`. Not a code-architecture defect.

---

## Package Structure

Single-package app; no new package introduced, so the per-package manifest/lint/test checklist is N/A. Within-package structure:

- `RouteErrorScreen` placed in `lib/app/router/` — **correct.** It is route-level, not Pokémon-specific: it serves both the malformed-`:id` case and any unmatched path (`errorBuilder`). Placing it under `features/pokemon/presentation` would wrongly couple a generic not-found page to the pokemon feature and would force `app_router` (which already lives in `app/`) to depend on a feature for its global error fallback. Placing it in `core/ui` would be defensible for a pure DS widget, but this screen is a *composed* surface (it wires the DS widget to the app's analytics seam and to `context.go('/')` navigation), which is composition responsibility — so `app/router/` is the most accurate home. The choice is right.
- Single, clear responsibility: render the not-found surface + emit its analytics event. Not a grab-bag.
- Test coverage added and correctly placed: unit/widget test at `test/app/router/route_error_screen_test.dart` (mirrors `lib/` path), and the C-1 deep-link flow added to `integration_test/app_test.dart` driven through the real `routerProvider` — co-located with the fix it verifies, matching the plan's testing note (§ deep-link case lands in T-31). Tests assert render, once-only `error_shown` with exact `{te_code, screen}`, and `Go home → /` recovery. Solid.

---

## Verdict

**Architecture is clean — ready to merge** (pending the non-code Vercel first-time provisioning + README handoff confirmation, which are infra runbook items, not architecture defects).

- Critical issues: **0**
- Important issues: **0**
- Suggestions: **3** (all optional / informational)
  1. TE-03 is correctly inlined in `RouteErrorScreen` rather than imported from the feature helper — keep it that way to preserve app→core-only deps (no change; confirming the trade-off).
  2. The deploy workflow's array-based `--dart-define` is a security improvement over the plan's inline interpolation — good call; keep it.
  3. Confirm `vercel link` / GitHub secrets (D-8) and README build-flow handoff are complete before the first `main` promotion.
