# 1. GitHub Actions builds the web artifact; Vercel hosts it prebuilt

- **Status:** Accepted
- **Date:** 2026-05-29
- **Deciders:** Paulo Sabra
- **Context task:** T-31 (Quality & Release epic)

## Context

The MVP ships as a Flutter **web** app that must be reachable at a public,
deep-linkable URL (PRD; DoD §12). Vercel is the chosen host. The open question
was **where the Flutter toolchain runs**:

1. **Vercel builds it.** Vercel has no first-class Flutter runtime. A custom
   `build.sh` would have to download and install the Flutter SDK inside Vercel's
   build container on every deploy — slow, and the SDK version would float
   unless pinned by hand against a platform we do not control.
2. **GitHub Actions builds it; Vercel hosts the prebuilt output.** The Flutter
   SDK is already pinned to `3.44.0` in CI (golden-test stability depends on the
   exact engine/Skia + bundled font). Reusing that same pinned toolchain to run
   `flutter build web --release` and shipping the resulting `build/web/` to
   Vercel via `vercel deploy --prebuilt` keeps one source of truth for the SDK
   version.

## Decision

**GitHub Actions builds; Vercel hosts the prebuilt artifact.**

`.github/workflows/deploy.yml` checks out the repo, sets up Flutter `3.44.0`
(the same pin as `ci.yaml`), regenerates code, runs `flutter build web
--release` with the environment's `--dart-define` flags, then `vercel build` +
`vercel deploy --prebuilt`. `vercel.json` sets `"framework": null` and
`"outputDirectory": "build/web"` so Vercel performs **no** build of its own — it
only serves and applies the SPA rewrites and security headers.

- **Production** publishes only on a push to `main`.
- **Previews** run for every pull request and stay analytics-dark (§4.4).
- The Vercel CLI is **pinned** (`vercel@54.6.1`), never `@latest`, so a CLI
  release cannot silently change deploy behaviour mid-stream.

## Consequences

**Positive**

- One pinned Flutter version drives both CI and deploy — no version drift, and
  goldens, the coverage gate, and the shipped artifact all agree.
- Builds are reproducible: `flutter pub get --enforce-lockfile` ties the deploy
  to the exact locked dependency graph (including the analyzer-9 codegen pins).
- The build → upload → promote sequence is **atomic**: a failed `flutter build`
  exits non-zero and the job stops before `vercel deploy`, so a broken build can
  never promote (resolves I-5).

**Negative / trade-offs**

- Deploys depend on GitHub Actions availability, not just Vercel's.
- Generated code must be rebuilt in CI on every deploy (it is git-ignored), so a
  cold deploy pays the `build_runner` cost. Acceptable for an MVP cadence.
- Secrets (`VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`, plus the
  observability keys) live in GitHub, requiring the one-time `vercel link`
  bootstrap documented in the README runbook.

**Rejected alternative:** a Vercel-side `build.sh` that installs Flutter at
deploy time — slower, an unpinned/duplicated SDK version, and no reuse of the
already-trusted CI toolchain.
