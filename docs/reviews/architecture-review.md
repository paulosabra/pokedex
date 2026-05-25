# Architecture Review — PR2 (T-03 · Error core)

- **Scope:** `lib/core/error/failure.dart`, `lib/core/error/result.dart`, `test/core/error/*`
- **Branch:** `feature/foundation-part2` → `epic/foundation`
- **Plan:** `docs/plan/2026-05-24-chore-foundation-setup-plan.md` § "PR2 — Error core"
- **Architecture:** single-package, feature-first Clean Architecture; `core/` is a transversal **pure leaf**.
- **Reviewed:** 2026-05-24

---

## Summary

PR2 adds the typed error vocabulary (`Failure` hierarchy + `Result<T>`) at `lib/core/error/`.
The placement, dependency direction, and sealed-type design are architecturally sound and match
the Tech Spec (§7.3 / §8.1) and the approved plan. No upward imports exist; the layer is a true
leaf. The only non-pure-Dart coupling — `@immutable` from `flutter/foundation` — is justified and
acceptable for a single-package Flutter app. This review found **no Critical and no Important
issues**.

---

## Critical

_None._

---

## Important

_None._

---

## Minor

### M-1 — `Result` is not annotated `@immutable` for symmetry with `Failure`

- `lib/core/error/result.dart:4` — `Result<T>`, `Ok<T>`, and `Err<T>` are sealed/final with
  `const` constructors and `final` fields, so they are effectively immutable. But unlike
  `Failure` (`lib/core/error/failure.dart:9`), they carry no `@immutable` annotation.
- This is stylistic, not a defect — the classes are already immutable in practice. Adding
  `@immutable` to `Result` would make the contract explicit and consistent with `Failure`, and
  the `flutter/foundation` import is already paid for in this package (see S-1). Note: `Ok<T>`
  holds a `T value` whose runtime instance may itself be mutable, so `@immutable` would be a
  shallow guarantee — acceptable, and the same caveat the analyzer already tolerates everywhere.
- **Not blocking.** Leave as-is or annotate; either is defensible.

---

## Suggestion

### S-1 — `@immutable` via `flutter/foundation` is the correct call (assessment, not a change)

- `lib/core/error/failure.dart:1` imports `package:flutter/foundation.dart` for `@immutable`.
  The task asked whether this Flutter coupling is acceptable in a leaf that is otherwise pure
  Dart. **It is, for this project.** Rationale:
  - This is a **single-package Flutter app**, not a published pure-Dart package. `flutter` is
    already a direct dependency of the only package; `core/error` will never be extracted or
    consumed by a Dart-only (server/CLI) target where dragging in Flutter would be a cost.
  - `@immutable` is an analyzer-only annotation with **zero runtime footprint** — it does not
    pull Flutter widgets, bindings, or platform channels into the call graph.
  - Verified `meta` is **not** a direct dependency in `pubspec.yaml`. Reusing the already-present
    `flutter` SDK dep to source `@immutable` avoids adding `meta` solely for one annotation,
    which is the leaner choice and matches the plan's incremental-deps / YAGNI posture.
- **If** this code were ever promoted to a shared pure-Dart package (it is not on the roadmap),
  the fix is a one-line import swap to `package:meta/meta.dart`. No structural change required.
  No action needed now.

### S-2 — Consider whether `core/error/` will need an `exceptions` slot before T-06

- Tech Spec §3 describes `core/error/` as holding "Failure, Result, **exceptions**." PR2 ships
  `Failure` + `Result` only, which is correct for this slice (no Dio yet). When T-06 maps Dio
  exceptions → `Failure`, decide deliberately whether intermediate exception types live here or
  whether the error mapper in `core/network/` consumes Dio's own exceptions directly and emits
  `Failure`. The current design supports either — flagging only so the §3 "exceptions" note
  isn't silently dropped. No action this PR.

---

## Detailed validation against the task questions

### 1. Is `core/error/` correctly a leaf (no upward imports)?

**Yes.** Verified by scanning all imports in `lib/core`:

- `lib/core/error/failure.dart` imports only `package:flutter/foundation.dart`.
- `lib/core/error/result.dart` imports only `package:pokedex/core/error/failure.dart` (intra-leaf).
- No imports of `features/`, `app/`, or any `data` / `domain` / `presentation` path exist
  anywhere under `lib/core` (`grep` for `features/|app/|presentation|data/|domain/` → none).
