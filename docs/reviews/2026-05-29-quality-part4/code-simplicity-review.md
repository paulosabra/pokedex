# Code Simplicity Review — PR4 (T-31: web deploy on Vercel)

**Branch:** `feature/quality-part4`
**Reviewer:** Code Simplicity Agent
**Date:** 2026-05-29

---

## Simplification Analysis

### Core Purpose

Deploy a pre-built Flutter web artifact to Vercel (PR→preview, main→production) and handle malformed deep links that the new SPA rewrite makes reachable.

---

### Unnecessary Complexity Found

#### 1. `route_error_screen.dart:29` — redundant `backgroundColor`

`RouteErrorScreen` sets `Scaffold(backgroundColor: AppColors.backgroundWhite, ...)` explicitly. `AppTheme.light` already sets `scaffoldBackgroundColor: AppColors.backgroundWhite` (verified in `lib/app/theme/app_theme.dart:17`), so this property has no effect and misleads the reader into thinking the screen needs its own override.

**Suggested simplification:** remove the `backgroundColor` argument from the `Scaffold`.

---

#### 2. `deploy.yml:24-25` — `TARGET_ENV` env var duplicates `PROD` logic

Two env vars (`PROD` and `TARGET_ENV`) express the same binary branch condition (`main` → prod, else → preview). `TARGET_ENV` drives `vercel pull --environment=` and the `--dart-define=ENVIRONMENT=` flag. `PROD` drives the `--prod` CLI flag. They are both derived from the same `github.ref` expression and could be collapsed, but the more meaningful question is whether `TARGET_ENV` is necessary at all. Because the Vercel CLI's `--prod` flag already communicates the environment to Vercel, `TARGET_ENV` only adds value for the `--dart-define` injected into the Flutter build. That use is real and worth keeping; having two separate env vars for the same conditional is acceptable given the clarity benefit. This is a minor observation, not a blocking issue.

---

#### 3. `deploy.yml:71-77` — bash array for `--dart-define` assembly (plan deviation, justified)

The plan (§7.4) proposed inlining the defines with `${{ format(...) }}`:

```yaml
flutter build web --release \
  --dart-define=ENVIRONMENT=$TARGET_ENV \
  ${{ github.ref == 'refs/heads/main' && format('...') || '' }}
```

The implementation instead uses a bash array:

```bash
defines=(--dart-define=ENVIRONMENT="$TARGET_ENV")
if [ "$GITHUB_REF" = "refs/heads/main" ]; then
  defines+=(--dart-define=ANALYTICS_ENABLED=true)
  defines+=(--dart-define=SENTRY_DSN="$SENTRY_DSN")
  defines+=(--dart-define=POSTHOG_KEY="$POSTHOG_KEY")
fi
flutter build web --release "${defines[@]}"
```

The deviation is **justified**: GitHub's `format()` expression inlines secret values as literal text in the evaluated command string, creating a shell-injection vector if a secret contains shell metacharacters. The bash array keeps each `--dart-define` a single argv entry regardless of the value's contents. The approach is correct and the comment explains it. However:

- The `if` branch tests `$GITHUB_REF` (the raw env var) while `PROD` and `TARGET_ENV` already capture the same condition at the top of the file. Using `$PROD` or `$TARGET_ENV` as the branch condition would avoid re-reading the ref and bring the logic into line with the established env vars:

  ```bash
  if [ -n "$PROD" ]; then   # PROD is '--prod' on main, '' elsewhere
  ```

  This is a minor readability improvement, not a correctness issue.

---

#### 4. `deploy.yml:22` — `VERCEL_TOKEN` in top-level `env` then re-used as `$VERCEL_TOKEN` in shell

`VERCEL_TOKEN` is declared as a top-level `env:` var (line 22) and then referenced as `$VERCEL_TOKEN` in the shell steps (lines 57, 83, 86). This is fine but note that the three `--token=$VERCEL_TOKEN` occurrences could be eliminated if the Vercel CLI respects the `VERCEL_TOKEN` environment variable natively (it does — the CLI reads `VERCEL_TOKEN` from the environment automatically). Removing the explicit `--token=` flags would reduce noise and remove the need for the env-var declaration. This is a suggestion only; keeping `--token=` explicit is defensible for clarity.

---

#### 5. `route_error_screen_test.dart:43-56` — GoRouter setup in the navigation test

