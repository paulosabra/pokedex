# PR Readiness Review: T-31 Web Deploy on Vercel + C-1 Router Fix

**Branch**: `feature/quality-part4`  
**Base**: `main`  
**Date**: 2026-05-29  
**Reviewer**: Claude Code  

---

## Executive Summary

**Verdict**: READY TO MERGE (with environmental caveats)

PR4 introduces Vercel deployment machinery (T-31) and a critical router fix (C-1) that gracefully handles malformed or unknown deep links in the SPA. All mechanical checks pass: formatting is clean, static analysis is silent, no debug artifacts detected, commit hygiene is sound, and GitHub Actions security is hardened. The deploy workflow correctly isolates production from preview, pins dependencies, and uses a secure bash array pattern to protect secrets from shell injection.

**Caveats** (expected per plan §7.4):
- The deploy workflow will show red status (failed secret checks) until the user configures Vercel GitHub secrets (`VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`). This is expected and will resolve once secrets are added.
- Pre-existing uncommitted Firebase artifacts (T-30a work) are present in the working directory but NOT being committed in this PR; they are flagged for awareness only.

---

## 1. Formatting

**Status**: CLEAN

Ran `dart format --output=none --set-exit-if-changed` on all Dart source files in the PR:
- `lib/app/router/app_router.dart`
- `lib/app/router/route_error_screen.dart`
- `test/app/router/route_error_screen_test.dart`
- `integration_test/app_test.dart`

**Result**: All 4 files already properly formatted. No reformatting required.

---

## 2. Static Analysis

**Status**: CLEAN

Ran `dart analyze` on all Dart source files:
```
Analyzing app_router.dart, route_error_screen.dart, route_error_screen_test.dart, app_test.dart...
No issues found!
```

- Zero errors
- Zero warnings
- Zero info-level findings

---

## 3. Debug Artifacts

**Status**: CLEAN

Scanned all changed Dart source files for:
- **Print statements**: None found
- **debugPrint**: None found
- **TODO/FIXME/HACK comments**: None found (only legitimate documentation comments)
- **Commented-out code blocks**: None found
- **Test skip/focus annotations**: None found
- **Hardcoded secrets**: None found
- **Merge conflict markers**: None found

All comments are legitimate documentation explaining the C-1 fix and TE-03 behavior.

---

## 4. GitHub Actions Security Review

**File**: `.github/workflows/deploy.yml`  
**Status**: SECURE ✓

### 4.1 Workflow Injection Prevention

#### Secrets are NOT directly interpolated into run strings
- `SENTRY_DSN` and `POSTHOG_KEY` are declared in the `env:` section
- Secrets are referenced as bash variables (`$SENTRY_DSN`, `$POSTHOG_KEY`), not `${{ secrets.* }}` in the `run:` string
- This prevents shell injection if a secret value contains special characters

#### Untrusted input (github.ref) is only used in equality comparisons
```yaml
PROD: ${{ github.ref == 'refs/heads/main' && '--prod' || '' }}
TARGET_ENV: ${{ github.ref == 'refs/heads/main' && 'production' || 'preview' }}
```
- Both uses are safe boolean comparisons that resolve to literal strings or empty
- `github.ref` is never interpolated into shell commands

#### Bash array pattern protects against argument splitting
```bash
defines=(--dart-define=ENVIRONMENT="$TARGET_ENV")
if [ "$GITHUB_REF" = "refs/heads/main" ]; then
  defines+=(--dart-define=ANALYTICS_ENABLED=true)
  defines+=(--dart-define=SENTRY_DSN="$SENTRY_DSN")
  defines+=(--dart-define=POSTHOG_KEY="$POSTHOG_KEY")
fi
flutter build web --release "${defines[@]}"
```
- Each flag is a single array element with its value
- `"${defines[@]}"` expands each element as a separate argument (no word-splitting or globbing)
- Secrets with spaces or special characters remain intact and safe

**Audit Result**: No shell-injection vulnerabilities. Secrets are properly isolated and cannot leak into logs or command substitution.

### 4.2 Branch Restrictions

- Production deploy (`--prod` flag) only triggers on `push to main`
- Preview deploys trigger on all pull requests
- `epic/**` and `develop` are explicitly excluded (comments explain the policy)

