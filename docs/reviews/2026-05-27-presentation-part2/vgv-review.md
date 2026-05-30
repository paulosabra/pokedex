# VGV Engineering Review — Presentation PR2 (Home + Discovery)

**Branch:** `feature/presentation-part2`
**Reviewer:** vgv-review-agent (Opus 4.7)
**Date:** 2026-05-27

## Verdict

**Needs minor fixes.** The PR is well-architected, faithful to the plan,
and the test discipline is unusually strong (21-case VM suite, real
`StreamController.hasListener` leak assertion, scroll-preservation widget
test, intent-signature constraint honored end-to-end). Layer separation is
clean (no `data/` imports in presentation), Freezed state is immutable,
mocktail + `ProviderContainer.overrides` is canonical, and the
plan-incorporated findings (copyWithPrevious, leak test seam, _composeFilter
unit test) all landed exactly as designed.

Two issues warrant fixing before merge — one is a real UX correctness bug
(drag-to-dismiss is indistinguishable from Clear in the Filters and
Generations sheets), and one is a concurrency hazard worth tightening
(`_enterDiscovery` does not guard against overlapping in-flight calls).
The rest is `Suggest` / `Note`.

| Severity | Count |
| --- | ----- |
| Blocker | 0 |
| Fix     | 2 |
| Suggest | 6 |
| Note    | 4 |

---

## Fix — should fix before merge

### F1. Drag-to-dismiss silently wipes the active filter / generation
**Files:** `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:62-90`,
`lib/features/pokemon/presentation/widgets/sheets/filters_sheet.dart:66-83`,
`lib/features/pokemon/presentation/widgets/sheets/generations_sheet.dart:42-54`

`_openFilters` and `_openGenerations` cannot distinguish three caller
intents that all collapse to `null`:

| User action               | Sheet pop value | Screen interprets as |
| ------------------------- | --------------- | --------------------- |
| Tap "Apply" with nothing  | `null`          | clear filter          |
| Tap "Clear"               | `null`          | clear filter          |
| Drag-dismiss the sheet    | `null`          | clear filter          |

The third case is the bug. Open the sheet with `state.filter` already set,
drag down to dismiss → the screen unconditionally calls
`applyFilter(null)`, wiping the filter the user didn't ask to clear. Same
pattern in `_openGenerations` → `selectGeneration(null)`.

`_openSort` already does this correctly (`if (result == null) return;`),
because for Sort the pop value is never `null` from Apply.

Note that the sort sheet has a subtle related issue: there's no Clear or
back-to-default-numberAsc affordance, but that's a Suggest, not a Fix.

**Fix options (pick one):**

- Have the sheets return a tagged result, e.g. an `enum
  FiltersSheetResult { applied(PokemonFilter? f), cleared, dismissed }`,
  so the caller can branch:
  ```dart
  switch (result) {
    case _Applied(:final f): notifier.applyFilter(f);
    case _Cleared(): notifier.applyFilter(null);
    case _Dismissed(): // no-op
    case null: // drag-dismiss
  }
  ```
- Or: distinguish "no pop value" (drag) from "explicit pop with null"
  (Clear) via a sentinel record/wrapper.
- Tests must add a "drag-dismiss preserves active filter / generation" case
  (currently no test covers this path).

This is the kind of bug that wouldn't surface in unit tests but would
infuriate a manual smoke run.

### F2. `_enterDiscovery` has no in-flight cancellation guard
**File:** `lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart:224-269`

`_applyMode` fires `unawaited(_enterDiscovery())` on every intent that
mutates a discovery axis (filter, sort, generation, debounced search). If
the user fires two such intents in quick succession (e.g. tap a filter,
then change sort 50 ms later), two `_enterDiscovery` calls run
concurrently. Each captures its own `current` snapshot **before** awaiting
`findPokemon`, then unconditionally writes
`current.copyWith(items: value, …)` on resolve. Whichever resolves last
wins — with a *stale* snapshot of the user-input axes.

The 5-rapid-flip leak test catches the subscription leak path but not this
data-coherence path, because debouncing collapses search inputs into a
single call. The non-debounced intents (`applyFilter`, `changeSort`,
`selectGeneration`) bypass the debounce and are the real risk.

