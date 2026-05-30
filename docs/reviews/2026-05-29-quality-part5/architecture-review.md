# Architecture Review — PR5 (T-32: Final docs & CHANGELOG)

**Date:** 2026-05-29
**Scope:** Docs-only PR. Verify that architecture descriptions in the docs
faithfully match the actual codebase.
**Files under review:** `README.md`, `cliff.toml`, `CHANGELOG.md`,
`docs/adr/0001-…`, `docs/adr/0002-…`, `docs/adr/0003-…`.
**Method:** Each architectural claim in the docs was checked against the source
files it describes (`lib/`, `vercel.json`, `.github/workflows/deploy.yml`,
`pubspec.lock`, `web/`). This is a documentation-fidelity review, not a code
review of the implementation itself.

---

## Summary verdict

The ADRs (0001, 0002, 0003) are accurate and faithfully describe the code. The
README is overwhelmingly accurate, with **one factually incorrect architectural
claim**: the absolute statement that "the presentation layer never imports
`data` directly" is contradicted by three presentation-layer coordinators that
import a `data/` file. This is the only Critical finding. Everything else
checked clean.

---

## 1. Layer Separation — README `lib/` overview

The README (lines 17–40) describes a single-package, **feature-first** layout
with a layered `data → domain → presentation` flow and the explicit rule:

> "the presentation layer never imports `data` directly."

### Tree fidelity — accurate

The ASCII tree (lines 24–40) matches the real tree:

- `lib/main.dart`, `lib/bootstrap.dart`, `lib/firebase_options.dart`, `lib/app/`
  all present as described.
- `lib/core/` subdirs `database/`, `network/`, `error/`, `observability/`,
  `ui/`, `utils/`, `pokemon/` all present.
- `lib/features/pokemon/{data,domain,presentation}/` present with the described
  contents (DTOs + repository + Drift/Dio sources in `data/`; entities +
  `repositories/pokemon_repository.dart` interface in `domain/`; Riverpod
  view-models + screens/widgets in `presentation/`).

The directory-level claims are faithful.

### CRITICAL — "presentation never imports `data` directly" is false

Three presentation-layer files import a `data/` layer file directly:

- `lib/features/pokemon/presentation/coordinators/backfill_coordinator.dart:8`
  — imports `package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart`
- `lib/features/pokemon/presentation/coordinators/index_coordinator.dart:6`
  — same import
- `lib/features/pokemon/presentation/coordinators/generation_sample.dart:3`
  — same import

**Root cause (not a stray import):** the Riverpod provider
`pokemonRepository` is declared *inside the data-layer impl file*, at
`lib/features/pokemon/data/repositories/pokemon_repository_impl.dart:459–460`:

```dart
@riverpod
PokemonRepository pokemonRepository(Ref ref) => PokemonRepositoryImpl(…);
```

The provider returns the **abstract** `PokemonRepository` (domain type), so the
dependency on the *abstraction* is clean — but to obtain
`pokemonRepositoryProvider` at all, a presentation consumer must
`import` the data-layer file where that provider symbol lives. Reading the
provider (`ref.read(pokemonRepositoryProvider)`, see
`backfill_coordinator.dart:93,131`) is therefore impossible without the
forbidden import. The README's rule, as written, is an absolute the codebase
does not honor.

