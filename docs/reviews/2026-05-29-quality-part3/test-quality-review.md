# Test Quality Review — T-30b (PR3): Wire PRD §12 Analytics Events

> **Branch:** `feature/quality-part3`
> **Reviewer:** Test Quality Review Agent
> **Date:** 2026-05-29
> **Scope:** Analytics event wiring tests for all 9 PRD §12 events

---

## Coverage Summary

- **Test run:** Not executed (pre-existing golden mismatch at root; individual suites pass — confirmed by `dart analyze` returning zero errors on all 7 touched test files)
- **Coverage gate:** Inherits T-29's ≥ 80% (hand-written code baseline 94.8%); the additions are entirely testable presentation edits
- **Files with tests:** 7/7 touched test files present
- **Missing test files:** None — every modified implementation file has a corresponding test file

### Event coverage matrix

| Event | Test file | Group |
|---|---|---|
| `list_viewed` (cold) | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `list_viewed` (warm) | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `search_performed` | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `filter_applied` | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `sort_changed` | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `generation_selected` | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `error_shown` (loadMore swallowed) | `pokemon_list_view_model_test.dart` | analytics (T-30b §12) |
| `pokemon_opened` (hydrated + skeleton) | `pokemon_card_test.dart` | PokemonCard adapter |
| `detail_tab_changed` | `pokemon_detail_screen_test.dart` | analytics (T-30b §12) |
| `error_shown` (detail offline TE-01) | `pokemon_detail_screen_test.dart` | analytics (T-30b §12) |
| `error_shown` (detail generic TE-07) | `pokemon_detail_screen_test.dart` | analytics (T-30b §12) |
| `evolution_navigated` | `evolution_tab_test.dart` | EvolutionTab |
| `error_shown` (list offline TE-01) | `pokemon_list_screen_test.dart` | error_shown analytics (T-30b §4.3) |
| `error_shown` (list generic TE-07) | `pokemon_list_screen_test.dart` | error_shown analytics (T-30b §4.3) |
| `error_shown` (stale banner TE-02) | `pokemon_list_screen_test.dart` | error_shown analytics (T-30b §4.3) |
| TE-code mapping | `error_te_code_test.dart` | teCodeFor / teCodeForError |

All 9 events and all 4 `error_shown` variants from §4.3 are covered.

---

## State Management Test Quality

### `pokemon_list_view_model_test.dart` — analytics group

**Result:** Pass with one important gap

The analytics group is correctly positioned at the bottom of the file, uses the same `RecordingAnalytics`/`RecordingErrorReporter` fakes injected via `ProviderContainer.overrides`, and follows the established pattern of the rest of the test file. Tests are grouped and named as specifications.

**Specific findings:**

- `build emits list_viewed{origin: cold} with the rendered count` — exact parameter map equality (`{'origin': 'cold', 'count': 24}`). Sound. The map equality assertion acts as a no-PII guarantee: if any unexpected key were added (e.g. a raw query term), the assertion would fail.

- `clearing discovery back to browse emits list_viewed{origin: warm}` — asserts `origins == ['cold', 'warm']` (ordering + count). However, the `count` property of the warm event is never asserted. The `_enterBrowse` implementation emits `ListViewed(origin: ListOrigin.warm, count: current.items.length)`. After `applyFilter(PokemonFilter(types: fire))` the discovery items are 3 (from the `findPokemon` stub). The warm event's `count: 3` is verifiable and would catch a regression where `count` is hardcoded or stale.

- `search emits search_performed with result_count only (RNF-09)` — asserts exact parameter map `{'result_count': 3}`. Because map equality is full equality (not a subset check), an accidental leak of the query term as an extra key would cause the assertion to fail. This is the correct and strongest possible test for RNF-09 compliance at this layer. Sound.

- `applyFilter emits filter_applied presence flags` — one scenario tested (type + height active, weakness absent). The implementation fires `FilterApplied` for every `applyFilter` call including `applyFilter(null)` (all flags false). The all-false case is exercised in the warm list_viewed test (which calls `applyFilter(null)`) but no assertion is made about the resulting `filter_applied` event emitted at that point. A regression in the null-clearing path (e.g. a null-check inversion) would not be caught by the analytics group.

- `changeSort emits sort_changed with the criterion name` — exact parameter map. Sound.

- `selectGeneration emits generation_selected; clearing does not` — tests both positive emission and the absence-of-emission guarantee when clearing. Good two-sided assertion.

