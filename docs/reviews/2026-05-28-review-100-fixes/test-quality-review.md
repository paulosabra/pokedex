# Test-Quality Review — review-100 regression tests
**Date:** 2026-05-28  
**Branch:** epic/presentation-layer  
**Scope:** unstaged working-tree additions for the 5 review-100 fixes

---

## Critical

_No critical findings._

---

## Important

### I-1 — Non-skeleton `PokemonCard` back-stack gap
**File:** `test/features/pokemon/presentation/widgets/pokemon_card_test.dart`  
**What's wrong:**

The production fix in `pokemon_card.dart` changed **only** the `_SkeletonPokemonCard` call-site from `context.go` to `context.push`. The non-skeleton path (`core.PokemonCard.onTap`) still calls `context.go` in the current working tree (line 53). The non-skeleton back-stack test was dropped on the stated grounds that `canPop` returned false in the test harness, yet the skeleton back-stack test — which uses an identical `GoRouter` harness — does verify `canPop() == true` successfully. This inconsistency raises two concerns:

1. **Coverage gap:** If the non-skeleton `context.go` is intentional (because the non-skeleton card is only reachable from the top-level route where `canPop` is always false), that assumption should be documented and a comment added to the production code. If it is a bug that `context.go` was not also changed to `context.push` for the non-skeleton path, no test will catch it.

2. **Regression risk:** Without a test, a future refactor that unintentionally reverts the non-skeleton path to `context.go` (or vice versa, accidentally changes it to `push`) will go undetected.

**Assessment of the skeleton + evolution coverage argument:**

The skeleton test (`_SkeletonPokemonCard`) and the evolution-stage test both confirm `context.push` was wired correctly in those two components. However they do not exercise the `core.PokemonCard` onTap path, so they do not substitute for a test of the non-skeleton card.

**Recommended fix:**

Either (a) add back a non-skeleton back-stack test and fix the production code to use `context.push` for both paths, or (b) keep `context.go` for the non-skeleton path and add a code comment explaining the deliberate asymmetry, then add a test that asserts `canPop() == false` after tapping a non-skeleton card to lock in the intentional behavior.

---

### I-2 — Backfill test: `firstCall` flag is shared state across two `when` closures with implicit coupling
**Test:** `'a new drain after offline does not inherit the prior drain error budget'`  
**File:** `test/features/pokemon/presentation/coordinators/backfill_coordinator_test.dart`  
**What's wrong:**

The `firstCall` flag is captured by both the `when(() => repository.listMissingSummaryIds(limit: any(...)))` closure and, implicitly, the tearoff `when(repository.listMissingSummaryIds)` second stub uses the same variable in the second drain setup. This is the same dual-stub pattern used in existing tests, so it works today, but it relies on Dart closure semantics (mutation of a closed-over local) in a non-obvious way.

More concretely: after the first drain, `firstCall` is `false` at the end of the drain (the limit-based loop stub exhausted the `[1,2,3,4]` chunk and set it false). When the test resets `firstCall = true` for the second drain and re-registers the stubs, the reset is applied to the shared variable — this is correct. However, if a reader modifies the stub registration order or introduces a third `when` using the same flag, the behavior will silently change.

The pattern is not wrong, just fragile. Since all existing tests in this file use the same idiom and they pass, this is an Important rather than Critical finding — but worth noting for a future refactor.

**Recommended fix:** Extract each drain's mock setup into a named helper (e.g., `_stubFirstDrain(...)` / `_stubSecondDrain(...)`) to make the closure-capture dependency explicit and localise the mutation.

---

## Suggest

### S-1 — Short-list scroll guard: test title understates the assertion
**Test:** `'short list (maxScrollExtent==0) does not trigger spurious loadMore (resolved review-100 #4)'`  
**File:** `test/features/pokemon/presentation/pages/pokemon_list_screen_test.dart`  
**What's wrong:**

The test verifies the **call count** of `getList` at `offset=0` via `verify(...).called(1)` and then `verifyNever` at `offset=24`. This is correct and does exercise the bug path (without the fix, `_onScroll` would fire `loadMore` on every layout pass, causing a second call at `offset=24`). The test is sound.

