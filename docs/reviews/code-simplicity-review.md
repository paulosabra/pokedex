---
title: "Code Simplicity / YAGNI Review — PR2 (feature/foundation-part2)"
date: 2026-05-24
scope: "lib/core/error/failure.dart, lib/core/error/result.dart, test/core/error/failure_test.dart, test/core/error/result_test.dart"
reviewer: claude-sonnet-4-6 (simplicity agent)
---

## Simplification Analysis

### Core Purpose

Provide the thinnest typed error vocabulary the rest of the app can depend on:
a `Result<T>` sum type (`Ok` / `Err`) and a `Failure` sealed hierarchy with seven
concrete subtypes covering every PRD TE code that is a recoverable error (TE-01..09,
minus the four UI-state codes). No logic, no utilities, no extension methods — pure
data types plus equality.

---

### Critical

None.

---

### Important

None.

---

### Minor

#### 1. `failure.dart:3-8` — base-class doc comment partially restates itself

- **File:** `lib/core/error/failure.dart:3-8`
- **Issue:** The doc comment opens with "Base type for all typed, recoverable errors in
  the app." — genuinely useful. The second sentence, "The mapping is many-to-one — e.g.
  both [NetworkFailure] and [CacheFailure] surface TE-01," is also load-bearing context.
  The third sentence, "[message] is a short, internal tag (not user-facing); the
  presentation layer maps each failure to a friendly, localized message," partially
  duplicates the inline doc on the `message` field two lines below (`lib/core/error/failure.dart:14`):
  `/// A short, internal description of the failure (not user-facing).`
  The "not user-facing" qualifier is stated in both places; the "presentation layer maps
  it" half does add context the field comment lacks.
- **Suggestion:** Trim the class-level sentence to only the part the field comment cannot
  carry: remove "not user-facing" from the class comment (the field comment already says
  it) and keep the "presentation layer maps each failure" clause. The duplication is minor
  and the comment body is otherwise excellent — this is purely cosmetic.
- **Estimated saving:** 1 phrase; net impact is negligible.

#### 2. `result_test.dart:8-11` — explicit `<int>` type argument on `Ok` is redundant

- **File:** `test/core/error/result_test.dart:8`
- **Issue:** `const result = Ok<int>(42)` — the `<int>` annotation is inferred by Dart
  from the literal `42`. The explicit annotation adds no safety here because both the
  `isA<Result<int>>()` assertion and the value check would catch a type mismatch at
  compile time regardless.
- **Contrast:** `const result = Err<int>(failure)` on line 16 is in the same position
  but the annotation there is arguably worthwhile because `failure` is typed `NetworkFailure`
  (a `Failure`, not an `int`), so the `<int>` is the only place the success-type is
  expressed — removing it would lose that signal. Line 16 should be kept.
- **Suggestion:** Drop `<int>` on line 8: `const result = Ok(42)`. The test reads the
  same; no information is lost.

---

### Suggestions

#### 3. `failure_test.dart:34` — inline comment is the only place the TE-01 sharing is called out in tests

- **File:** `test/core/error/failure_test.dart:34`
- **Issue:** `// NetworkFailure and CacheFailure both map to TE-01 but are distinct.`
  This is a good comment — it explains *why* the test exists (two types sharing a TE
  code must still be unequal). It is not redundant. No action needed; included here
  only to confirm it was evaluated and found to be load-bearing.

#### 4. `result.dart` — no `==`/`hashCode` on `Ok`/`Err` is a deliberate omission, not a gap

- **File:** `lib/core/error/result.dart`
- **Issue:** Deliberately absent per the plan's "props = [runtimeType, message] on
  Failure base only; Ok/Err intentionally have none" decision. Calling this out
  explicitly so future reviewers do not add value-equality to `Ok`/`Err` speculatively —
  structural equality on a wrapper carrying an arbitrary `T` would require `T: Equatable`
  or be silently identity-based, which is worse than no `==` at all. The omission is
  correct.

---

### YAGNI Violations

None confirmed. The following were evaluated and ruled out:

- **Seven `Failure` subtypes** — all required by the PRD TE mapping. No subtype is
  speculative; each has a concrete trigger callout in its doc comment (e.g.
  `DioExceptionType.connectionError`, HTTP status codes). Keep.
- **Optional `message` parameter on every subtype** — the default messages satisfy the
  plan's §7.3 requirement; the optional override is needed at T-06 when repository code
  passes a structured message from the network layer (e.g. the raw HTTP status line).
  Not YAGNI.
- **`@immutable` on `Failure`** — prevents mutable subclass accidents at zero runtime
  cost. Correct use of the annotation; not over-engineering.
- **`const Result()` base constructor** — enables `const Ok(...)` / `const Err(...)`
  at call sites. Used in both test files already (`const Ok<int>(42)`,
  `const Err<int>(failure)`). Keep.
- **`identical` short-circuit in `==`** — standard Dart equality idiom for sealed
  value types; adds one branch that is hit whenever the same const instance is compared
  to itself. The alternative (removing it) would be a micro-pessimization with no
  clarity benefit.

---

### Final Assessment

**Total potential LOC reduction:** 1 phrase in a doc comment + 1 type argument in a
test. Effectively zero.

**Complexity score:** Low — this is among the simplest possible implementations of a
typed result type in Dart. The hand-rolled approach is leaner than any macro-generated
equivalent would be at this size.

**Verdict:** Ready to merge. The error core is minimal, correct, and fully covered.
The two minor findings are cosmetic and should not block the PR.