- `swallowed loadMore failure reports captureError and emits error_shown` — covers both `analytics.named('error_shown')` with exact parameters AND `reporter.captured` with exact type. `hasLength(1)` on both, preventing double-fire. Well-structured.

- `browse refresh failure reports the handled failure (TE-02 banner)` — uses `isNotEmpty` rather than `hasLength(1)`. The browse refresh Err path calls `_reportFailure` exactly once; `hasLength(1)` would be the more precise and regression-proof assertion. This is the only test in the analytics group that uses a weaker-than-necessary matcher.

---

## UI Component Test Quality

### `pokemon_card_test.dart` — analytics group

**Result:** Pass with one minor gap

- `tap logs pokemon_opened with id + primary_type` — exact map `{'id': 1, 'primary_type': 'grass'}` using a hydrated card. Sound.

- `skeleton tap logs pokemon_opened with unknown primary_type` — exact map `{'id': 445, 'primary_type': 'unknown'}`. Correctly exercises the skeleton branch in the implementation where `pokemon.types.isEmpty` results in `'unknown'`. This is a non-obvious edge case and testing it is appropriate.

- No test asserts that `pokemon_opened` is NOT emitted when a tap occurs with no `RecordingAnalytics` injected (i.e. that the Noop default is active). This is not strictly necessary — the provider default is a no-op and the T-30a tests cover that — but it is noted.

### `pokemon_detail_screen_test.dart` — analytics group

**Result:** Pass with one missing scenario

- `switching tabs emits detail_tab_changed (never for the initial tab)` — verifies that the initial About tab mount does not emit, then asserts the ordered list of subsequent emissions `['stats', 'evolution']`. This is a strong two-sided test: both presence and ordering. Sound.

- `offline failure emits error_shown TE-01 on the detail screen` — exact map. Sound.

- `generic failure emits error_shown TE-07 on the detail screen` — exact map. Sound.

- **Missing:** no test exercises returning to the About tab after having navigated away. The implementation fires `detail_tab_changed` for any tab change including back to About (the `_reportedIndex` guard only prevents the initial-load-no-change case). A test going Stats→About would verify that `'about'` is emitted as a tab name, completing the tab name coverage for all three `DetailTab` enum values. Currently only `'stats'` and `'evolution'` are asserted as emitted values; `'about'` is never verified as an outgoing event name.

- `ErrorReporter` is not injected in the detail screen tests. The `_Error` widget does not call `captureError` — it only calls `logEvent(ErrorShown(...))` — so this is not a gap in terms of the §4.3 contract.

### `pokemon_list_screen_test.dart` — error_shown analytics group

**Result:** Pass

All three §4.3 error_shown variants are covered with distinct tests:

- `offline error widget emits error_shown TE-01` — exact parameters, `hasLength(1)`. Sound.
- `generic error widget emits error_shown TE-07` — uses `analytics.named('error_shown').single.parameters` (equivalent assertion). Sound.
- `stale-cache banner emits error_shown TE-02` — creates a fresh `RecordingAnalytics` after initial success, triggers refresh failure, checks `hasLength(1)` and exact parameters. The fresh analytics instance correctly avoids contamination from the initial cold load (which emits `list_viewed` but not `error_shown`). Sound.

One structural note: the test for `stale-cache banner emits error_shown TE-02` sets up `analytics` before `pumpInitial`, which means `list_viewed` (cold) is also captured in the same `RecordingAnalytics` instance. Because the assertion uses `analytics.named('error_shown')`, the `list_viewed` event is filtered out and does not pollute the result. The `hasLength(1)` guard confirms no double-fire from banner re-mount.

### `evolution_tab_test.dart` — analytics

**Result:** Pass

- `tapping a stage emits evolution_navigated{source_id, dest_id}` — exact parameter map `{'source_id': 1, 'dest_id': 3}`. Both IDs are explicitly verified. Sound.

---

## TE-Code Mapping Test Quality

### `error_te_code_test.dart`

**Result:** Pass

- `maps every Failure subtype to its PRD TE code` — tests all 7 sealed Failure subtypes in a single test: `NetworkFailure` → TE-01, `CacheFailure` → TE-01, `NotFoundFailure` → TE-03, `TimeoutFailure` → TE-06, `ServerFailure` → TE-07, `RateLimitFailure` → TE-08, `ParsingFailure` → TE-09. Because `teCodeFor` exhaustively switches on the sealed class, adding a new `Failure` subtype would be a compile error until this mapping is updated. The test mirrors that exhaustiveness.