Minor suggestion: the comment says "The initial build fetches page-0 exactly once. If _onScroll misfires…" but does not call `clearInteractions(harness.getList)` before the `verify`. Since `pumpAndSettle` is called immediately after `_pumpScreen`, the build's page-0 call and any spurious `loadMore` call happen before the single `verify`. The current form works because `verify(...).called(1)` matches a total count of exactly 1 across the entire test; if a future framework change fires additional early frames, this could become a false negative. Consider adding `clearInteractions(harness.getList)` right before the verify pair to make the intent explicit and make the test resilient to additional setup calls.

### S-2 — `_enterBrowse` race-window test: `offset: any(named: 'offset')` in verify is too broad
**Test:** `'discovery → browse unblocks loadMore in the pre-stream race window (resolved review-100 #2)'`  
**File:** `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`  
**What's wrong:**

The verify uses `offset: any(named: 'offset')` rather than the concrete expected value (`offset: 24`, since `pumpInitial` loads 24 items). Using `any()` means the test would pass even if `loadMore` fetched the wrong page (e.g., `offset: 0` — a duplicate page-0 fetch). The production code at this point holds `offset: 3` from the discovery result (3 items returned by the `findPokemon` stub), so the correct expected offset is `3`.

**Recommended fix:** Replace `offset: any(named: 'offset')` with `offset: 3` to pin the exact offset expected after the discovery result settled, making the test fail on any offset regression.

### S-3 — Browse-refresh isLoadingMore (Err path): missing `isRefreshing: false` assertion
**Test:** `'browse refresh resets isLoadingMore on Err path (resolved review-100 #1)'`  
**File:** `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`  
**What's wrong:**

The test only asserts `isLoadingMore == false` but does not assert `isRefreshing == false` on the Err path. The Ok-path sibling test correctly asserts both. The production fix touches both `isLoadingMore` and `isRefreshing` in the Err branch; testing only `isLoadingMore` leaves the `isRefreshing` reset unverified on this path.

**Recommended fix:** Add `expect(valueOrThrow(container).isRefreshing, isFalse)` after the existing assertion.

### S-4 — Evolution back-stack test: does not assert the navigated route
**Test:** `'tapping a stage preserves the back-stack (resolved review-100 #5)'`  
**File:** `test/features/pokemon/presentation/widgets/detail/evolution_tab_test.dart`  
**What's wrong:**

The test asserts `router.canPop() == true` but does not verify which route was pushed (i.e., that the detail route for Venusaur `/pokemon/3` is now on top). The sibling test `'tapping a stage navigates to /pokemon/<id>'` already covers the correct destination, so there is no duplication risk in adding the assertion — it would only strengthen this test to confirm that `push` (not `go`) delivered the right route.

**Recommended fix:** Check that the current route after the tap is `/pokemon/3` (or that `find.text('detail:3')` is rendered) in addition to `router.canPop()`.

---

## Approved

### A-1 — Browse refresh resets isLoadingMore (Ok path)
**Test:** `'browse refresh resets isLoadingMore when a loadMore is in flight (resolved review-100 #1)'`  
**File:** `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`  
Correctly hangs the `offset=24` fetch to keep `isLoadingMore: true`, then asserts `isFalse` after a successful `refresh`. The Completer is drained at the end to avoid leaked futures. Test will fail without the `isLoadingMore: false` line in the Ok branch of `refresh`. Approved.

### A-2 — `_enterBrowse` unblocks loadMore
**Test:** `'discovery → browse unblocks loadMore in the pre-stream race window (resolved review-100 #2)'`  
**File:** `test/features/pokemon/presentation/view_models/pokemon_list_view_model_test.dart`  
Two-step state check (discovery sets `hasMore: false`, `_enterBrowse` restores `hasMore: true`) plus an end-to-end `loadMore()` call that actually fetches a page. Without the `state = AsyncData(current.copyWith(hasMore: true))` line in `_enterBrowse`, `loadMore` is gated by `!current.hasMore` and the `verify(...).called(1)` would fail. Core logic is sound; see S-2 for a precision improvement. Approved with suggestion.