**Fix sketch:**
```dart
int _discoverySeq = 0;
Future<void> _enterDiscovery() async {
  final mySeq = ++_discoverySeq;
  // … existing cancel + AsyncLoading setup …
  final result = await ref.read(findPokemonProvider).call(/*…*/);
  if (mySeq != _discoverySeq) return; // a newer call superseded us
  // … switch on result as today …
}
```

Add a test that fires `applyFilter` then immediately `changeSort` with a
hanging `Completer` on the first call and a faster resolve on the second
— assert the final state reflects the second intent, not the first.

---

## Suggest — improvements worth doing

### S1. Empty-string search shouldn't wait 300 ms to return to browse
**File:** `view_models/pokemon_list_view_model.dart:89-99`

When the user clears the search field, the empty-query state is the user
explicitly asking to leave discovery. Debouncing the empty case means the
list looks "stuck in discovery" for 300 ms after the field clears. Trivial
fix:

```dart
state = AsyncData(current.copyWith(query: capped));
_debounce?.cancel();
if (capped.isEmpty) {
  _applyMode();  // immediate
  return;
}
_debounce = Timer(_searchDebounce, _applyMode);
```

### S2. `loadMore`-failure is silently swallowed
**File:** `view_models/pokemon_list_view_model.dart:78-82`

The comment notes the state shape has no `loadMoreError` field, so the
error is dropped. For PR2 this is acceptable since pull-to-refresh can
recover, but the user gets zero signal that pagination stopped working.
Either:

- Add a `Failure? loadMoreError` to `PokemonListState` (small) and surface
  a footer error tile, or
- Defer to PR4 explicitly and add a TODO comment with the PR4 task pointer
  so the deferral isn't invisible.

### S3. `// ignore: invalid_use_of_internal_member` for `copyWithPrevious`
**File:** `view_models/pokemon_list_view_model.dart:241-242, 267-268`

`copyWithPrevious` is on the public `AsyncValue` API surface, but Riverpod
marks it `@internal` so the lint requires the suppression. This is the
canonical Riverpod 3.x pattern for in-place AsyncLoading-preserving-data
transitions — your usage is correct. Two suggestions:

- Centralize behind a small private helper to avoid two `ignore` lines:
  ```dart
  AsyncValue<PokemonListState> _loadingPreservingState() {
    // ignore: invalid_use_of_internal_member
    return const AsyncLoading<PokemonListState>().copyWithPrevious(state);
  }
  ```
- Add a one-line comment linking to the resolved blocker 1 design note,
  so future readers don't try to "fix" the ignore.

### S4. `PokemonCard` uses `context.go` for card → detail navigation
**File:** `lib/features/pokemon/presentation/widgets/pokemon_card.dart:27`

Per Tech Spec §9.1 ("Mobile: push de rota"), card → detail is a push, not
a replace. `context.go('/pokemon/$id')` replaces the URL stack on web and
prevents the user from returning to the list with a swipe-back / browser
back without the URL bar.

Use `context.push('/pokemon/$id')` instead. The deep-link case (user
pastes `/pokemon/25` into the URL bar fresh) is already covered by the
router's `initialLocation`.

Tests should adjust assertion: a tap call sequence on `context.push`
followed by `pop` should round-trip back to `/`.

### S5. Screen's `_searchController` and VM `state.query` can drift
**File:** `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:34, 40-50`

The screen owns a `TextEditingController` that's only the source-of-truth
for what the user typed. The VM mirrors typed input into `state.query`,
but no code path writes the other direction. PR2 doesn't currently expose
"clear search from outside" (no filter-chip `×` for the active query),
but PR4 likely will. If/when something else mutates `state.query` (e.g. a
clear-all CTA), the text field will be out of sync.

Either:

- Add a `ref.listen(provider, ...)` that writes `controller.text` when the
  upstream query changes (debounced to skip echoes), or
- Push the controller ownership into the VM via a `late
  TextEditingController` exposed as a getter (heavier).

For PR2, a comment marker is enough — leave the drift open until PR4
introduces an external mutation path.

### S6. Empty / Error blocks duplicate the typography + padding pattern
**Files:** `pokemon_list_screen.dart:264-318`

`_EmptyBlock` and `_ErrorBlock` use identical `Center(Padding(...,
Text(...)))` containers. With PR4 landing real empty/error widgets under
`lib/core/ui/states/` this'll collapse. Just a note that the duplication
is intentional and short-lived — don't extract a `_MessageBlock` helper
here; PR4 will replace both.