- `delegates to teCodeFor for a Failure` and `falls back to TE-07 for a non-Failure error` — covers both branches of `teCodeForError`. The non-Failure test uses a `String` and `null`, covering two non-Failure shapes.

- **Structural note:** The stale-cache TE-02 case is correctly absent from this file. The docstring explains the deliberate design: TE-02 is a UI-state distinction (offline + cache present), not a Failure subtype distinction. The `StaleCacheBanner` hardcodes `'TE-02'` at the call site. This split is sound and the comment makes the intent explicit.

---

## Recording Fakes Quality

### `test/helpers/recording_observability.dart`

**Result:** Sound design choice

The rationale provided in the file header is correct and complete: `AnalyticsEvent` is a sealed class with no `==` override, making matcher-based verification cumbersome and requiring `registerFallbackValue` for every subtype. The `RecordingAnalytics.named(String)` helper provides a clean way to filter by event name and then assert on the `parameters` map, which is `Map<String, Object>` (fully equatable). This avoids the matcher-overhead of mocktail while providing stronger assertions (full map equality vs a `verify(mock.logEvent(...)).called(1)` that only checks call count).

`RecordingErrorReporter` similarly captures structured `CapturedError` records (a Dart record with named fields), allowing fine-grained assertions on `failure` type separately from the error object.

Both fakes are stateless except for their accumulation lists, which are reset by creating a new instance in each test's `setUp`. No shared state leaks between tests.

The choice of fakes over mocktail mocks is appropriate here and is the correct VGV recommendation when the collaborator produces value-like outputs that are better asserted on their content than their invocation pattern.

---

## Anti-Patterns Found

**`pokemon_list_view_model_test.dart:1015`** — Weak `isNotEmpty` assertion in analytics group

- **Anti-pattern:** Under-specified assertion where a precise bound is possible
- **Issue:** The test `'browse refresh failure reports the handled failure (TE-02 banner)'` asserts `reporter.captured.where((c) => c.failure is NetworkFailure), isNotEmpty`. The browse refresh Err path calls `_reportFailure` exactly once. `isNotEmpty` would pass even if `captureError` were called 5 times, masking a double-fire regression.
- **Fix:** Replace with `hasLength(1)` and optionally assert `reporter.captured.single.failure, isA<NetworkFailure>()` for symmetry with the loadMore test.

```dart
// Current (line 1014-1017):
expect(
  reporter.captured.where((c) => c.failure is NetworkFailure),
  isNotEmpty,
);

// Improved:
expect(reporter.captured, hasLength(1));
expect(reporter.captured.single.failure, isA<NetworkFailure>());
```

---

## Recommendations

1. **Strengthen the TE-02 captureError assertion** (Important): Change `isNotEmpty` to `hasLength(1)` with an exact type check in the browse refresh failure test. This is the only place in the analytics group where the assertion precision drops below the standard set by the other tests.

2. **Assert the warm list_viewed count** (Suggestion): In `'clearing discovery back to browse emits list_viewed{origin: warm}'`, add `expect(analytics.named('list_viewed').last.parameters['count'], 3)` (or assert the full parameter map for the second event). This would catch a regression in the count field of warm re-entries, which is currently validated for cold but not warm.

3. **Assert filter_applied all-false on clear** (Suggestion): The `applyFilter(null)` call in the warm list_viewed test silently emits `FilterApplied(hasType:false, hasWeakness:false, hasHeight:false)` but no test asserts this. A dedicated case or an in-line assertion in the warm test would close the gap.

4. **Cover the 'about' tab emission in detail_tab_changed** (Suggestion): Add a test that navigates Stats → About and asserts `analytics.named('detail_tab_changed').map((e) => e.parameters['tab'])` contains `'about'`. Currently only `'stats'` and `'evolution'` are verified as outgoing tab names; `'about'` is never tested as an emitted value.

---

## Verdict

**Fix 1 issue before merging.** The test suite is structurally sound: all 9 PRD §12 events are covered, all 4 §4.3 `error_shown` variants are tested, RNF-09 is enforced via full map-equality assertions, the recording-fake design is appropriate and well-justified, and the `dart analyze` pass confirms zero compile errors across all 7 test files.

One **important** finding needs fixing: the `isNotEmpty` assertion in the TE-02 browse refresh captureError test is a weaker guarantee than the rest of the analytics group and should be tightened to `hasLength(1)` before merge. The three suggestions are improvements to confidence, not blockers.
