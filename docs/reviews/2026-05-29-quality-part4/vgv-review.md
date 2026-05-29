# VGV Code Review — PR4 (T-31: Web deploy on Vercel + C-1 router fix)

**Branch:** `feature/quality-part4` · **Date:** 2026-05-29 · **Reviewer:** VGV Review Agent

**Scope reviewed (working-tree changes only):**
- `vercel.json` (NEW)
- `.github/workflows/deploy.yml` (NEW)
- `lib/app/router/app_router.dart` (MODIFIED)
- `lib/app/router/route_error_screen.dart` (NEW)
- `integration_test/app_test.dart` (MODIFIED)
- `test/app/router/route_error_screen_test.dart` (NEW)

Immediate context read: `lib/core/ui/states/generic_error_widget.dart`, `lib/core/ui/states/state_view.dart`, `lib/core/observability/analytics_event.dart`, `test/helpers/recording_observability.dart`, `lib/app/app.dart`, `app_router.g.dart`, `.github/workflows/ci.yaml`, plan §4.1/§4.4/§7.

---

## Summary

This is a tight, high-quality slice that is ready to merge. The C-1 router robustness fix is correct and idiomatic; `RouteErrorScreen` faithfully reuses the T-30b `onShown` → `error_shown` seam with zero new observability coupling in the design-system layer; and the deploy workflow implements §7.4 (prod-on-main-only, `--enforce-lockfile`, pinned Vercel CLI v54.6.1, atomic build→deploy, previews stay dark) accurately. `dart analyze` is clean on all changed Dart files and all three new unit tests pass. There are **no critical issues**. The important items are operational hardening on the deploy workflow (broad `pull_request` trigger scope, missing `--delete-conflicting-outputs` on a fresh-clone codegen step, and the unmitigated COEP `require-corp` cross-origin-image risk that is acceptance-gated but not yet wired). All three are low-blast-radius and consistent with the approved plan.

---

## 🔴 Critical — Must Fix Before Merge

None.

---

## 🟡 Important — Should Fix

### 1. `pull_request` trigger has no `branches` filter — every PR builds a preview, including PRs into `epic/**` and `develop`
- **`.github/workflows/deploy.yml:11`** — `pull_request:` is unscoped.
  - **Why:** The header comment (lines 4–7) and §7.4 frame the design as "`epic/**`/`develop` deliberately excluded so an epic-branch push never promotes to production." That guarantee holds for **production** (`PROD`/`TARGET_ENV` key off `refs/heads/main`, and `push` is scoped to `[main]`), so this is **not** a production-promotion risk. However, the comment's spirit — keep epic/develop out of this workflow — is only half-implemented: a PR targeting `develop` or an `epic/**` branch still spins up a Vercel **preview** deploy and consumes a Vercel build. The sibling `ci.yaml` scopes both `push` and `pull_request` to `epic/**`/`develop`/`main`; `deploy.yml` diverges by leaving `pull_request` wide open.
  - **Note:** This matches the plan's literal YAML snippet (§7.4 also shows bare `pull_request:`), so it is plan-faithful. Flagging because the in-file comment claims a tighter exclusion than the trigger actually enforces, and because preview deploys on every PR (e.g. docs-only or dependabot PRs) is likely broader than intended.
  - **Fix:** Either scope previews to where they add value (PRs into `main`), or update the comment so it does not over-claim. Example:
    ```yaml
    on:
      push:
        branches: [main]
      pull_request:
        branches: [main]
    ```
    If previews on every PR are genuinely wanted, soften the lines 4–7 comment to say only **production** is gated on `main`.

### 2. `dart run build_runner build` lacks `--delete-conflicting-outputs`
- **`.github/workflows/deploy.yml:49`** — codegen step.
  - **Why:** Generated code is git-ignored (confirmed: `app_router.g.dart` is regenerated), so a fresh CI clone starts with no `.g.dart` files and `build` will normally succeed. But `build_runner build` aborts on any output conflict, and the runner caches/`subosito` setup can leave stale state across re-runs of a cancelled job (`concurrency.cancel-in-progress: true` makes mid-build cancellation routine). A conflict there fails the deploy with a non-obvious error.
  - **Fix:** `dart run build_runner build --delete-conflicting-outputs`. The CI E2E job (§5.4) uses the same bare form, so apply consistently or leave a one-line note on why the deterministic-clone assumption holds.

