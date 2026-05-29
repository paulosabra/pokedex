# Architecture Review — T-29 Part 1 (Test pyramid + coverage gate)

**Scope:** `integration_test/` (app_test, e2e_harness, fake_poke_api, in_memory_database + native/web variants), `test_driver/integration_test.dart`, `.github/workflows/ci.yaml`, `pubspec.yaml`, `pubspec.lock`.
**Plan:** `docs/plan/2026-05-28-feat-quality-and-release-plan.md` §5.
**Method:** read-only (local test runner is broken). Verified against pinned package sources in `~/.pub-cache` (drift 2.31.0, sqlite3 2.9.4) and the git working-tree diff vs `HEAD`.

---

## Verdict

**Architecture is clean — ready to merge.** Zero layer-boundary violations, zero test-only code leaking into `lib/`, the platform split for the in-memory Drift executor is correct, `package:drift/native.dart` is provably kept out of the web compile, and the analyzer-9 codegen pins in `pubspec.lock` are fully preserved (only `integration_test` + `sqlite3` added, with their SDK-transitive runner deps).

---

## 1. Layer Separation

The harness is built on a deliberate and correct architectural principle: **override only the leaf I/O providers, keep the real graph above them.** This is what makes it an integration test rather than a widget test, and it respects every layer boundary.

Overridden in `e2e_harness.dart` (all genuine I/O leaves or the one unbounded-fan-out coordinator):

| Provider | Layer | Override | Correct? |
| --- | --- | --- | --- |
| `appDatabaseProvider` | core/data (SQLite leaf) | `AppDatabase.forTesting(inMemoryExecutor())` | yes |
| `dioProvider` | core/network (HTTP leaf) | `FakePokeApi.buildDio()` | yes |
| `connectivityProvider` | core/network (platform-channel leaf) | `FakeOnlineConnectivity` | yes |
| `backfillCoordinatorProvider` | presentation/coordinator | `_NoopBackfillCoordinator` | yes — justified (unbounded background drain races `pumpAndSettle`) |

Everything between the leaves and the UI — remote data source, cache-first repository, use cases, view models, router — runs unmodified. That is the integration surface the plan (§5.3) asked for, and the override set is the minimum that achieves determinism.

**Test-imports-production direction is correct and one-directional.** `integration_test/` depends inward on `package:pokedex/...` (app, core, features). No production file under `lib/` imports anything from `integration_test/` or `test_driver/`.

**Verified — no test-only code leaks into `lib/`:** a full grep of `lib/` for `forTesting | inMemoryExecutor | integration_test | fake_poke_api | e2e_harness | FakePokeApi | E2EHarness` returns exactly one hit: `lib/core/database/app_database.dart:150 AppDatabase.forTesting(super.e)`. That named constructor is a legitimate, pre-existing seam (already used by the committed widget tests in `test/`), not new test-only code introduced into production by this PR. The in-memory executor, the fake API, and the harness all live under `integration_test/`.

- Violations found: **0**
- Clean files: all checked files clean.

---

## 2. Platform Split — conditional-import in-memory executor

`in_memory_database.dart` selects the backend with the standard drift idiom:

```dart
import 'in_memory_database_native.dart'
    if (dart.library.js_interop) 'in_memory_database_web.dart';
QueryExecutor inMemoryExecutor() => createInMemoryExecutor();
```

**The split is correct.** Confirmed by reading drift 2.31.0's own source: drift uses the identical `if (dart.library.js_interop)` guard to fence its web vs native implementations (e.g. `lib/src/runtime/api/runtime_api.dart:12`). Default branch = native (VM); the `js_interop` branch = web. This is the right key for the modern Wasm/`js_interop` toolchain (not the legacy `dart.library.html`).

**`package:drift/native.dart` is provably kept out of the web compile.** A repo-wide grep finds the import in exactly one place — `in_memory_database_native.dart:2` — which is only ever selected on the **default (non-`js_interop`)** branch. The web branch (`in_memory_database_web.dart`) imports only `package:drift/drift.dart`, `package:drift/wasm.dart`, and `package:sqlite3/wasm.dart`. Since conditional-import resolution is compile-time, the `dart:ffi`-backed `native.dart` is never reachable from a web (`flutter drive` headless Chrome) compilation unit. This is the load-bearing claim and it holds.

**Web executor APIs verified against pinned sources (sqlite3 2.9.4, drift 2.31.0):**

- `WasmSqlite3.loadFromUrl(Uri)` — exists (`sqlite3/lib/src/wasm/sqlite3.dart:46`).
- `InMemoryFileSystem()` — exists, no-arg constructor (`sqlite3/lib/src/in_memory_vfs.dart:18`), exported through `package:sqlite3/wasm.dart` via `common.dart:14 export ... show InMemoryFileSystem`.
- `registerVirtualFileSystem(vfs, makeDefault: true)` — public API present.
- `WasmDatabase.inMemory(sqlite3)` — factory takes a positional `CommonSqlite3` (`drift/lib/wasm.dart:82`), matching the call site.

The web variant deliberately uses an in-memory VFS with no `SharedArrayBuffer` / OPFS dependency, so it runs identically under `flutter drive`'s web-server (which emits no COOP/COEP) — exactly the determinism rationale in plan §5.3 and the C-4/C-5 risk mitigations.

