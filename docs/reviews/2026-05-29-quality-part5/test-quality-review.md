# Test Quality Review — PR5: T-32 Final Docs & CHANGELOG

**Date:** 2026-05-29
**Branch:** feature/quality-part5
**Scope:** Docs-only PR — README.md, cliff.toml, CHANGELOG.md, docs/adr/0001–0003

---

## 1. Production Code Change Verification

**Finding: No application or test code was introduced in PR5.**

The commits on `feature/quality-part5` beyond the PR4 merge base (`40fadc8`) are
zero. All PR5 deliverables (full README.md, cliff.toml, CHANGELOG.md,
docs/adr/0001–0003) exist in the working tree but have not yet been committed. A
`git diff main...HEAD -- '*.dart' '*.yaml' '*.yml'` confirms no new Dart source
files and no CI workflow changes are attributable to this PR. The CI workflow
changes visible in the `main…HEAD` diff belong to earlier PRs (T-29, T-31) already
merged into the epic branch.

**Conclusion: This is a docs-only PR. No tests are required and none are missing.**

---

## 2. Documented Command Verification

### 2.1 CHANGELOG Regeneration (`git-cliff -o CHANGELOG.md`)

**Status: Correct and reproducible.**

The command `git-cliff -o CHANGELOG.md` (documented in the README Documentation
section and in cliff.toml's header comment) was executed from the repo root.
`git-cliff` auto-detects `cliff.toml` in the current working directory — the
`--config` flag is not needed. The regenerated output is byte-for-byte identical to
the committed `CHANGELOG.md`. The 22-commit skip warning (`process_commits: 22
commit(s) were skipped due to parse error(s)`) is expected: `cliff.toml` sets
`filter_unconventional = true`, so merge commits and non-Conventional-Commit
messages are intentionally excluded.

### 2.2 E2E `flutter drive` Command

**Status: Command flags are correct; prerequisite is undocumented (see Important finding).**

The README documents:

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server --browser-name chrome --headless
```

This is a verbatim copy of the CI step in `.github/workflows/ci.yaml` (lines
117–120). The flags, paths, and device target match exactly. The
`test_driver/integration_test.dart` file exists and contains the standard two-line
`integrationDriver()` entrypoint. The three E2E test cases in
`integration_test/app_test.dart` match the README's claim of "search → detail,
pagination, deep-link errors" (UC-02/06, UC-01, C-1 respectively).

**Issue (Important):** `flutter drive -d web-server` requires ChromeDriver to be
running on port 4444 before the command is issued. CI handles this with a dedicated
"Start ChromeDriver" step that polls `/status` before proceeding. The README omits
this prerequisite entirely. A developer following the documented command will
receive "Unable to connect to ChromeDriver" and have no guidance on how to resolve
it.

### 2.3 Quality Check Commands

**Status: Intentional divergence from CI; adequately explained.**

| Command in README | Command in CI | Assessment |
|---|---|---|
| `dart format .` | `dart format --set-exit-if-changed .` | Intentional: README is for local dev (mutates files); CI checks only. |
| `dart analyze --fatal-infos --fatal-warnings` | `flutter analyze --fatal-infos --fatal-warnings` | Intentional: README explains `flutter analyze` can crash the analysis server locally; `dart analyze` is the recommended local substitute. The note is present inline. |
| `flutter test --coverage` | `flutter test --coverage` | Identical. |

The README's inline note (lines 98–100) explains the `dart analyze` vs
`flutter analyze` divergence. The format divergence is a conventional and
reasonable difference between local workflow and CI gate; no explanation is needed.

### 2.4 `flutter pub get` vs `--enforce-lockfile`

**Status: Minor inconsistency (Important finding).**

The README's "Clone, build, run" step reads:

```bash
# 2. Fetch dependencies (use --enforce-lockfile to match CI exactly)
flutter pub get
```

The inline comment instructs the reader to use `--enforce-lockfile` but the command
itself omits the flag. CI uses `flutter pub get --enforce-lockfile` in both the
`build` and `e2e` jobs. A developer copying the command verbatim will silently omit
the flag despite the comment's instruction. The fix is to either include the flag in
the command or reword the comment to acknowledge the deliberate omission (e.g. "CI
uses `--enforce-lockfile`; omit locally if you need to resolve a newer version").

### 2.5 Sentry Verify Procedure

**Status: Correct.**

The Sentry verify section (`flutter run -d chrome --dart-define=SENTRY_DSN=…`)
correctly uses `flutter run` (not `flutter drive`), so no ChromeDriver dependency
exists here. The DSN placeholder format `https://<key>@<org>.ingest.sentry.io/<project>`
is the canonical Sentry DSN format; Sentry accepts both the legacy
`ingest.sentry.io` and the newer region-specific hostnames (`ingest.us.sentry.io`)
for the same project, so the placeholder is not misleading. The requirement to pass
`ANALYTICS_ENABLED=true` alongside `SENTRY_DSN` is accurate: the bootstrap
conditionally routes errors through Sentry only when both flags are set.

### 2.6 PostHog Verify Procedure

**Status: Correct and appropriately scoped.**

The PostHog verify step uses `-d macos`, not `-d chrome`, consistent with the
README's explanation that the PostHog adapter no-ops on web (a web/index.html
snippet would fire on every preview regardless of flags). This is accurate: the
`PostHogAdapter` explicitly guards on platform. The `POSTHOG_HOST` default
(`https://us.i.posthog.com`) matches the value in
`lib/core/observability/observability_providers.dart`.

### 2.7 Vercel Rollback / Promote Commands

**Status: Commands are valid for pinned CLI version.**