### 4.3 Concurrency and Atomicity

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true
```
- Serializes deploys per ref so a newer push supersedes an in-flight deployment
- Prevents a stale deployment from racing a newer one to production

Build atomicity: The GitHub Actions runner enforces that all steps run sequentially within a job. A failed "Build Flutter web" step exits non-zero and prevents the "Deploy prebuilt artifact" step from running, guaranteeing a broken build cannot promote to production (I-5 requirement met).

### 4.4 Dependency Immutability

- Flutter SDK pinned to `3.44.0` (matches CI workflow, per comment §37–39)
- Vercel CLI pinned to `54.6.1` (prevents silent behavior changes mid-stream, per comment §51–54)
- `--enforce-lockfile` flag on `flutter pub get` ensures the deployed artifact is built from the exact locked dependency graph

### 4.5 Environment-Specific Configuration

Analytics and crash reporting differ between preview and production (§4.4 compliance):
- **Preview** (PR): `ANALYTICS_ENABLED` omitted → analytics disabled, `SENTRY_DSN` and `POSTHOG_KEY` not injected
- **Production** (main): `ANALYTICS_ENABLED=true`, full `SENTRY_DSN` and `POSTHOG_KEY` injected

This ensures preview builds stay dark and never emit telemetry to production analytics/crash projects.

---

## 5. YAML/JSON Validity

**Status**: VALID

### `.github/workflows/deploy.yml`
```
✓ Valid YAML syntax
✓ All required fields present
✓ Steps are well-ordered and complete
```

### `vercel.json`
```
✓ Valid JSON syntax
✓ Required fields: outputDirectory, rewrites, headers
✓ outputDirectory correctly points to build/web (Flutter web build output)
✓ SPA rewrite rewrites all paths to /index.html
✓ COOP/COEP headers set for SharedArrayBuffer support (Drift on web)
✓ Cache-Control header set to no-cache on index.html (fresh SPA on reload)
```

The `vercel.json` configuration correctly:
1. Outputs the Flutter web build artifact from `build/web`
2. Sets `framework: null` (custom framework; no Vercel-managed build)
3. Rewrites all paths to `index.html` (SPA rewrite for client-side routing)
4. Sets COOP/COEP headers to enable SharedArrayBuffer (required for Drift's `sqlite3.wasm`)
5. Cache-busts `index.html` to ensure fresh SPA loads

---

## 6. Scope and Commit Hygiene

### 6.1 PR4 Scope: T-31 Deploy + C-1 Router

**Changed Files** (all on-scope):
1. `.github/workflows/deploy.yml` (NEW) — Vercel deploy automation
2. `vercel.json` (NEW) — Vercel SPA configuration
3. `lib/app/router/app_router.dart` (MODIFIED) — C-1 fix: int.tryParse + errorBuilder
4. `lib/app/router/route_error_screen.dart` (NEW) — TE-03 error page
5. `test/app/router/route_error_screen_test.dart` (NEW) — Route error tests
6. `integration_test/app_test.dart` (MODIFIED) — E2E test for C-1 deep-link handling

All changes are tightly scoped to deploy machinery and the router fix. No unrelated files touched.

### 6.2 Commit Hygiene on feature/quality-part4

The branch contains the full merge history from main through T-30b (quality-part3):
- 770328f — Merge pull request #20 (quality-part3)
- 77a8d64 — docs(review): T-30b quality review reports
- ac480e6 — feat: wire PRD §12 analytics events (T-30b)
- ... (full upstream history)

The PR4 changes are currently **unstaged** (not yet committed):
```
 M integration_test/app_test.dart
 M lib/app/router/app_router.dart
?? .github/workflows/deploy.yml
?? lib/app/router/route_error_screen.dart
?? test/app/router/route_error_screen_test.dart
?? vercel.json
```

**Note**: Per the project's commit strategy, these will be staged and committed with a message like:
```
feat: web deploy on Vercel + C-1 route error handling (T-31)
```

### 6.3 Pre-Existing Uncommitted Firebase Artifacts

The working directory contains untracked files from T-30a observability work:
```
?? android/app/google-services.json
?? firebase.json
?? ios/Runner/GoogleService-Info.plist
?? macos/Runner/GoogleService-Info.plist
```

These are **NOT being committed in PR4** and should be added to `.gitignore` in a separate task. Per the task instructions, this is flagged for awareness but not a blocker for PR4 readiness.

---

## 7. Integration Test E2E Scope

The `integration_test/app_test.dart` E2E test is specifically designed for CI's separate `flutter drive` job (not `very_good test`). The test file includes:

**New Test**: `C-1: malformed and unmatched deep links render TE-03`
- Verifies `/pokemon/abc` (non-numeric) renders the error page
- Verifies `/no-such-route` (unmatched path) renders the error page
- Verifies the "Go home" CTA recovers to the home screen

This test validates the exact fix implemented in C-1 and can only run via `flutter drive` on web in CI (as documented in comments §89–92).

---

## 8. Environmental Notes

Per the plan (§7.4), the deploy workflow will fail on initial runs until the user configures three Vercel GitHub secrets in the repository settings:

1. **VERCEL_TOKEN** — Personal access token for Vercel CLI authentication
2. **VERCEL_ORG_ID** — Organization/team ID in Vercel
3. **VERCEL_PROJECT_ID** — Project ID in Vercel

Once these are added, the workflow will:
- Pull the Vercel environment config via `vercel pull`
- Build the Flutter web artifact
- Deploy to Vercel (production on `main`, preview on PRs)

This is expected and deliberate. The workflow is production-ready; it just needs the secrets to be activated.

---

## 9. Auto-Fixable Items

None. All checks passed. No formatting, analysis, or artifact issues require fixing.

---

## 10. Verdict

### READY TO MERGE

- [x] Formatting: Clean (0 files need reformatting)
- [x] Static analysis: Clean (0 errors, 0 warnings)
- [x] Debug artifacts: Clean (0 stray prints, TODOs, secrets, etc.)
- [x] GitHub Actions security: Hardened (no injection, proper secret isolation, atomicity enforced)
- [x] YAML/JSON validity: Valid
- [x] Scope and commit hygiene: Sound (tightly scoped to T-31 + C-1)

### Expected Next Steps

1. Stage the PR4 changes and commit with an appropriate message.
2. Open a PR from `feature/quality-part4` to `main`.
3. Wait for the CI and deploy workflows to run (deploy workflow will show red until Vercel secrets are added).
4. Once CI passes and the user adds the Vercel GitHub secrets, the deploy workflow will succeed.
5. Merge the PR.

**Note on Environmental Failures**: The deploy workflow will fail on secret validation until `VERCEL_TOKEN`, `VERCEL_ORG_ID`, and `VERCEL_PROJECT_ID` are configured in the repository's GitHub Actions secrets. This is expected and not a blocker for PR approval.
