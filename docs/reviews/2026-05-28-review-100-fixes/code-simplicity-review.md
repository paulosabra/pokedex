# Code-Simplicity Review — review-100 fixes (2026-05-28)

Scope: unstaged working-tree diff only (`git diff`).
Lens: YAGNI, minimal change, no over-engineering.

---

## Critical

### pokemon_card.dart — fix #5 is half-applied

**File:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart`, line 53

The diff changes only the _skeleton_ branch (`_SkeletonPokemonCard`) from
`context.go` to `context.push`. The non-skeleton branch (the `core.PokemonCard`
path) is unchanged and still calls `context.go`:

```dart
// line 53 — NOT changed by the diff
onTap: () => context.go('/pokemon/${pokemon.id}'),
```

This means every fully-hydrated Pokémon card still replaces the navigation
stack. The new test in `pokemon_card_test.dart` only pumps `_skeleton`, so it
passes green even though the hydrated path is broken for the stated goal.

**Recommendation:** Change line 53 to `context.push` as well, and add a
`canPop` assertion to the existing hydrated-card tap test (or a new one) that
mirrors the skeleton test.

---

## Suggest

### backfill_coordinator_test.dart — duplicate `when` stubs for `listMissingSummaryIds`

**File:** `test/features/pokemon/presentation/coordinators/backfill_coordinator_test.dart`, lines 238–251 and 267–278

Each drain setup registers two stubs for the same method: one with a
`limit: any(named: 'limit')` named-parameter matcher and one with no
parameters. Mocktail resolves the most-recently-registered stub, so the second
`when(repository.listMissingSummaryIds)` (no-arg form) silently shadows the
first. The first `when` is never exercised and the `firstCall` flag in the
named-parameter stub is never reset by the second stub block.

```dart
// First block (lines 238–248): named-param form with firstCall toggle
when(() => repository.listMissingSummaryIds(limit: any(named: 'limit')))
    .thenAnswer((_) async { ... });
// Second block (line 249–251): no-arg form always returns [1,2,3,4]
when(repository.listMissingSummaryIds).thenAnswer((_) async => [1, 2, 3, 4]);
```

The same pattern repeats for the second drain setup (lines 267–278). The test
still proves the bug because the no-arg stub is the one that actually fires in
`_drain()` (which calls `listMissingSummaryIds()` without a limit for the
opening count), but the named-param stub with the `firstCall` guard is dead
code.

**Recommendation:** Remove the named-param `when` stubs. Use only the no-arg
form, since that is what `_drain()` calls for the initial missing-count query.
If `listMissingSummaryIds(limit:)` (the chunked form) needs its own behavior,
mock it separately and deliberately.

### pokemon_list_screen.dart — comment restates what the code already says

**File:** `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart`, lines 76–77

```dart
// `maxScrollExtent == 0` when the list fits in the viewport — without
// the lower bound, `0 >= 0` fires `loadMore` on every layout pass.
if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent) {
```

The comment accurately explains the guard. However, the condition is
self-documenting to any reader familiar with `ScrollPosition`, and the comment
adds ~40 extra chars of diff noise. This is minor — a single concise sentence
would suffice — but it is slightly longer than necessary.

**Recommendation (optional):** Trim to one line if the team prefers
self-documenting code over prose: `// skip when list fits in the viewport`.
Not a blocker; keep if the team values this level of explanation.

---

## Approved

### pokemon_list_view_model.dart — `isLoadingMore: false` in refresh() branches

Adding `isLoadingMore: false` to all four `copyWith` call-sites in `refresh()`
is the correct minimal fix. No helper, no flag propagation layer, no state
machine overhead. Each site is already a `copyWith` call that must be updated;
the change is additive and locally obvious.

### pokemon_list_view_model.dart — `_enterBrowse` hasMore reset

One extra `state = AsyncData(current.copyWith(hasMore: true))` line before
`_subscribeBrowseStream`. This is the smallest possible fix for the race window
— no new state field, no flag, no boolean argument. The comment correctly
identifies the precondition.

### backfill_coordinator.dart — `_consecutiveErrors = 0` at drain start

A one-liner in the right place. No new parameter, no reset method, no
lifecycle callback. Placing the reset after the connectivity gate but before
the repo access is the correct semantics (the budget is per-attempt, not
per-session). Approved as-is.

### evolution_tab.dart — context.go → context.push

Minimal one-character category change. No helper, no abstraction. The
accompanying test verifies the precise semantic (`router.canPop()`) rather than
just route-string matching, which is the tightest possible assertion.

### Test: pokemon_list_view_model_test.dart — `isLoadingMore` reset tests

Two separate tests for Ok and Err paths are preferable to one combined test
that muddles the setup. The `Completer`-based hang pattern is the standard
approach for in-flight race tests. No speculative setup, no shared helpers
beyond what already existed.

### Test: pokemon_list_view_model_test.dart — discovery→browse hasMore test

Three-phase structure (enter discovery, re-enter browse, attempt loadMore) is
the minimum needed to prove the race window. No helper layers.

### Test: pokemon_list_screen_test.dart — maxScrollExtent guard test

Relies on `verify(...).called(1)` and `verifyNever(...)` — no custom matchers,
no extra harness state. Minimal.

### Test: evolution_tab_test.dart — back-stack preservation test

Constructs its own router inline rather than mutating shared state. The
`canPop()` assertion is the sharpest possible observable for push-vs-go.

---

## Summary

One **Critical** issue: fix #5 (`context.go → context.push`) was applied only
to the skeleton branch of `PokemonCard`; the hydrated branch at line 53 still
calls `context.go`. The test covers only the skeleton variant and therefore
does not catch this gap.

One **Suggest** issue: the backfill test registers two stubs per drain setup
where only one fires; the named-param stub with the `firstCall` toggle is dead
code and can be removed without changing test behavior.

Everything else is the smallest correct change. No over-engineering detected in
the production fixes.
