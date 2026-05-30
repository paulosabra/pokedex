# Code Simplicity Review — T-29 (Part 1: Test Pyramid & Coverage Gate)

**Branch:** `feature/quality-part1`
**Date:** 2026-05-29
**Scope:** `integration_test/app_test.dart`, `integration_test/helpers/e2e_harness.dart`,
`integration_test/helpers/fake_poke_api.dart`, `integration_test/helpers/in_memory_database.dart`,
`integration_test/helpers/in_memory_database_native.dart`, `integration_test/helpers/in_memory_database_web.dart`,
`test_driver/integration_test.dart`, `.github/workflows/ci.yaml`, `pubspec.yaml`, `pubspec.lock`

---

## Simplification Analysis

### Core Purpose

Add deterministic E2E coverage of two critical flows (UC-02/06: search→detail; UC-01: pagination)
using real Riverpod + Drift + Dio graphs seeded with in-memory I/O, and enforce an honest ≥80%
coverage gate on hand-written code only.

---

### Unnecessary Complexity Found

#### 1. `_NoopBackfillCoordinator` class — over-specified stub

**File:** `integration_test/helpers/e2e_harness.dart` lines 65–71

The harness defines a private subclass that overrides two methods:

```dart
class _NoopBackfillCoordinator extends BackfillCoordinator {
  @override
  BackfillProgress build() => BackfillProgress.idle();

  @override
  Future<void> start() async {}
}
```

`backfillCoordinatorProvider` exposes `overrideWithValue(BackfillProgress)` directly
(generated in `backfill_coordinator.g.dart` line 87). That single call short-circuits
the entire notifier — no `build()` is invoked, no `onConnectivityChanged` subscription
is installed — so the class and its two method overrides are unnecessary.

The replacement is a one-liner already available in the generated code:

```dart
backfillCoordinatorProvider.overrideWithValue(BackfillProgress.idle()),
```

**Why it matters:** The subclass approach is also subtly risky. `_NoopBackfillCoordinator`
overrides `build()` but does _not_ override the `_connectivitySub` wiring in
`BackfillCoordinator.build()` — because it skips calling `super.build()`. In the current
`FakeOnlineConnectivity` the stream is `Stream.empty()` so the subscription fires no
events, making the test pass. But the correctness depends on both the stream being empty
_and_ the override fully replacing build behaviour, which is not obvious to a future reader.
`overrideWithValue` eliminates the dependency entirely.

**Estimated reduction:** ~10 LOC (the class + its imports remain but the coordinator import
can be removed, ~2 lines net after replacing with the single override).

**Severity: Important**

---

#### 2. `FakeOnlineConnectivity` in `fake_poke_api.dart` — wrong home, duplicate of existing pattern

**File:** `integration_test/helpers/fake_poke_api.dart` lines 203–213

`FakeOnlineConnectivity` is a connectivity fake that has nothing to do with the PokéAPI.
It lives in `fake_poke_api.dart` only because that was a convenient place. This breaks
the single-responsibility principle of the file and makes both the file name and the
`FakePokeApi` class comment misleading.

There is also an existing `_FakeConnectivity` in `test/app/provider_graph_test.dart`
(lines 16–21) that is identical in substance. The two fakes implement the same interface
the same way, with the only difference being that the E2E version also implements
`onConnectivityChanged` (returning `Stream.empty()`).

**Suggested fix:** Move `FakeOnlineConnectivity` into its own file,
`integration_test/helpers/fake_connectivity.dart`, or inline the three-line override
directly into `e2e_harness.dart` (which is its only consumer). Shared test fakes that
appear in both `test/` and `integration_test/` are not reusable across the package
boundary, so there is no opportunity to deduplicate with the unit-test version.

**Estimated reduction:** 0 LOC net from the move, but improves readability and removes
the false implication that connectivity is an aspect of the PokéAPI fake.

**Severity: Suggestion**

---

#### 3. `in_memory_database.dart` one-liner forwarding file — marginal abstraction value

**File:** `integration_test/helpers/in_memory_database.dart` lines 1–13

The file is a three-line shim:

```dart
QueryExecutor inMemoryExecutor() => createInMemoryExecutor();
```

It exists to hold the conditional import and expose a stable name to `e2e_harness.dart`.
This pattern is correct and idiomatic for platform-conditional Drift setup — the split
is load-bearing because `drift/native.dart` cannot compile on the web target and
`drift/wasm.dart` cannot compile on the VM target. The plan (§5.3) explicitly calls
this out, and it matches the pattern used by Drift's own documentation.