The third test builds a full `GoRouter` with two routes in order to verify that tapping "Go home" calls `context.go('/')`. This is correct but slightly more ceremony than needed: `context.go('/')` could be verified by replacing the router with a `MockGoRouter` stub or by checking the route location after the tap. However, the current approach is straightforward and avoids mocking a framework type. Not a concern.

---

### Code to Remove

| File | Lines | Reason | Estimated LOC |
|------|-------|--------|--------------|
| `lib/app/router/route_error_screen.dart` | 29 (`backgroundColor:` line) | Redundant: `AppTheme.light` sets `scaffoldBackgroundColor` globally | 1 LOC |

Total potential removal: **1 LOC** across the reviewed files.

---

### Simplification Recommendations

#### 1. (Important) Remove redundant `backgroundColor` from `RouteErrorScreen`

- **Current:** `Scaffold(backgroundColor: AppColors.backgroundWhite, body: ...)`
- **Proposed:** `Scaffold(body: ...)`
- **Impact:** 1 LOC saved; removes a false signal that the screen needs to override the global theme

#### 2. (Suggestion) Use `$PROD` as the branch guard inside the bash array block

- **Current:** `if [ "$GITHUB_REF" = "refs/heads/main" ]; then`
- **Proposed:** `if [ -n "$PROD" ]; then`
- **Impact:** 0 LOC, but avoids a second reference to the raw ref string that is already captured by `PROD`; DRY-er

#### 3. (Suggestion) Consider removing explicit `--token=` from Vercel CLI calls

- **Current:** `vercel pull --yes --environment=$TARGET_ENV --token=$VERCEL_TOKEN` (and two other calls)
- **Proposed:** rely on the `VERCEL_TOKEN` env var the CLI already reads natively; remove `--token=` flags and the top-level `env: VERCEL_TOKEN:` declaration
- **Impact:** 4 LOC saved; reduces repetition; the env var is still secret-sourced so no security regression

---

### YAGNI Violations

None found. Every piece of the changeset maps directly to a stated requirement:

- `vercel.json`: SPA rewrites + COOP/COEP for SharedArrayBuffer (§7.3)
- `deploy.yml`: prod-on-main, atomic, dark previews (§7.4)
- `RouteErrorScreen`: TE-03 for malformed deep links (C-1 / §7.5)
- `tryParse` + `errorBuilder` in `app_router.dart`: C-1 fix
- `route_error_screen_test.dart`: three tests covering message render, analytics emit, and navigation — all exercising real behaviour
- `integration_test/app_test.dart` deep-link test: C-1 E2E, colocated with the fix

No extensibility points without use cases. No dead config. `$schema` in `vercel.json` gives editor validation and is worth its one line.

---

### Assessment of Key Design Questions

#### Is `RouteErrorScreen` the right minimal unit (vs inlining)?

Yes. The screen needs to be a `ConsumerWidget` to access `analyticsServiceProvider`, which means it cannot be a plain function or an anonymous builder. It is referenced in two independent places in `app_router.dart` (the `tryParse` branch and the `errorBuilder`) and has its own test file. Inlining a `ConsumerWidget` into a builder closure would require either a local `Consumer` wrapper at each call site or passing the `WidgetRef` down, both of which add more complexity than the file itself. The file is 43 lines including the doc comment; the abstraction is weight-bearing.

The only thing to remove from the class body is the redundant `backgroundColor` (see Recommendation 1).

#### Is the bash-array `dart-define` assembly justified?

Yes. The plan's inline `${{ format(...) }}` form interpolates secret values into the YAML expression evaluator before they reach the shell, which means a secret containing shell metacharacters could alter the command. The bash array form keeps each define as an opaque argv entry. The comment in the workflow explains this correctly. The deviation from the plan is an improvement, not a regression.

#### Is `deploy.yml` as simple as it can be while meeting §7.4?

Mostly yes. The two minor simplifications (use `$PROD` as the branch guard; drop explicit `--token=` flags) would trim 4-5 lines and reduce internal duplication, but neither is blocking.

---

### Final Assessment

**Total potential LOC reduction:** 1 line mandatory, 4-5 lines optional
**Complexity score:** Low
**Recommended action:** Minor tweaks only — remove the redundant `backgroundColor` (1 line); optionally apply the `$PROD` branch guard and `--token=` cleanup