- Inbound check: nothing outside `lib/core/error/` imports the error core yet (expected — its
  consumers, data/domain, arrive in later layers). No premature coupling.

`core/error` is a genuine transversal pure leaf, exactly as the plan's Technical Considerations
("`core/error` is leaf") and Tech Spec §3 ("código realmente transversal vive em `core/`") require.

### 2. Is `Result` depending on `Failure` (and not vice-versa) sound?

**Yes — the dependency direction is correct and one-way.**

- `result.dart` → `failure.dart` (`Err.failure` is typed `Failure`). `failure.dart` has **no**
  reference to `Result`. No cycle.
- This is the right direction: `Result<T>` is the generic success/error envelope, and the error
  arm must name a concrete error vocabulary. `Failure` is the more primitive concept (it has
  meaning independent of `Result`), so it belongs "below." A reverse dependency (`Failure`
  knowing about `Result`) would be an abstraction inversion. Clean.

### 3. Will this vocabulary serve the later data/domain layers cleanly?

**Yes.** The `Failure` subtypes are a 1:1 transcription of Tech Spec §7.3's Dio→Failure→TE map:
`NetworkFailure` (TE-01/02), `TimeoutFailure` (TE-06), `NotFoundFailure` (TE-03),
`ServerFailure` (TE-07), `RateLimitFailure` (TE-08), `ParsingFailure` (TE-09), `CacheFailure`
(TE-01). The T-06 mapper (`DioExceptionType.connectionError → NetworkFailure`, etc.) will switch
over Dio exception types and construct these directly — the default-message constructors
(`const NetworkFailure([super.message = 'offline'])`) make that mapping terse. Use cases
returning `Result<T>` (Tech Spec §4.1, `call(...) → Result<T>`) compose with `Ok`/`Err` without
any added abstraction. The vocabulary is complete for the planned data/domain needs and the
many-to-one TE mapping is documented in the doc comment (`failure.dart:5-6`).

### 4. Is the sealed-type design appropriate for exhaustive handling?

**Yes — this is the canonical reason to use sealed types here.**

- `sealed class Failure` + `final` subtypes (`failure.dart:10`, `:30-69`) and `sealed class
  Result<T>` + `final Ok`/`Err` (`result.dart:4`, `:10`, `:19`) give the analyzer closed-world
  knowledge, so `switch` over a `Result`/`Failure` is exhaustiveness-checked at compile time.
- The test at `test/core/error/result_test.dart:22-30` exercises exactly this — a `switch`
  expression with no `default`, which only compiles because the hierarchy is sealed. Adding a new
  `Failure` later will force every exhaustive `switch` to be updated (the desired safety net for
  the presentation layer's failure→message mapping).
- `final` (not `base`/`sealed`) on the leaves is appropriate: subtypes are concrete and should
  not be extended further. Good.

### 5. Equality contract

`Failure` hand-rolls `==`/`hashCode` over `[runtimeType, message]` (`failure.dart:17-25`),
matching the plan's pinned contract. Using `runtimeType` (not `is`) correctly makes
`NetworkFailure('x') != CacheFailure('x')` even though both map to TE-01 — verified by
`failure_test.dart:33-36`. Inequality on same-type/different-message is covered
(`failure_test.dart:29-31`). This is the architecturally important property: `Failure` values are
comparable, so they flow safely through `Result` into Riverpod `AsyncValue.error` /
UI-state equality without spurious rebuilds. `Result` itself has no value equality — acceptable,
since equality is delegated to its payload (`T` or `Failure`) at the use sites that need it.

---

## Layer Separation

- Violations found: **0**
- Clean files: `lib/core/error/failure.dart`, `lib/core/error/result.dart` (all checked files clean)

## Dependency Direction

- Direction violations: **0** · Circular dependencies: **0**
- Clean: `result.dart → failure.dart` (one-way, intra-leaf); `core/error` depends on nothing in
  `features/`, `app/`, or any layer above it.

## Package / Module Structure

- Single package; `core/error/` is a focused module with one clear responsibility (typed error
  vocabulary). Test mirror exists at `test/core/error/`. Files are well-sized and YAGNI-correct
  for the slice (no exceptions/Dio code pulled in early). No unnecessary dependencies.

---

## Verdict

**Architecture is clean — ready to merge.** No Critical or Important issues; 1 Minor (optional
`@immutable` on `Result`) and 2 Suggestions, none blocking.