**Assessment:** Not removable. The three-file split (`in_memory_database.dart`,
`_native.dart`, `_web.dart`) is the minimum correct structure for a compile-time
platform conditional. Flagged here only to document the conscious decision.

---

#### 4. Interceptors intentionally absent from `FakePokeApi.buildDio()` — documented correctly, no action needed

**File:** `integration_test/helpers/fake_poke_api.dart` lines 33–37

The comment says interceptors are omitted because the fake never produces the transient
429/5xx responses they handle, and their retry/backoff timers would add nondeterminism.
This is correct: `RateLimitInterceptor` and `RetryInterceptor` contain `Future.delayed`
calls for backoff. The decision is well-reasoned and aligns with the plan (§5.3).

**Assessment:** Correct as-is. Not a simplification opportunity.

---

#### 5. `_FakePokeApiAdapter.fetch` ignores `requestStream` and `cancelFuture` — intentional no-op

**File:** `integration_test/helpers/fake_poke_api.dart` lines 191–198

The `_FakePokeApiAdapter` implements `HttpClientAdapter` with a no-op `close()` and
ignores `requestStream`/`cancelFuture` in `fetch`. This is the correct minimal
implementation for a synchronous in-process fake — there is no network to cancel and
no request body to read. The same pattern appears in `QueueHttpAdapter` in
`test/helpers/queue_http_adapter.dart` lines 26–35.

**Assessment:** Correct and minimal. The `requestStream` parameter signature uses
`Stream<List<int>>?` here vs `Stream<Uint8List>?` in `QueueHttpAdapter`. Both compile
(Dart allows covariant list-type substitution in function parameters due to type erasure
at the call site), but the inconsistency is a readability micro-nit. Not a meaningful
simplification target.

---

#### 6. `cardNumber` helper function declared outside test groups — minor scoping issue

**File:** `integration_test/app_test.dart` lines 26–27

```dart
Finder cardNumber(int id) => find.text('#${id.toString().padLeft(3, '0')}');
```

This is declared inside `main()` but outside any `group()`. It is only used in the
two `testWidgets` calls. Moving it inside each test or into a local variable would
make the scope explicit, but the current placement is not wrong. Alternatively it
could be a top-level private helper `_cardNumber`. The current approach is readable
and the function is tiny. No action required.

---

#### 7. `tester.view.devicePixelRatio = 1` pin in `pumpApp` — legitimate fixture, not dead code

**File:** `integration_test/helpers/e2e_harness.dart` lines 37–41

The DPR pin ensures the 420px physical surface maps 1:1 to logical pixels so the
single-column layout is deterministic. The `addTearDown` calls correctly undo both
the DPR and the physical size. This is necessary plumbing for a deterministic E2E
surface, not over-engineering.

---

#### 8. `total = 48` default and the `_names` map — appropriate minimal fixture

**File:** `integration_test/helpers/fake_poke_api.dart` lines 20–29

The default of 48 (two pages of 24) is the minimum to exercise both pagination
(UC-01 requires a second page) and search (UC-02/06 requires at least one named
entry per page). The `_names` map with just `{1: 'bulbasaur', 25: 'pikachu'}` is
correctly minimal — the tests only assert on id 1 and id 48 (the tail of page 2).
`pikachu` at id 25 is present but unused in the current tests; however it sits inside
the first page so it costs nothing at runtime and provides a natural second search
anchor for any test that needs one. Not worth removing.

---

### Code to Remove

| File | Lines | Reason | Est. LOC reduction |
|------|-------|--------|--------------------|
| `integration_test/helpers/e2e_harness.dart` | 65–71 (class) + 52–54 (overrideWith call) | Replace `_NoopBackfillCoordinator` and `overrideWith` with `overrideWithValue(BackfillProgress.idle())` | ~10 LOC |
| `integration_test/helpers/e2e_harness.dart` | backfill_coordinator import line | No longer needed if subclass is removed | ~1 LOC |
| `integration_test/helpers/e2e_harness.dart` | backfill_progress import line | No longer needed if `BackfillProgress.idle()` comes from the provider override call (still needs the import for the value) | 0 |

Total estimated removal: **~8–10 lines**.

---

### Simplification Recommendations

#### 1. Replace `_NoopBackfillCoordinator` with `overrideWithValue`