The README documents three rollback commands using `--token=$VERCEL_TOKEN`:
`vercel rollback`, `vercel promote <url>`, and `vercel ls`. All three exist in
Vercel CLI 54.6.1 (the pinned version). The `--token` flag is passed consistently,
matching the deploy workflow's pattern and the noted requirement that the CLI does
not read `VERCEL_TOKEN` from the environment for `vercel pull`. The shell variable
`$VERCEL_TOKEN` is appropriate for a manual runbook step where the reader would
export the token beforehand.

### 2.8 CI Badge

**Status: Correct.**

The badge URL references `paulosabra/pokedex` (verified from `git remote get-url
origin`) and `ci.yaml` (the actual workflow filename — not `ci.yml`). The link
target URL also resolves to the correct GitHub Actions workflow page.

### 2.9 Web Build & WASM Assets Version Table

**Status: Correct.**

The README claims `sqlite3.wasm` matches `sqlite3` package version `2.9.4` and
`drift_worker.js` matches `drift` version `2.31.0`. Both are confirmed from
`pubspec.lock` (`sqlite3: 2.9.4`) and `pubspec.yaml` (`drift: 2.31.0`).

### 2.10 Architecture Tree

**Status: Accurate.**

All directories and files listed in the `lib/` tree (main.dart, bootstrap.dart,
firebase_options.dart, app/, core/, features/pokemon/{data,domain,presentation})
exist in the actual repository structure.

### 2.11 `--dart-define` Flag Table

**Status: Matches implementation.**

The five flags (`ANALYTICS_ENABLED`, `SENTRY_DSN`, `POSTHOG_KEY`, `POSTHOG_HOST`,
`ENVIRONMENT`) and their defaults match the `String.fromEnvironment` /
`bool.fromEnvironment` calls in
`lib/core/observability/observability_providers.dart`. The note that
`ANALYTICS_ENABLED` cannot vary by build mode via a `fromEnvironment` default is
correct: Dart compile-time constants are fixed at build time.

---

## 3. ADR Quality Check

### ADR 0001 — GitHub Actions builds, Vercel hosts prebuilt

The stated decision (`vercel build` + `vercel deploy --prebuilt`, `framework: null`
in vercel.json, `outputDirectory: build/web`) is confirmed accurate against
`deploy.yml` (lines 91–94) and `vercel.json`. The claimed production-only trigger
(`push to main only`) is verified in `deploy.yml`'s `on.push.branches: [main]`.

### ADR 0002 — Split observability interfaces

The two interfaces (`AnalyticsService`, `ErrorReporter`), their Riverpod providers,
the Noop default, and the `CompositeAnalyticsSink` are all present in
`lib/core/observability/`. The sealed `AnalyticsEvent` type with whitelisted
properties is present in `analytics_event.dart`.

### ADR 0003 — COOP/COEP and cross-origin artwork

The decision to default to `require-corp` with a fallback to `credentialless` is
documented. The ADR correctly identifies that COOP/COEP headers are emitted only by
the host (Vercel), not by `flutter run` or `flutter drive`'s web-server, so local
dev cannot reproduce the behavior. The verification step ("check on the Vercel
preview, not local dev") is sound.

---

## 4. Findings Summary

### Critical Issues

None.

### Important Issues

**I-1: `flutter drive` prerequisite (ChromeDriver) not documented**

The E2E section of the README documents the `flutter drive` command verbatim from
CI but omits the prerequisite that ChromeDriver must be running on port 4444 first.
CI's "Start ChromeDriver" step handles this automatically; a developer following the
README will hit a connection error with no guidance.

**Suggested fix:**

```bash
### End-to-end tests

E2E flows run on headless Chrome … deterministic, no network:

```bash
# 1. Start ChromeDriver (install via `brew install chromedriver` or the Dart
#    `chromedriver` pub package; CI uses nanasess/setup-chromedriver@v2):
chromedriver --port=4444 &

# 2. Drive the app:
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server --browser-name chrome --headless
```

**I-2: `flutter pub get` comment contradicts the command**

Line 75 of the README says "(use --enforce-lockfile to match CI exactly)" but line
76 shows the command without the flag. The inconsistency will cause readers to either
ignore the comment or manually add a flag not shown in the code block.

**Suggested fix:** Either include the flag in the command:

```bash
flutter pub get --enforce-lockfile
```

Or reword the comment to acknowledge why the flag is omitted locally (e.g.
`--enforce-lockfile` can break if you intentionally want to pick up a newer
resolution; use it only when reproducing CI exactly).

### Suggestions

**S-1: CHANGELOG does not yet include the T-32 docs commit**

This is expected and correct behavior — CHANGELOG.md is generated from the commit
history at the time of generation; the T-32 docs commit has not been made yet.
After the PR5 commit is landed, run `git-cliff -o CHANGELOG.md` once more and
amend/update the CHANGELOG so the docs commit appears in the unreleased section.

**S-2: cliff.toml `filter_commits = false` with `sort_commits = "newest"`**

`filter_commits = false` means all conventional commits reach the template. The
22-commit skip warning from `filter_unconventional = true` is expected, but the
combination means the `chore(release)` skip rule (lines 51–52) is only exercised if
such commits appear. Not a bug, but worth noting that the two skip rules could be
consolidated if the commit vocabulary expands. No action required for this PR.

---

## 5. Verdict

**Ready to merge after resolving 2 important issues (I-1, I-2).**

No critical issues. The CHANGELOG is reproducible, the CI badge is accurate, the
`flutter drive` flags exactly match CI, the ADRs faithfully record the implemented
decisions, and all version claims are verified against pubspec.lock. The two
important issues are both README-only text fixes requiring no code change.
