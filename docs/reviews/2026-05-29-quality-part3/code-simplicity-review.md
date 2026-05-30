# Code Simplicity Review — T-30b (PR3): Analytics Event Wiring

**Branch:** `feature/quality-part3`
**Date:** 2026-05-29
**Reviewer:** Code Simplicity Agent

---

## Simplification Analysis

### Core Purpose

Wire the 9 PRD §12 analytics events across the presentation layer by consuming the T-30a observability seam (`analyticsServiceProvider` / `errorReporterProvider`). The three supporting additions — `error_te_code.dart`, `onShown` callbacks on DS widgets, and `RecordingAnalytics`/`RecordingErrorReporter` fakes — are the scaffolding that makes the wiring testable without coupling the DS to observability.

---

### Unnecessary Complexity Found

#### 1. Duplicated "is this an offline error?" branch in two screens

**Files:**
- `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:332`
- `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:650`

Both screens contain an identical inline type-test that is already encoded in `error_te_code.dart`:

```dart
// list_screen.dart
if (error is NetworkFailure || error is CacheFailure) { ... 'TE-01' ... }

// detail_screen.dart
final isOffline = error is NetworkFailure || error is CacheFailure;
```

`teCodeFor` / `teCodeForError` already encodes this mapping exhaustively and is imported by both files. The inline `is NetworkFailure || is CacheFailure` check is a partial, duplicate re-expression of the same fact. If a new connectivity failure type is added to the sealed hierarchy (e.g. a `DnsFailure`), `teCodeFor` gets the compile-time nudge but both inline checks are silent.

**Why it's unnecessary:** `error_te_code.dart` was created specifically to be the single source of TE code derivation. The inline checks duplicate its logic while adding a secondary maintenance point.

**Suggested simplification:** Replace both inline checks with `teCodeForError`. The widget selection (Offline vs Generic) can be inlined with the same call:

```dart
// list_screen: _Body.build
final teCode = teCodeForError(error);
if (teCode == 'TE-01') {
  return OfflineErrorWidget(onRetry: onRefresh, onShown: () => _reportErrorShown(ref, teCode));
}
return GenericErrorWidget(onRetry: onRefresh, onShown: () => _reportErrorShown(ref, teCode));

// detail_screen: _Error.build
final teCode = teCodeForError(error);
return Scaffold(
  body: teCode == 'TE-01'
      ? OfflineErrorWidget(message: '...', retryLabel: 'Back', onRetry: () => _back(context), onShown: () => reportShown(teCode))
      : GenericErrorWidget(message: '...', retryLabel: 'Back', onRetry: () => _back(context), onShown: () => reportShown(teCode)),
);
```

This removes the duplicated type-test entirely. `teCodeForError` already falls back to `TE-07` for non-`Failure` objects, so the branch stays correct for every case. Note that this also removes the `'TE-01'` string literal from the call sites — the code and the mapper agree via the single `teCodeFor` return value.