**Current (`e2e_harness.dart` lines 50–71):**
```dart
backfillCoordinatorProvider.overrideWith(
  _NoopBackfillCoordinator.new,
),
// ...
class _NoopBackfillCoordinator extends BackfillCoordinator {
  @override
  BackfillProgress build() => BackfillProgress.idle();

  @override
  Future<void> start() async {}
}
```

**Proposed:**
```dart
backfillCoordinatorProvider.overrideWithValue(BackfillProgress.idle()),
```

**Impact:** removes the 8-line private class, removes one import
(`backfill_coordinator.dart`), and eliminates the subtle assumption that
`FakeOnlineConnectivity.onConnectivityChanged` returns an empty stream. The
`overrideWithValue` path uses `$SyncValueProvider` which bypasses the notifier
entirely — no constructor, no `build()`, no subscription wiring. The semantics
are exactly what the comment says: the backfill never runs.

**Severity: Important** — not a correctness bug today, but a maintenance trap
(the subclass silently relies on the stream being empty; `overrideWithValue`
makes the intent explicit and removes the dependency).

---

#### 2. Move `FakeOnlineConnectivity` out of `fake_poke_api.dart`

**Current:** `FakeOnlineConnectivity` lives at the bottom of `fake_poke_api.dart`
after the `_FakePokeApiAdapter`.

**Proposed:** Move to `integration_test/helpers/fake_connectivity.dart` (a new
~15-line file) or inline directly into `e2e_harness.dart` as a private class.
The `fake_poke_api.dart` file should contain only PokéAPI-specific fakes.

**Impact:** 0 LOC net; improves file cohesion and makes the `FakePokeApi` class
comment accurate.

**Severity: Suggestion**

---

### YAGNI Violations

None. The implementation is appropriately scoped to the §5.5 acceptance criteria:

- No extensibility hooks or abstract base classes are introduced.
- No unused configuration parameters.
- `test_driver/integration_test.dart` is the literal 2-line standard (as the plan
  requires — "do not add custom logic").
- CI jobs use `--enforce-lockfile` with no extra matrix or strategy configuration.
- `pubspec.yaml` adds only `integration_test: {sdk: flutter}` and `sqlite3: ^2.9.0`
  (the latter justified by the web in-memory executor needing `package:sqlite3/wasm.dart`
  which is otherwise only a transitive dep).
- The coverage awk one-liner does not use `lcov --summary` (it reads the filtered
  `.info` directly) — zero extra tools, zero extra flags.
- The lcov `--ignore-errors unused` flag is correct: without it lcov 2.x errors when
  a pattern matches nothing (the `*.drift.dart` / `*.config.dart` globs are forward-safety
  and will be unused until those generators are added).

---

### CI YAML Assessment

`.github/workflows/ci.yaml` is clean:

- The `build` job now uses `--enforce-lockfile` (matches acceptance criterion).
- The `e2e` job is a separate job (not a step in `build`), so `flutter drive` can
  never write into the `lcov.info` the coverage gate reads.
- The `--coverage` flag is correctly absent from the `flutter drive` call.
- The 4-glob `lcov --remove` matches the plan exactly (§5.2 note: `*.mocks.dart`
  intentionally absent; `*.drift.dart`/`*.config.dart` as forward-safety).
- The `sudo apt-get install -y lcov` step runs in the `build` job only, not in `e2e` —
  correct, since the E2E job does not need lcov.
- Both jobs pin `flutter-version: 3.44.0` and include the "Keep in sync" comment —
  appropriate given the golden stability rationale.

One minor observation: the `e2e` job does not declare a `needs: [build]` dependency.
This means it runs in parallel with the `build` job. That is acceptable (and faster)
since E2E is independent of the unit-test coverage result. The plan (§5.4) specifies
"separate job" without requiring sequencing, so this is consistent with the plan.

---

### Final Assessment

**Total potential LOC reduction:** ~10 lines (~2% of the new code)
**Complexity score:** Low
**Recommended action:** Minor tweak — apply the `overrideWithValue` replacement
before merging. Everything else is either correct-as-designed or a non-blocking
suggestion.

The implementation faithfully follows the §5 plan. The fake PokéAPI, in-memory
database split, and CI gate are all minimal and purposeful. The single meaningful
finding (`_NoopBackfillCoordinator`) is a maintenance trap rather than a live bug,
but it should be addressed because the simpler form is already available in the
generated code.
