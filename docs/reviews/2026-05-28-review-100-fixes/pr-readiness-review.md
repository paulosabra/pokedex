# PR-Readiness Review — review-100 5-fix sweep

**Date:** 2026-05-28  
**Branch:** `epic/presentation-layer`  
**Base:** `develop`  
**Scope:** unstaged working-tree diff only (`git diff`)

---

## Critical (blocks merge)

### C-1 — Hydrated `PokemonCard` still calls `context.go` (fix #5 is incomplete)

**File:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart`, line 53

The diff changed only the skeleton branch (`_SkeletonPokemonCard`, line 42) from
`context.go` → `context.push`. The hydrated path — `core.PokemonCard.onTap` —
was not touched and still calls `context.go`:

```dart
// line 53 — unchanged, still destroys the back-stack
onTap: () => context.go('/pokemon/${pokemon.id}'),
```

The new regression test (`tap on a skeleton preserves the back-stack`) passes
because it exercises `_skeleton` (a `Pokemon` with no types, so
`pokemon.isSkeleton == true`). The far-more-common hydrated path (non-empty
`types`) is untested for back-stack behaviour and is still broken.

**Fix required before merge:**
1. Change line 53 to `context.push('/pokemon/${pokemon.id}')`.
2. Add a `canPop()` test for the hydrated card path (pump `_bulbasaur`, tap,
   assert `router.canPop() == true`).

---

## Important (should fix)

### I-1 — Untracked golden directories should not land in this commit

`git status` shows three untracked directories that are not gitignored:

```
test/core/ui/goldens/
test/features/pokemon/presentation/goldens/
test/features/pokemon/presentation/widgets/goldens/
```

They contain 24 PNG golden baselines and appear to have been generated locally
(possibly by a previous test run with `--update-goldens`). They are not
referenced by any of the five test files being changed in this sweep. Leaving
them floating means:

- A bare `git add .` would silently include 24 binary files in this fix commit,
  inflating the diff and mixing concerns.
- If they are intentional baselines they belong in a dedicated
  `test: add golden baselines` commit, not a `fix:` commit.

**Recommended action:** Either add `**/test/**/goldens/` to `.gitignore` if
goldens are always regenerated locally, or stage them in a separate commit.
Do **not** include them in this commit.

---

## Suggest (nice to have)

### S-1 — Backfill coordinator test has a redundant stub that may confuse readers

In the new `backfill_coordinator_test.dart` test (lines 249–251 and 278), there
is a bare `when(repository.listMissingSummaryIds)` stub registered immediately
after a more-specific `when(() => repository.listMissingSummaryIds(limit: any(named: 'limit')))` stub:

```dart
when(
  () => repository.listMissingSummaryIds(limit: any(named: 'limit')),
).thenAnswer((_) async { … });
when(
  repository.listMissingSummaryIds,          // bare stub — shadowed?
).thenAnswer((_) async => [1, 2, 3, 4]);
```

This follows the existing pattern in the file (lines 139–140, 176–177, 210–211)
so it is presumably intentional for mocktail's call-with-no-args coverage. The
test is not wrong, but a one-line comment explaining why both stubs are needed
would prevent future readers from deleting the bare stub thinking it is dead
code.

### S-2 — New list-screen test comment says `hasMore=true` but relies on the
default — explicit is clearer

In the new `pokemon_list_screen_test.dart` test (line 410), the comment says
"First page has 3 items with hasMore=true" but the call is:

```dart
final harness = _makeHarness(firstPage: _page(1, 3));
```

Since `_makeHarness` defaults `hasMore: true`, this is correct. Passing
`hasMore: true` explicitly would make the intent self-documenting:

```dart
final harness = _makeHarness(firstPage: _page(1, 3), hasMore: true);
```

---

## Approved (no action required)

- **Formatter:** All hunks are correctly formatted. No trailing whitespace,
  no misaligned braces, no lines that `dart format` would reflow in the
  changed ranges. Import-line over-80-chars are pre-existing and are excluded
  from formatting rules.
- **Static analyzer:** No obvious lint hits in the diff. `unawaited()` is used
  correctly in tests. Cascade operators, `const`, and `final` are applied
  appropriately.
- **Debug artifacts:** No `print()`, `debugPrint()`, `console.log()`, or
  ownerless `TODO`/`FIXME` in any changed file.
- **Commit hygiene:** No `.DS_Store`, IDE files, or generated files (`*.g.dart`,
  `*.mocks.dart`) in the diff. (The golden PNGs are flagged under I-1 as
  untracked — not in the diff itself.)
- **Fix #1 — `isLoadingMore` stuck on refresh:** Production fix is correct
  (all four switch arms cleared). Two regression tests cover the OK and Err
  paths. Approved.
- **Fix #2 — `hasMore: false` race window after discovery → browse:**
  Production fix (`state = AsyncData(current.copyWith(hasMore: true))` before
  `_subscribeBrowseStream`) is correct. Regression test drives the full
  `applyFilter(types) → applyFilter(null) → loadMore` sequence. Approved.
- **Fix #3 — Error-budget reset per drain in backfill coordinator:**
  Production fix (`_consecutiveErrors = 0` at top of `_drain()`) is correctly
  placed after the online check but before the loop. Test verifies that
  4-error first drain + 1-error second drain does not trip the halt threshold.
  Approved.
- **Fix #4 — Spurious `loadMore` on short list:** Guard
  `pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent` is correct.
  Widget test verifies `getList(offset: 0)` is called exactly once and
  `getList(offset: 24)` is never called. Approved.
- **Fix #5 (evolution tab):** `context.go` → `context.push` in `_StageCard`
  is correct. The new `router.canPop()` test is the right assertion. Approved.
- **Fix #5 (skeleton card):** `context.go` → `context.push` in
  `_SkeletonPokemonCard` is correct. Test approved. (But see **C-1** — the
  hydrated card path is a separate, still-broken path.)
- **Deliberately dropped test:** One brittle back-stack widget test was dropped
  in a prior conversation step; confirmed covered by two remaining regression
  tests. Not a concern here.

---

## Commit subject and PR description

**Suggested commit subject** (`fix:` type per Conventional Commits, subject ≤ 70 chars):

```
fix(presentation): 5 bug-fixes from review-100 sweep
```

**PR description bullets:**

- Fixes `isLoadingMore` stuck after a concurrent refresh interrupts an in-flight
  `loadMore` (both success and failure paths cleared) — resolves review-100 #1.
- Restores `hasMore: true` before the browse stream is re-subscribed after
  discovery mode, eliminating a race window where `loadMore` was permanently
  blocked — resolves review-100 #2.
- Resets the backfill error-budget at the start of each drain rather than
  accumulating it across drains, preventing a transient offline event from
  pre-biasing the halt threshold — resolves review-100 #3.
- Guards `_onScroll` against firing `loadMore` on every layout pass when the
  list fits in the viewport (`maxScrollExtent == 0`) — resolves review-100 #4.
- Replaces `context.go` with `context.push` on evolution-tab stage cards and
  skeleton list cards so the system-back button returns to the previous screen
  — resolves review-100 #5 (partial — see open item below).

**Open item before opening the PR:** C-1 above must be resolved — the hydrated
`PokemonCard` path (line 53) also needs `context.push` and a matching canPop test.