This is a **doc-vs-code mismatch**, which is the focus of this review. Two ways
to make the docs faithful (a code fix is out of scope for a docs-only PR, but
noted for the author's choice):

1. **Soften the doc claim** to match reality — e.g. "presentation depends on the
   domain `PokemonRepository` abstraction; the only data-layer import is the
   Riverpod provider declaration co-located with the repository
   implementation." This is honest and still communicates the intent.
2. **Move the provider** declaration out of the data impl file (e.g. into a
   `domain/` or a neutral DI file returning the abstract type) so presentation
   never needs a `data/` import — then the README's absolute claim becomes
   true. (Code change; defer to a non-docs PR.)

Note the asymmetry: the view-models, pages, widgets, and state files contain
**no** `data/` imports (verified) — only the three coordinators do. The
violation is narrow and provider-wiring-driven, not pervasive, but the README
states an unqualified absolute, so the claim is still incorrect as written.

### Shared `core/ui` independence — accurate

`lib/core/ui/components/{pokemon_card,stat_bar,type_badge}.dart` reference
`features/pokemon/domain/…` only in **doc comments** (explaining that the caller
supplies a domain-derived adapter); there are no actual `import` statements from
`core/ui` into `data/` or `domain/`. The shared UI toolkit is genuinely
portable, consistent with the README's framing.

---

## 2. ADR 0002 — Split observability interfaces — ACCURATE

Every architectural claim verified against `lib/core/observability/`:

| ADR 0002 claim | Code | Verdict |
| --- | --- | --- |
| Two separate interfaces in `lib/core/observability/` | `analytics_service.dart` (`AnalyticsService`), `error_reporter.dart` (`ErrorReporter`) | Match |
| `AnalyticsService { void logEvent(AnalyticsEvent event) }` | `analytics_service.dart:12–16` exact signature | Match |
| `ErrorReporter { void captureError(Object, StackTrace?, {Failure?}) }` | `error_reporter.dart:12–17` exact signature | Match |
| Each has its own Riverpod provider (`analyticsServiceProvider`, `errorReporterProvider`) | `observability_providers.dart:73–79` (`@riverpod analyticsService`, `@riverpod errorReporter`) | Match |
| Both default to a **Noop** | `analyticsService` → `NoopAnalyticsSink` (`sinks/noop_sink.dart`); `errorReporter` → `NoopErrorReporter` (`error_reporter.dart:21`) | Match |
| `bootstrap()` overrides with real fan-out (`CompositeAnalyticsSink`) + console/Sentry reporter | `bootstrap.dart:101–107` installs `observabilityOverrides`; `observability_providers.dart:117–123` overrides both providers; `buildAnalyticsSink` returns `CompositeAnalyticsSink` (line 112) | Match |
| Sealed `AnalyticsEvent`, one constructor per §12 event, only whitelisted props, no `Map<String,Object>` passthrough | `analytics_event.dart:34` `sealed class AnalyticsEvent`; **9** final subclasses (`ListViewed`, `SearchPerformed`, `FilterApplied`, `SortChanged`, `GenerationSelected`, `PokemonOpened`, `DetailTabChanged`, `EvolutionNavigated`, `ErrorShown`); each exposes a fixed `parameters` map, no free-form constructor | Match |
| Single package directory, no separate package split (D-5) | All observability files under `lib/core/observability/`, no separate pubspec | Match |

The "leaks no-ops" motivation is consistent with the adapter set on disk
(`firebase_analytics_adapter.dart`, `posthog_adapter.dart` implement
`AnalyticsService`; `sentry_error_reporter.dart` implements `ErrorReporter`).
ADR 0002 is faithful.

---

## 3. ADR 0001 — GitHub Actions builds, Vercel hosts prebuilt — ACCURATE

Verified against `.github/workflows/deploy.yml` and `vercel.json`:

| ADR 0001 claim | Code | Verdict |
| --- | --- | --- |
| GitHub Actions checks out, sets up Flutter `3.44.0` (same pin as `ci.yaml`) | `deploy.yml:38–46` `subosito/flutter-action@v2`, `flutter-version: 3.44.0` | Match |
| Regenerates code | `deploy.yml:55–56` `dart run build_runner build` | Match |
| `flutter build web --release` with env `--dart-define` flags | `deploy.yml:73–85` builds with a `--dart-define` array | Match |
| `vercel build` + `vercel deploy --prebuilt` | `deploy.yml:90–94` | Match |
| `vercel.json` sets `"framework": null` and `"outputDirectory": "build/web"` → Vercel does no build of its own | `vercel.json:3–4` `"outputDirectory":"build/web"`, `"framework": null` | Match |
| Production only on push to `main` | `deploy.yml:12–13` `push: branches: [main]`; `PROD` non-empty only on main (`deploy.yml:31`) | Match |
| Previews on every PR, analytics-dark | `deploy.yml:14` `pull_request:`; preview omits `ANALYTICS_ENABLED`/DSN/key (`deploy.yml:80–84`) | Match |
| Vercel CLI pinned `vercel@54.6.1`, never `@latest` | `deploy.yml:61` `npm i -g vercel@54.6.1` | Match |
| Atomic build→deploy: failed `flutter build` exits non-zero, job stops before deploy | Sequential steps; `flutter build web` (line 85) precedes `vercel build`/`deploy` (90–94); failure aborts the job | Match |
| `flutter pub get --enforce-lockfile` | `deploy.yml:51–52` | Match |

The SPA rewrite + security-headers claim ("Vercel only serves and applies the
SPA rewrites and security headers") is borne out by `vercel.json:5–22`
(`rewrites` to `/index.html`, COOP/COEP headers). ADR 0001 is faithful.

---

## 4. ADR 0003 — COOP/COEP and cross-origin artwork — ACCURATE

Verified against `vercel.json` and `lib/core/database/app_database.dart`:

| ADR 0003 claim | Code | Verdict |
| --- | --- | --- |
| COOP `same-origin` + COEP `require-corp` set in `vercel.json` for all routes | `vercel.json:7–13` `source:"/(.*)"` with both headers, exact values | Match |
| `require-corp` is the default (fall back to `credentialless` if artwork breaks) | `vercel.json` ships `require-corp`; ADR documents the swap as a remedy, not current state | Match |
| Drift runs SQLite in a Web Worker, sharing memory via `SharedArrayBuffer` (needs isolation) | `app_database.dart:173–179` `driftDatabase(web: DriftWebOptions(sqlite3Wasm:'sqlite3.wasm', driftWorker:'drift_worker.js'))` | Match |
| Verification on preview deploy, not local (`flutter run`/`flutter drive` don't emit COOP/COEP) | Headers live only in `vercel.json` (host layer); no local-serve header config exists | Consistent |

The README's "Web build & WASM assets" table (lines 264–289) claims
`sqlite3.wasm` "matches `2.9.4`" and `drift_worker.js` "matches `2.31.0`".
`pubspec.lock` resolves **`sqlite3 2.9.4`** and **`drift 2.31.0`** — the
documented version pairing is correct. Both binaries are present in `web/`
(`sqlite3.wasm`, `drift_worker.js`). ADR 0003 and the related README section are
faithful.

---

## 5. CHANGELOG.md / cliff.toml — in scope, no architectural claims

`CHANGELOG.md` is a git-cliff-generated Conventional-Commits log (header states
"generated … do not edit by hand"); `cliff.toml` is the generator config. Neither
makes architectural claims about `lib/` structure, so there is nothing to
fact-check against the code here. The README's Documentation section (lines
291–301) correctly points to `cliff.toml` as the config and `git-cliff -o
CHANGELOG.md` as the regen command — consistent with the files present.

---

## Findings ledger

### Critical (1)

1. **README:20–21 — "the presentation layer never imports `data` directly" is
   false.** Three presentation coordinators
   (`backfill_coordinator.dart:8`, `index_coordinator.dart:6`,
   `generation_sample.dart:3`) import
   `features/pokemon/data/repositories/pokemon_repository_impl.dart` to access
   the `pokemonRepository` Riverpod provider declared there
   (`pokemon_repository_impl.dart:459–460`). Either soften the README claim to
   reflect the provider-co-location reality, or relocate the provider so the
   absolute holds. The dependency on the *abstraction* (`PokemonRepository`) is
   clean; the import-path claim is what's inaccurate.

### Important (0)

None.

### Suggestions (2)

1. **README:36–40 vs `presentation/`** — the tree summarizes
   `presentation/` as "Riverpod view-models + screens/widgets" but omits the
   `coordinators/` subtree, which is exactly where the data-layer coupling lives.
   Naming `coordinators/` in the tree (and noting it holds the repository-provider
   consumers) would make the one real cross-layer touchpoint visible to readers
   rather than hidden behind a tidy summary.
2. **ADR 0002:38–40** — the ADR says providers default to "a **Noop**
   implementation" generically. Minor precision: the two Noop types are
   `NoopAnalyticsSink` (in `sinks/noop_sink.dart`) and `NoopErrorReporter` (in
   `error_reporter.dart`) — they live in different files. The claim is correct;
   spelling the type names would aid a reader navigating to them. Optional.

---

## Verdict

**Needs work — fix 1 architectural claim before merging.** The ADRs are
accurate and merge-ready. The README has a single incorrect absolute
("presentation never imports `data` directly") that the code contradicts in
three coordinator files; reword it (or relocate the provider in a follow-up) so
the documentation faithfully represents the dependency graph.