### 3. COEP `require-corp` cross-origin artwork risk (C-5) is acceptance-gated but not mitigated in code
- **`vercel.json:11`** — `Cross-Origin-Embedder-Policy: require-corp`.
  - **Why:** Under `require-corp`, every cross-origin subresource must send CORP headers. Official artwork loads from `raw.githubusercontent.com` via `cached_network_image`; GitHub's raw host does not send CORP, so images can silently fail to render on the deployed site while Drift's `SharedArrayBuffer` requirement is satisfied. The plan (§7.3 C-5, D-9) documents the fallback (`credentialless`) and §7.5 makes "artwork renders under COEP — else `credentialless` applied" an acceptance criterion to verify on the **preview** deploy. So this is correctly deferred to deploy-time verification, not a code bug — but the PR ships `require-corp` with no follow-up wired and no note in the PR description on the verification step.
  - **Fix:** No code change required to merge. Ensure the PR description / T-32 runbook captures the manual C-5 check (load a deployed preview, confirm sprites render); if they 404, switch to `credentialless`. Consider a one-line comment in `vercel.json` pointing at the C-5 decision (JSON has no comments — a `README`/runbook line suffices).

---

## 🔵 Suggestions — Nice to Have

- **`.github/workflows/deploy.yml:57,83,86`** — `--token=$TOKEN` is fine, but since `VERCEL_TOKEN` is already exported in `env:`, the Vercel CLI reads it implicitly; the explicit flag is redundant (harmless, and arguably clearer). Leave as-is if you prefer explicitness.
- **`.github/workflows/deploy.yml:71`** — `defines=(--dart-define=ENVIRONMENT="$TARGET_ENV")` quotes the value inside the array element. Because each element is a single argv entry, the quotes are inert here (bash strips them before the array stores the token). Harmless; the bash-array approach itself is the right call for injection-safety (§7.4) and is well-commented.
- **`lib/app/router/route_error_screen.dart:31`** — `"This page doesn't exist."` is duplicated as a literal in both test files (`route_error_screen_test.dart:19`, `app_test.dart`). Acceptable for a single-use string; if a TE-03 copy ever changes you'll update three sites. Not worth a shared constant yet (YAGNI).
- **`integration_test/app_test.dart`** — reaching into `ProviderScope.containerOf(tester.element(find.byType(PokedexApp))).read(routerProvider)..go(...)` is a pragmatic way to drive the real router without a fake URL bar; it is well-commented and the only practical seam for an in-harness deep-link test. Fine as-is.

---

## Pass 1 — Regressions & Breaking Changes

- **Signature change:** `app_router.dart` `/pokemon/:id` builder changed `int.parse` → `int.tryParse` with a null-guard. This is strictly safer — it converts a thrown `FormatException` (a hard crash now reachable under the SPA rewrite) into a TE-03 page. No caller impact: the route still yields `PokemonDetailScreen(id: int)` for valid ids. ✅
- **New `errorBuilder`:** Replaces GoRouter's default error scaffold with `RouteErrorScreen` for unmatched paths. No existing route behavior regresses. ✅
- **No deleted code / no weakened tests.** The integration test is purely additive (new `testWidgets` block); existing UC-02/06 and pagination flows untouched. ✅
- **No dependency changes** in scope. `go_router`, `flutter_riverpod` already present. ✅

## Pass 2 — VGV Architecture & Conventions

