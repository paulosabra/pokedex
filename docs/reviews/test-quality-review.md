---
title: "Test Quality Review — PR2 (foundation-part2)"
date: 2026-05-24
branch: feature/foundation-part2
reviewer: Test Quality Agent (VGV)
---

## Test Quality Review

### Coverage Summary

- Test run: **Pass** (coverage confirmed at 100% per task context)
- Coverage: **100% line coverage** of `lib/core/error/`
  - `lib/core/error/failure.dart`: 14/14 lines hit
  - `lib/core/error/result.dart`: 3/3 lines hit
- Files with tests: **2/2**
  - `lib/core/error/failure.dart` → `test/core/error/failure_test.dart`
  - `lib/core/error/result.dart` → `test/core/error/result_test.dart`
- Missing test files: none

---

### Critical

None.

---

### Important

**`test/core/error/failure_test.dart:21-27` — Structural equality path never exercised by the "equal" case**

The equality test uses two `const` instances of the same type:

```dart
const a = ServerFailure();
const b = ServerFailure();
expect(a, b);
```

Dart canonicalizes compile-time constants: `a` and `b` are the *identical* object in memory. The hand-rolled `==` operator short-circuits on `identical(this, other)` before reaching the structural comparison (`runtimeType == other.runtimeType && message == other.message`). As a result, the structural equality branch — the part of `==` that is actually hand-written and therefore error-prone — is never exercised by any test case that expects the result to be `true`.

The inequality tests at `failure_test.dart:29-36` do partially exercise the structural path (they reach the `other is Failure` check and then fail on message or type), but no test confirms that the structural branch correctly returns `true` for two non-identical, structurally-equal instances. A bug in that branch — for example, `||` changed to `&&`, or `runtimeType ==` dropped — would be invisible to the current suite.

Fix: add one equality test using non-const-identical instances. The simplest approach is to construct two instances from a runtime value so Dart cannot canonicalize them, or use factory constructors:

```dart
test('equal instances constructed independently share value equality', () {
  final message = 'test-${DateTime.now().microsecondsSinceEpoch}';
  final a = NetworkFailure(message);
  final b = NetworkFailure(message);
  // a and b are not identical — structural path is exercised
  expect(identical(a, b), isFalse);
  expect(a, b);
  expect(a.hashCode, b.hashCode);
});
```

This is the one gap between reported line coverage and semantic coverage of the equality contract.

---

### Minor

None.

---

### Suggestions

**`test/core/error/failure_test.dart` — hashCode divergence for unequal instances not asserted**

The test at `failure_test.dart:21-27` confirms that two equal `Failure` instances share a `hashCode`, which satisfies the contract's positive side. The hand-rolled implementation uses `Object.hash(runtimeType, message)`. While the Dart spec does not require unequal objects to have different hashes (collisions are valid), for a hand-rolled implementation with only two fields, asserting that the hashes *do* differ for the inequality cases documents intent and catches a naive bug (e.g. `hashCode => 0`). This is a suggestion, not a requirement.

```dart
test('different type or message produce different hashCodes', () {
  expect(
    const NetworkFailure('x').hashCode,
    isNot(const CacheFailure('x').hashCode),
  );
  expect(
    const NetworkFailure('a').hashCode,
    isNot(const NetworkFailure('b').hashCode),
  );
});
```

**`test/core/error/failure_test.dart:16-18` — Custom message only tested for `NetworkFailure`**

Only one subtype is exercised with a custom message. All 7 subtypes share the same `([super.message = '<default>'])` constructor pattern, so this is not a critical gap — the path is covered. However, a brief parametric check across all subtypes (or at least one more subtype) would make the test suite self-documenting: a future reader can confirm that the optional-message pattern compiles and behaves correctly for each type, not just the one used as an example. Low priority given the shared constructor delegate.

---

### Plan Requirement Checklist

| Requirement (from plan PR2 section) | Status |
|---|---|
| Construction of `Ok` and `Err` tested | Pass — `result_test.dart:7-19` |
| `Ok`/`Err` exhaustive switch (pattern-match) tested | Pass — `result_test.dart:22-30` |
| `Failure` equality of identical instances tested | Pass — `failure_test.dart:21-27` |
| Inequality: same type, different message | Pass — `failure_test.dart:29-31` |
| Inequality: different type, same message | Pass — `failure_test.dart:33-36` |
| Default message for all 7 subtypes asserted | Pass — `failure_test.dart:6-13` |
| `hashCode` consistency tested | Pass — `failure_test.dart:26` |
| `~100% line coverage` of `core/error/` | Pass — 100% confirmed |
| Structural equality path exercised under positive case | **Gap** — const canonicalization means `identical()` short-circuits; structural branch untested for `true` return |

---

### State Management Test Quality

Not applicable. No BLoC/Cubit/Riverpod providers exist in PR2. The first provider lands in T-17.

### UI Component Test Quality

Not applicable. PR2 is pure Dart — no widgets.

---

### Anti-Patterns Found

None detected.

| Check | Result |
|---|---|
| Tautological assertion (`expect(true, isTrue)` style) | Not present |
| Mock-everything (mocking the class under test) | Not applicable — pure Dart, no dependencies to mock |
| Implementation mirroring | Not present — the `describe` helper in `result_test.dart:23` tests pattern-match expressiveness, not internal logic |
| No assertions | Not present — all test cases carry meaningful assertions |
| Missing state tests | Not applicable — no state management |
| Hardcoded magic values without context | Not present — `42` in `result_test.dart:8` is an unambiguous sentinel; `'offline'`, `'404'` etc. are the literal spec-defined defaults |
| Over-verification (`verify` on every mock) | Not present |
| Missing async waiting after state changes | Not applicable — synchronous pure-Dart tests |

---

### Recommendations

1. **Add a non-identical equality test to exercise the structural branch of `Failure.==`.** The const-canonicalization issue means the hand-rolled structural equality body (`runtimeType == other.runtimeType && message == other.message`) is only exercised on the *false* side (the inequality tests) and never on the *true* side from a non-identical object pair. One new test case, using a runtime-derived message string to defeat canonicalization, closes this gap without touching production code.

2. **All other plan requirements are fully met.** Both files have tests, all 7 default messages are asserted, both inequality axes (same-type-different-message and different-type-same-message) are covered, the exhaustive switch is demonstrated, and `hashCode` consistency is verified. The tests are clean, idiomatic `flutter_test`, and free of the anti-patterns listed above.

---

### Verdict

Ready to merge after adding one non-identical equality test (`failure_test.dart`) to close the structural-branch gap in the hand-rolled `Failure.==` — one important semantic coverage issue; all other plan requirements are satisfied and the test quality is otherwise high.
