# VGV Code Review — Foundation PR2 (T-03 · Error core)

- **Branch:** `feature/foundation-part2` (stacked on merged PR1) → target `epic/foundation`
- **Scope reviewed:** `lib/core/error/failure.dart`, `lib/core/error/result.dart`, `test/core/error/failure_test.dart`, `test/core/error/result_test.dart`
- **Source of truth:** `docs/plan/2026-05-24-chore-foundation-setup-plan.md` (PR2 — Error core section), Tech Spec §7.3/§8.1, PRD §8 (TE codes)
- **Reviewed:** 2026-05-24

## Summary

This is a clean, faithful, well-scoped implementation of the typed error core. The sealed `Failure` hierarchy and `Result<T>` re-express the Tech Spec §7.3/§8.1 sketches exactly, with the planned equality contract (`props = [runtimeType, message]`) hand-rolled correctly on the base class. Doc comments carry the PRD TE-code traceability per the plan, default messages match §7.3's terse internal tags, and `@immutable` is sourced from the already-present `flutter/foundation` rather than adding `meta`. The tests cover construction, default and overridden messages, `Ok`/`Err` exhaustive pattern-matching, and — critically — both equality and the two inequality axes (same-type/different-message, different-type/same-message). `dart analyze lib/core/error test/core/error` returns **No issues found**. All four T-03 acceptance criteria are met. The deliberate, plan-justified decisions (hand-rolled sealed classes, no `==` on `Ok`/`Err`, terse internal messages) are correctly applied and are explicitly NOT flagged below.

**One process caveat (not a code defect):** as with PR1, the PR2 files are currently **untracked working-tree files** (`git status` shows `?? lib/core/`, `?? test/core/`; `git log epic/foundation..HEAD` shows no T-03 commit). The error-core work is invisible to git/CI until committed. Flagging for parity with the PR1 finding, but the code itself is ship-quality.

## Critical — Must Fix Before Merge

_None._ The code is correct, analyzer-clean, and meets every T-03 acceptance criterion.

## Important — Should Fix

- **(whole PR) — The T-03 deliverables are uncommitted/untracked.**
  - Evidence: `git status --short` shows `lib/core/` and `test/core/` as `??`; `git log --oneline epic/foundation..feature/foundation-part2` lists no `feat(core)` commit (only the inherited PR1 merge). The error-core files exist on disk but are not part of the branch.
  - Why: A reviewer pulling the branch, and CI running against the pushed ref, would see no error core and no tests — the acceptance criteria are unmet at the git/CI level even though they pass on disk.
  - Fix: Stage the specific paths and commit as `feat(core)` per the plan, e.g. `git add lib/core/error test/core/error && git commit -m "feat(core): add typed Result and Failure error core"`. Re-verify with `git log --oneline epic/foundation..HEAD` and `git diff --stat epic/foundation...HEAD`. (Note `lib/core/.gitkeep` is now deletable since `lib/core/error/` carries real files — stage that deletion too.)

## Minor

- **`test/core/error/failure_test.dart:16-18` — the custom-message override is only exercised on `NetworkFailure`.** Every subtype shares the same optional-positional-`super.message` construct, so this is sufficient for both behavior and line coverage (the override path is structurally identical across subtypes; verified `dart analyze` clean and the plan confirms 14/14 failure-file coverage). No action required — duplicating the override test across all seven subtypes would be redundant. Flagging only so the single-subtype choice is on record as intentional, not an omission.

- **TE traceability lives only in doc comments, not in code.** Per the plan this is the deliberate design — the Dio→Failure→TE mapping is a T-06 concern, and modeling TE codes as fields now would be premature (YAGNI). The doc comments in `failure.dart:5-8,28-29,35,41,47,53,59,65` correctly carry the PRD mapping for traceability. Correct as-is; noting that the "each Failure maps to its TE code(s)" acceptance criterion is satisfied by documentation + the plan's mapping table, which is the agreed approach.

## Suggestion

- **`lib/core/error/result.dart` — consider a brief class-level note that `Ok`/`Err` intentionally omit `==`.** This is a deliberate, plan-justified decision (§8.1 has no equality; tests pattern-match and read `.value`/`.failure`). A one-line `// No `==` by design — consumers pattern-match; see plan PR2.` would pre-empt a future contributor "helpfully" adding equality and diverging from the spec. Purely optional; the current doc comments are otherwise clear and complete.

- **`failure.dart:9` — `@immutable` is well-placed on the sealed base** and correctly inherited by all subtypes. No change needed; mentioned only to confirm the annotation choice (reusing `flutter/foundation` over adding `meta`) is the right call and matches the plan.

## T-03 Acceptance Verification

Verified against the working tree (NOT committed git state — see Important):

- **`Result<T>` covers typed success and error:** PASS. `Ok<T>(value)` and `Err<T>(failure)` extend `sealed Result<T>`; `result_test.dart:7-20` asserts both carry their payloads and are `isA<Result<int>>`; `result_test.dart:22-30` proves exhaustive `switch` pattern-matching with no default arm (compiler-enforced exhaustiveness).
- **Each Failure maps to its PRD TE code(s) — many-to-one, TE-01…TE-09:** PASS. All seven subtypes present with §7.3 default messages (`offline`/`timeout`/`404`/`5xx`/`429`/`parse`/`cache`); doc comments map each to its TE code(s), including the shared TE-01 (`NetworkFailure` + `CacheFailure`) and TE-01/02 on `NetworkFailure`. TE-04/05/10/11 correctly excluded as UI states.
- **Unit tests cover construction + equality/inequality:** PASS. Default messages (`failure_test.dart:6-14`), custom override (`:16-18`), equality + hashCode parity (`:21-27`), same-type/different-message inequality (`:29-31`), different-type/same-message inequality (`:33-36`). Equality contract matches the plan's `props = [runtimeType, message]` exactly.
- **`core/error/` reaches ~100% line coverage:** PASS (plan-verified: failure 14/14, result 3/3). `Ok.value`, `Err.failure`, the base `==`/`hashCode`, and every subtype constructor are exercised.

## Equality Correctness Audit

The hand-rolled contract on the base `Failure` (`failure.dart:17-25`) is correct:
- `identical` short-circuit, then `other is Failure && runtimeType == other.runtimeType && message == other.message` — so different subtypes are never equal even with identical messages (verified `:33-36`), and same subtype with different messages is unequal (verified `:29-31`).
- `hashCode = Object.hash(runtimeType, message)` is consistent with `==` (equal objects → equal hashes; asserted `:21-27`). No hashCode/equals contract violation.

## Simplicity Assessment

- Lines that could be removed: ~0. Both files are minimal — no speculative helpers (`map`/`fold`/`when` on `Result`, factory constructors, etc.) were added; those belong to the layer that first needs them.
- Unnecessary abstractions: none. No `freezed`/`equatable` pulled in for two tiny types (plan-justified).
- YAGNI violations: none. `Result` exposes only `value`/`failure`; no premature combinators.
- Complexity verdict: Already minimal.

## Testing Assessment

- New code with tests: PASS — both `failure.dart` and `result.dart` have dedicated, behavior-focused test files.
- Test quality: Meaningful. No tautologies; equality is tested across all three relevant axes; pattern-matching exhaustiveness is exercised through real `switch` behavior rather than asserting framework internals.
- State management test coverage: N/A (no providers in this PR).
- UI component test coverage: N/A (pure-Dart error core, no widgets).

---

**Overall verdict: READY TO MERGE (code) — commit the untracked `lib/core/error` + `test/core/error` as a `feat(core)` commit before pushing; zero critical and zero code-level important issues.**