- **Layer separation:** `RouteErrorScreen` lives in the presentation/app layer, depends on the observability provider (`analyticsServiceProvider`) and the design-system `GenericErrorWidget` — no data-layer reach-through. `GenericErrorWidget` stays observability-free; the `onShown` callback keeps the analytics emission at the call site (§4.3). Clean inversion. ✅
- **Riverpod idioms:** `ConsumerWidget` + `ref.read(analyticsServiceProvider).logEvent(...)` inside `onShown` is correct — `read` (not `watch`) for a one-shot side effect. The router provider remains `@Riverpod(keepAlive: true)` with `ref.onDispose(router.dispose)` — disposal correct. ✅
- **Router idioms:** `int.tryParse(state.pathParameters['id']!)` — the `!` is justified (a matched `/pokemon/:id` always supplies the param) and the failure mode is the parse, not the null map access. `context.go('/')` for the recovery CTA is correct for a deep-link with no back stack. ✅
- **`error_shown` reuse (T-30b consistency):** `RouteErrorScreen` emits `const ErrorShown(teCode: 'TE-03', screen: 'route_error')` via the same `onShown`-once pattern the other full-screen error states use. Parameter keys (`te_code`, `screen`) match `ErrorShown.parameters`. Naming consistent with the sealed event hierarchy. ✅
- **Naming (5-second rule):** `RouteErrorScreen`, `_screenName = 'route_error'`, `routerProvider` — all pass. ✅
- **Lint/format:** `dart analyze` reports **No issues found** on all three changed/added Dart files. No suppressions. ✅
- **Deploy workflow conventions:** Flutter pinned to 3.44.0 (matches CI), Vercel CLI pinned to `54.6.1` (not `@latest`), `--enforce-lockfile`, secrets via `env:` + bash array rather than string interpolation (injection-safe), `concurrency` group with cancel-in-progress. Atomicity holds: a failed `flutter build web` exits non-zero before `vercel build`/`deploy`, so a broken build cannot promote (I-5). All faithful to §7.4. ✅

## Pass 3 — Testing Quality

- **`route_error_screen_test.dart`** — three meaningful tests:
  1. Renders TE-03 message + "Go home" CTA (`widgetWithText(ElevatedButton, ...)` — verified `StateView` primary action renders `ElevatedButton`).
  2. `error_shown` emitted **exactly once** on mount, with exact parameter map — uses `RecordingAnalytics` fake (value-like events, no `==`), asserting `hasLength(1)` guards against double-emission. This is the right depth for the seam reuse.
  3. CTA navigation: real `GoRouter` with `initialLocation: '/oops'`, `addTearDown(router.dispose)` (no leak), taps CTA, asserts landing on home. Covers the `context.go('/')` behavior, not framework rebuild mechanics.
  - All three pass under `very_good test`. ✅ Covers render, side-effect, and interaction — not just the happy path.
- **`app_test.dart` E2E (C-1):** Drives the real `routerProvider` for both malformed (`/pokemon/abc`) and unmatched (`/no-such-route`) deep links → both assert the TE-03 page, then exercises recovery via the CTA back to the list. Correctly chooses `abc` over an int64-overflow id (deterministic on web where large-int parse is lossy — good reasoning, captured in the comment). As noted in the task brief, this runs via `flutter drive` in CI, not `very_good test` on a bare VM — expected, not a defect. ✅
- **Test pyramid:** unit-heavy (3 widget tests) with one additive E2E flow — respects §5.5. ✅
- No tautologies, no over-mocking, no assertion-free tests.

## Pass 4 — Simplicity & YAGNI Audit

- `RouteErrorScreen` is 42 lines, single responsibility, no premature abstraction. It does **not** invent a new error widget — it composes the existing `GenericErrorWidget`, overriding only `message`/`retryLabel`/`onRetry`/`onShown`. This is the correct reuse, not a parallel hierarchy. ✅
- The router fix is the minimal change: one `tryParse` + null guard + one `errorBuilder`. No new config surface, no generic error-routing framework. ✅
- `vercel.json` carries exactly the keys §7.3 specifies — no speculative headers or routes. ✅
- The deploy workflow is appropriately sized: no reusable-workflow extraction for a single deploy target (would be premature). ✅
- **Lines that could be removed:** ~0 (the redundant `--token` flags, lines 57/83/86, are stylistic, not removable without losing explicitness).
- **Unnecessary abstractions:** none.
- **YAGNI violations:** none.
- **Complexity verdict:** Already minimal.

---

## Verdicts

- **Simplicity:** Already minimal.
- **Testing:** New code fully tested; meaningful coverage (render + side-effect + interaction + E2E); state/seam coverage complete.
- **Overall:** **Ready to merge.** Address the three 🟡 items as operational hardening (preferably in this PR, but none block correctness or violate the approved plan).