**Estimated LOC reduction:** ~4 lines across 2 files (and one fewer import of `Failure` subtypes in detail screen's `_Error`).

---

#### 2. `_reportErrorShown` private helper on `_Body` — single-use, adds indirection

**File:** `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:316–318`

```dart
void _reportErrorShown(WidgetRef ref, String teCode) => ref
    .read(analyticsServiceProvider)
    .logEvent(ErrorShown(teCode: teCode, screen: _screenName));
```

This helper is a one-liner called in three places in `_Body.build`. The three call sites each pass `ref` and a pre-computed `teCode`, which means none of the three callers benefit from the abstraction beyond the `screen: _screenName` capture. The equivalent inline expression is already shorter than a helper invocation when you include the `() =>` wrapper at each call site.

**Contrast with `_Error.reportShown`:** The detail screen's local `reportShown` closure (line 651) is defined inside `build` where `ref` is already in scope — it genuinely saves repeating `ref.read(analyticsServiceProvider)` twice without needing `ref` as a parameter. That pattern is fine. The list-screen version wraps the same call but requires passing `ref` as a parameter, which negates the readability gain.

**Suggested simplification:** Inline the three call sites in `_Body.build`. The `onShown` lambdas become:

```dart
onShown: () => ref.read(analyticsServiceProvider).logEvent(ErrorShown(teCode: 'TE-01', screen: _screenName))
```

Or, if the `_reportErrorShown` helper is kept, move its definition into `build` so `ref` is captured in the closure rather than passed as a parameter (matching the detail screen pattern).

**Estimated LOC reduction:** 4 lines (the helper definition + 3 parameter-thread calls simplified).

---

#### 3. `RecordingAnalytics.named` helper — marginal value, call pattern is already trivial

**File:** `test/helpers/recording_observability.dart:17–19`

```dart
List<AnalyticsEvent> named(String name) =>
    events.where((e) => e.name == name).toList();
```

All test assertions already go through `.named('...')` rather than operating on `.events` directly, which is a good pattern. However, the helper is thin enough that `.events.where((e) => e.name == 'foo').toList()` is the obvious one-liner and the helper saves less than a line per call site. This is a minor YAGNI nudge, not a blocker.

**Assessment:** The helper is borderline. Its real value is that test names (strings) appear in exactly one place per event type — if `AnalyticsEvent.name` is ever renamed the tests still compile. Keeping it is defensible. If removed, replace each `.named('foo')` call with the inline `.where` expression.

**Estimated LOC reduction if removed:** 3 lines in the helper file.

---

### Code to Remove

| Location | Reason | Estimated LOC |
|---|---|---|
| `pokemon_list_screen.dart:332` — `if (error is NetworkFailure \|\| error is CacheFailure)` branch | Duplicates `teCodeForError` mapping already in `error_te_code.dart` | -4 |
| `pokemon_detail_screen.dart:650` — `final isOffline = error is NetworkFailure \|\| error is CacheFailure` | Same duplication | -2 |
| `pokemon_list_screen.dart:316–318` — `_Body._reportErrorShown` helper | Single-use helper with a `ref` parameter that negates its closure benefit | -4 |

---

### Simplification Recommendations

#### 1. Consolidate offline-widget selection behind `teCodeForError` (Important)

- **Current:** Both `_Body` and `_Error` re-implement the `NetworkFailure || CacheFailure → TE-01` type check inline, in addition to passing the literal string `'TE-01'`.
- **Proposed:** Call `teCodeForError(error)` once, store in a local, use its value both for widget selection (`== 'TE-01'`) and for the `onShown` callback. The literal `'TE-01'` disappears from call sites.
- **Impact:** ~6 LOC removed across 2 files; the sealed-hierarchy compiler guarantee from `teCodeFor` now covers the widget-routing branch as well.

#### 2. Inline or fix the parameter threading in `_Body._reportErrorShown` (Suggestion)

- **Current:** A helper method on a `ConsumerWidget` subclass that requires `ref` as a parameter, called in 3 places.
- **Proposed:** Move it into `build` as a local closure (removing the `ref` parameter), or inline the 3 call sites entirely.
- **Impact:** 4 LOC, cleaner call sites that match the detail screen's existing pattern.

---

### YAGNI Violations

None of the changed files introduce speculative extension points.

The three items assessed as "deliberate decoupling choices" in the task brief hold up:

- **`error_te_code.dart`:** Justified. It is the single source of truth for the Failure → TE-code mapping and provides exhaustiveness via the sealed-switch. It is used in at least 4 call sites (VM, list screen Body, detail screen, and its own test). Not over-built.
- **`onShown` callback on DS widgets:** Justified. The design-system widgets (`OfflineErrorWidget`, `GenericErrorWidget`, `StaleCacheBanner`) are deliberately free of observability imports. The `onShown` seam is the minimal coupling surface. It is nullable (no behaviour change when omitted), implemented in `initState` (fires exactly once per mount without needing a `StatefulWidget` for any other reason), and tested. The `StatefulWidget` promotion it necessitates adds ~10 lines each, but that is a fair price for DS/observability isolation.
- **`RecordingAnalytics` / `RecordingErrorReporter` fakes:** Justified. The comment in the file correctly explains why a recorder beats a mock for value-like events with no `==`. Both fakes are used across at least 4 test files each. Not over-built.

The one issue that does touch YAGNI lightly is the inline duplication of the `NetworkFailure || CacheFailure` type check at two call sites. It is not a "feature" per se, but it re-encodes a rule that `error_te_code.dart` was built to own, which is a small YAGNI violation against the mapper's stated purpose.

---

### Final Assessment

**Total potential LOC reduction:** ~10 lines (~1.5% of the changed presentation layer code). The PR is clean and well-structured.

**Complexity score:** Low

**Recommended action:** Minor tweaks only. The single meaningful simplification (issue 1: consolidate offline type-test behind `teCodeForError`) should be applied before merge. Issue 2 (`_reportErrorShown` helper) is a style preference and can be deferred. Issue 3 (`RecordingAnalytics.named`) is a suggestion with no impact on merge readiness.