---

## Note — observations / stylistic preferences

### N1. `_onScroll` re-fires `loadMore` every scroll tick within the threshold
**File:** `pokemon_list_screen.dart:52-60`

Every tick within 200 px of the bottom calls `ref.read(...).loadMore()`,
which the VM correctly no-ops on `isLoadingMore || !hasMore ||
isDiscovery`. The traffic is harmless but noisy. If the scroll listener
showed up in a profiler, add a `_lastLoadMoreAt` debounce. Today, fine.

### N2. Filter sheet height single-select toggle is undocumented
**File:** `filters_sheet.dart:223`

`onTap: () => onChanged(value == entry.key ? null : entry.key)` toggles
the height back to null on re-tap. This is a nice affordance, but it's
not exposed in the title (e.g. no visual hint that re-tap clears) and not
covered by an explicit doc comment. Add a one-liner above the `_labels`
map: `// Re-tapping the active height clears the selection (toggle).`
Same applies to GenerationsSheet's identical toggle.

### N3. `_pokemon` and `_page` helpers in tests are duplicated across files
**Files:** `pokemon_list_view_model_test.dart:29-39`,
`pokemon_list_screen_test.dart:26-36`, `pokemon_card_test.dart:9-23`

Each test file defines its own `_pokemon`/`_page` builders. With the
domain entity small (5 fields) this is fine; if PR3 adds a
`PokemonDetail` builder of its own that duplicates fixture-shape logic
twice more, consider a `test/helpers/pokemon_factories.dart`. For PR2,
acceptable.

### N4. `PageStorageKey<String>('pokemon-list-grid')` works but is implicit
**File:** `pokemon_list_screen.dart:220`

The constant is fine. A `static const _gridStorageKey = PageStorageKey...`
at top-of-file would help future readers grep for "what keeps scroll
state". Nit.

---

## What the PR gets right

- **Plan adherence** — every plan-derived AC for PR2 is reflected in
  code or tests: intent signatures, adapter alias, `_composeFilter`
  unit test, copyWithPrevious for blocker 1, real-controller leak test,
  scroll-preservation widget test, generation composition.
- **Test discipline** — 21 VM cases cover browse init / loadMore /
  debounce / discovery flip / refresh in both modes / refresh-error /
  stream re-sync / leak / dispose / `_composeFilter` composition.
  Assertions are on observable state, not on mock call counts.
  `valueOrThrow` helper is exactly right — keeps each test concise.
- **Layer separation** — `grep -r 'features/pokemon/data'` in
  `lib/features/pokemon/presentation/` returns nothing. The adapter
  pattern (`PokemonCard` feature widget over `core.PokemonCard`) keeps
  domain entity unpacking off the DS.
- **Disposal correctness** — `ref.onDispose` is the first thing in
  `build()`. `_debounce` and `_streamSub` are nulled after cancel. The
  dispose test is a single line that asserts behavior, not internals.
- **Intent surface** — every public method on the notifier returns
  `void` or `Future<void>`; parameters are domain entities or
  primitives. No `Ref` / `AsyncValue` / `ProviderSubscription` leaks
  to callers. Matches the plan's intent-signature constraint exactly.
- **`@freezed` state** — single source of truth, immutable, with an
  `isDiscovery` derived getter so the VM never duplicates the
  "is-any-axis-active" logic.
- **Self-baselined goldens** — three sheet goldens, no flaky cross-CI
  font rendering risk (per project_analyzer9-toolchain).
- **`AsyncLoading.copyWithPrevious`** — applied at exactly the two
  places it's needed (load + error paths in `_enterDiscovery`) with
  the rationale documented inline.

The two `Fix` findings are local cleanups, not architecture mistakes.
Address them and this is a clean merge.

---

## References

- Plan: `docs/plan/2026-05-26-feat-presentation-layer-plan.md` §PR2
- Tech Spec: `docs/project/02-tech-spec.md` §5.2 (state), §9 (nav),
  §9.1 (mobile push vs. web URL)
- Prior PR1 review: `docs/reviews/2026-05-26-presentation-part1/vgv-review.md`
- Memory: `feedback_review-vs-plan`, `feedback_abstraction-vs-fidelity`,
  `project_analyzer9-toolchain`