- Platform-split issues: **0**

---

## 3. Dependency Direction

The dependency graph flows one way and is acyclic:

```
integration_test/app_test.dart
  └─> helpers/e2e_harness.dart
        ├─> package:pokedex/app/app.dart            (presentation root)
        ├─> package:pokedex/core/...                (data/network leaves)
        ├─> package:pokedex/features/.../coordinators
        ├─> helpers/fake_poke_api.dart              (dio/connectivity fakes)
        └─> helpers/in_memory_database.dart
              └─(conditional)─> _native.dart | _web.dart
test_driver/integration_test.dart  └─> integration_test/integration_test_driver.dart (SDK)
```

- No production package depends on test code (reverse dependency): **none**.
- Circular dependencies: **none**.
- `_NoopBackfillCoordinator extends BackfillCoordinator` overriding `build()` and `start()` with `overrideWith(_NoopBackfillCoordinator.new)` is the correct Riverpod-3 notifier-override form; signatures match the production `@Riverpod(keepAlive: true) class BackfillCoordinator` (`build() => BackfillProgress`, `Future<void> start()`).

- Direction violations: **0**

---

## 4. Package / Manifest Structure

Single-package app (per decision D-5: no package split for this layout). Reviewed the manifest deltas:

**`pubspec.yaml` (working-tree diff vs HEAD):** two additions, both in `dev_dependencies`, both justified by comments:

- `integration_test: { sdk: flutter }` — the E2E runner. Correct placement (dev-only).
- `sqlite3: ^2.9.0` — promoted from transitive to a direct dev dep so the web executor can import `package:sqlite3/wasm.dart`. The range tracks the version already pulled transitively via `sqlite3_flutter_libs`; resolved version is unchanged (`2.9.4`).

No production (`dependencies`) entries were touched. `test_driver/integration_test.dart` is the literal 2-line `integrationDriver()` standard entrypoint with no custom logic, as the plan mandated.

**`pubspec.lock` (working-tree diff vs HEAD) — the analyzer-9 pin claim holds.** The package-level diff shows **only**:

- `integration_test` → `direct dev` (new), `version: "0.0.0"` (SDK).
- `sqlite3` → flipped `transitive` → `direct dev`; **version line unchanged** (`2.9.4`).
- SDK-transitive runner deps newly surfaced by `integration_test`: `flutter_driver`, `fuchsia_remote_debug_protocol`, `process` (5.0.5), `sync_http` (0.3.1), `webdriver` (3.1.0). All expected, all from the Flutter SDK / its closure.

Crucially, **none** of the codegen-pin packages changed: `analyzer` stays `9.0.0`, `_fe_analyzer_shared` `92.0.0`, `source_gen` `4.2.3`, `drift_dev` `2.31.0`, `freezed` `3.2.5`, `riverpod_generator` `4.0.3`, `build_runner` `2.15.0`, `json_serializable` `6.13.0`, `drift` `2.31.0`, `drift_flutter` `0.2.8`. The analyzer-9 stable codegen line that the exact pins exist to fence is intact — the new deps are pure runtime/test additions that don't drag the analyzer toolchain.

> Note: `main` carries no `pubspec.lock` (the entire project is greenfield relative to `main`), so the meaningful baseline is the prior committed lock on this branch (`HEAD`). The diff above is against `HEAD`, which is the correct comparison.

- Structure issues: **0**

---

## 5. CI Workflow (`ci.yaml`) — architectural correctness

Not a layering concern, but reviewed for the "E2E is not in the coverage gate" boundary the plan treats as load-bearing:

- E2E runs in a **separate `e2e` job**; `flutter drive` is invoked **without `--coverage`** (commented explicitly), so it cannot write into the `lcov.info` the `build` job's gate measures. The honest-gate boundary is preserved.
- Coverage gate strips the 4 generated globs (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`, `*.config.dart`) and enforces ≥80% via the zero-dependency awk check — not `very_good test --min-coverage`. Matches §5.2 exactly.
- Both jobs use `flutter pub get --enforce-lockfile`, so both measure the locked graph (the pin fence is enforced at install time).

One **suggestion** (non-blocking, not an architecture violation): the `e2e` job starts ChromeDriver on `--port=4444` in a background step, but the `flutter drive` invocation does not pass a matching `--driver-port`/Selenium address and relies on `web-server --browser-name chrome --headless`. Under `flutter drive -d web-server`, Flutter manages its own ChromeDriver handshake, so the manually-started `chromedriver` on 4444 may be redundant (or, if `flutter drive` expects 4444, it is conventionally the default). This is a CI-wiring detail to confirm on first green run; it does not affect any architectural boundary and the broken local runner prevents confirming it by reading alone.

---

## Summary of findings

| Severity | Finding |
| --- | --- |
| — | No critical issues. |
| — | No important issues. |
| Suggestion | `e2e` job's manual `chromedriver --port=4444 &` may be redundant under `flutter drive -d web-server` (Flutter manages the driver). Confirm on first CI run; no boundary impact. |

**Layer separation:** clean. **Platform split:** correct, native fenced off web. **Dependency direction:** acyclic, one-way. **Codegen pins:** preserved. **Test-only code in `lib/`:** none.