### A-3 — Backfill per-drain error budget reset
**Test:** `'a new drain after offline does not inherit the prior drain error budget (resolved review-100 #3)'`  
**File:** `test/features/pokemon/presentation/coordinators/backfill_coordinator_test.dart`  
Two-drain setup: drain 1 accumulates 4 consecutive errors (< threshold); drain 2 accumulates 1 more. Without the `_consecutiveErrors = 0` reset in `_drain`, the combined count hits 5 and triggers halt. The test correctly targets the critical boundary (4+1 = threshold). Approved with the fragility note in I-2.

### A-4 — Short-list scroll guard
**Test:** `'short list (maxScrollExtent==0) does not trigger spurious loadMore (resolved review-100 #4)'`  
**File:** `test/features/pokemon/presentation/pages/pokemon_list_screen_test.dart`  
Without the `pos.maxScrollExtent > 0` guard, the scroll listener fires `loadMore` on the initial layout pass even when all items fit the viewport, causing an unexpected `offset=24` fetch. The test directly exercises this by giving a short first page (`_page(1, 3)`) with a tall enough surface (the default 420×1000) so the list never scrolls. `verifyNever` at `offset=24` is the right sentinel. Approved with the `clearInteractions` suggestion in S-1.

### A-5 — Skeleton back-stack preservation
**Test:** `'tap on a skeleton preserves the back-stack (resolved review-100 #5)'`  
**File:** `test/features/pokemon/presentation/widgets/pokemon_card_test.dart`  
Uses `canPop()` as the precise behavioral discriminant between `push` (stack grows, `canPop: true`) and `go` (stack resets, `canPop: false`). The fix changed `_SkeletonPokemonCard.onTap` from `context.go` to `context.push`; without the fix, `canPop()` returns false and the test fails. Approved.

### A-6 — Evolution stage back-stack preservation
**Test:** `'tapping a stage preserves the back-stack (resolved review-100 #5)'`  
**File:** `test/features/pokemon/presentation/widgets/detail/evolution_tab_test.dart`  
Mirrors the skeleton back-stack approach using an explicit `GoRouter` with two routes. `canPop()` is the correct discriminant for `push` vs `go`. Without the `context.go → context.push` fix in `_StageCard`, `router.canPop()` returns false and the test fails. Approved with the destination assertion suggestion in S-4.

### A-7 — Deletion of non-skeleton back-stack test
The deletion is conditionally approved given the explanation (see I-1 for the full analysis). The `canPop: false` behavior in the test harness for a non-skeleton card at the root route is plausible — the root `/` route has nothing to pop back to, so `canPop` is always false regardless of `push` vs `go` when the router starts at `/`. If the intended back-stack behavior only applies when navigating from a non-root context (e.g., from a detail page to another detail page), the existing `'tap navigates to /pokemon/<id>'` test plus the `_lastVisited` assertion does confirm the correct URL. However, the production code still uses `context.go` for non-skeleton cards (see I-1), so the question of whether that is intentional needs to be resolved. The deletion is **conditionally approved**: if the non-skeleton path intentionally uses `go` (and the test harness limitation accurately reflects the production use case), the deletion is acceptable; if the non-skeleton path should also use `push`, the test must be restored with an appropriate two-route harness where the start route is not the root.

---

## Summary

| Severity | Count | Issues |
|----------|-------|--------|
| Critical | 0 | — |
| Important | 2 | I-1 non-skeleton coverage gap; I-2 shared `firstCall` flag fragility |
| Suggest | 4 | S-1 `clearInteractions` before verify; S-2 imprecise offset matcher; S-3 missing `isRefreshing` assertion; S-4 missing destination assertion |
| Approved | 7 | A-1 through A-7 |

The five regressions are each covered by a test that would fail without the corresponding fix. The most pressing action item is resolving I-1: either confirm and document that the non-skeleton `PokemonCard` intentionally uses `context.go`, or apply the same `context.push` fix there and restore (or write) a back-stack test for it.
