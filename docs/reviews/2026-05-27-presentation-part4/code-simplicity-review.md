---
date: 2026-05-27
reviewer: code-simplicity-agent
pr: feature/presentation-part4
tasks: T-27, T-28
---

# Code Simplicity Review — PR4 (Errors + Responsive)

## Simplification Analysis

### Core Purpose

PR4 must deliver six stateless error/empty widgets, three responsive layout
primitives, and rewire the list + detail screens to use them. Every byte of
code that does not serve those deliverables is a liability.

---

### Unnecessary Complexity Found

#### 1. `masterFlex` / `childFlex` on `MasterDetailScaffold` — unused knobs

**File**: `lib/app/layout/master_detail_scaffold.dart:21–22, 36–39, 48, 52`

`MasterDetailScaffold` exposes two constructor parameters (`masterFlex = 2`,
`childFlex = 3`) that control the `Expanded` flex factors of the two panels.
There is exactly one call site — `pokemon_detail_screen.dart:48` — and it
passes neither parameter, always relying on the defaults. The 40/60 split is
therefore hardcoded in practice; the parameters exist only in case a future
screen wants a different ratio.

That is a YAGNI violation. No second caller exists and none is planned for this
epic. The flex values could be inlined as literals (`flex: 2` / `flex: 3`) and
the two public fields removed, saving four lines of declaration plus the
doc-comment block.

**Suggested simplification**: Remove `masterFlex` and `childFlex`; hardcode
`flex: 2` and `flex: 3` at the usage site inside `build`. If a future screen
genuinely needs a different split, add the parameters then.

**LOC saved**: ~10 (two field declarations + two doc comments + constructor
params + default values).

---

#### 2. `_filterIsEffectivelyEmpty` — duplicates domain knowledge already in `PokemonFilter`

**File**: `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:456–462`

```dart
bool _filterIsEffectivelyEmpty(PokemonFilter? filter) {
  if (filter == null) return true;
  return filter.types.isEmpty &&
      filter.weaknesses.isEmpty &&
      filter.height == null &&
      filter.weight == null;
}
```

This private method reconstructs the concept "all filter axes are at their
default / empty state". The `PokemonFilter` Freezed class already knows its own
fields; the ViewModel also derives the same concept implicitly in
`_isDiscovery`. Encoding this test a third time in the View layer means that
every time `PokemonFilter` gains a new axis (e.g. `int? generationId` was just
added in PR1), this helper must be updated in sync or it silently produces the
wrong empty-state routing.

At the call site in `_EmptyState.build` the intent is:

> Show `EmptyGenerationWidget` when the **only** active discovery axis is
> `generationId` (the generation filter itself). Show `EmptyFilterWidget`
> when any type/weakness/height/weight axis is also active.

The cleanest expression of that intent is to check whether the filter object
— minus `generationId`, which is already asserted non-null by the preceding
`if` — has any active non-generation axes. A getter `PokemonFilter.hasNonGenerationAxes`
on the domain entity would be the canonical home. Failing that, the note in
the plan acknowledged `_filterIsEffectivelyEmpty` is a deliberate heuristic;
but the current implementation silently excludes the `generationId` field from
its emptiness check (correct, but fragile and unexplained).

**Suggested simplification**: Add a getter `bool get isEmpty` (or
`hasNoActiveAxes`) to `PokemonFilter` that tests all non-generation fields.
Replace the private helper with `filter?.isEmpty ?? true`. This puts the
knowledge where it belongs and makes the intent readable at the call site.

**LOC saved**: ~6 in the screen file; ~3 added to the entity (net improvement
in locality and safety).

---

#### 3. `isScrollControlled` / `useRootNavigator` on `showSheetOrDialog` — parameters with no non-default callers

**File**: `lib/app/layout/responsive_layout.dart:41–42, 48–49, 55`

`showSheetOrDialog` accepts `isScrollControlled` (default `true`) and
`useRootNavigator` (default `false`). There are three call sites, all in
`pokemon_list_screen.dart`; every call omits both parameters, using the
defaults. The `useRootNavigator` flag is passed through to both the sheet and
the dialog branch; `isScrollControlled` is only meaningful for the sheet branch
(the dialog branch ignores it), making the parameter leaky in its abstraction.

These are "just in case" knobs with no current need.

**Suggested simplification**: Remove both optional parameters. Hardcode
`isScrollControlled: true` inside the sheet branch. If a future call site
needs `useRootNavigator: true`, the parameter can be reintroduced then.

**LOC saved**: ~8 (two param declarations + forwarding lines + doc comment
references).

---

#### 4. Duplicate CTA-button structure across `OfflineErrorWidget` and `GenericErrorWidget`

**Files**: `lib/core/ui/states/offline_error_widget.dart:37–68`,
`lib/core/ui/states/generic_error_widget.dart:33–63`

Both widgets share an identical structural skeleton:

```
Center → Padding(24) → Column(min) → [Icon(48, textGray), SizedBox(16),
Text(center, description), SizedBox(16), ElevatedButton(actionPrimary)]
```

The only differences are the default icon, default message, and default
`retryLabel`. If `retryLabel` were removed (see finding 5), the two widgets
would differ only in their default icon and default message string — i.e. in
their constants, not their structure.

The plan spec explicitly calls for these as separate widgets (they represent
different user-facing situations), so collapsing them into a single widget
would reduce clarity even if it reduces lines. The more targeted simplification
is to extract the shared scaffold into a private `_ErrorScaffold` widget in a
shared file (or inline helper) that both reference — keeping the two public
classes as thin wrappers that supply their own icon and default message.

This is a **suggestion** rather than a critical issue; the duplication is
currently only two-widget deep. It becomes more painful if a third error widget
with the same structure is added later.

**Potential LOC saved**: ~20 (shared scaffold extracted once, two wrappers
become ~8 lines each).

---

#### 5. `retryLabel` parameter on `OfflineErrorWidget` and `GenericErrorWidget` — semantic mismatch

**Files**: `lib/core/ui/states/offline_error_widget.dart:18, 30`,
`lib/core/ui/states/generic_error_widget.dart:17, 26`

Both widgets expose `retryLabel` to allow callers to pass `'Back'` instead of
`'Retry'`. The only call sites that use a non-default value are the detail
screen's `_Error` widget, which passes `retryLabel: 'Back'` to both.

The parameter conflates two different actions under one slot: "retry the
request" and "go back to the list". This is a naming and semantic mismatch — a
`retryLabel` that says "Back" is confusing to the next developer. More
importantly, the detail screen's `_Error` widget already knows it wants a "Back"
action; it just needs a button. The simplest model is:

- `OfflineErrorWidget` and `GenericErrorWidget` keep a single fixed label
  `'Retry'` and a required `onRetry` callback.
- The detail error path renders its own `TextButton('Back', onPressed: _back)`
  alongside (or instead of) the standard retry CTA, or overrides only `message`
  if that is the only distinct need.

Alternatively, rename `retryLabel` to `ctaLabel` to be semantically honest
about what it is.

**LOC saved if removed**: ~6 total (two param declarations + two usages). Low
count but improves semantic clarity.

---

#### 6. `StaleCacheBanner.message` — overridable but only ever used at default

**File**: `lib/core/ui/states/stale_cache_banner.dart:13`

`StaleCacheBanner` exposes a `message` optional parameter. The only call site
is `pokemon_list_screen.dart:153`, which uses `const StaleCacheBanner()` —
the default. There is no planned second call site (the plan explicitly says the
banner is list-only per resolved refine 4).

This is a minor YAGNI: the parameter adds API surface for no current benefit.
The banner message is its whole identity; making it fixed also makes the widget
more `const`-constructible by default.

**Suggested simplification**: Remove `message` from the constructor; inline the
string constant in `build`.

**LOC saved**: ~5 (field declaration + constructor param + doc comment).

---

#### 7. `AppTypography.description.copyWith(fontSize: 14)` in `StaleCacheBanner`

**File**: `lib/core/ui/states/stale_cache_banner.dart:37`

`AppTypography.description` is defined at `fontSize: 16`. The banner applies
`.copyWith(fontSize: 14)` to shrink it. This hardcodes a size variant that is
not in the typography token set — neither a named style nor a Figma token. If
the banner is the only place in the codebase that needs 14px description text,
this is a one-off magic number; if it appears elsewhere a named token (`small`
or `caption`) would be cleaner. Either way, the deviation from the token
should be intentional and documented (a `// Figma: banner body` comment or a
dedicated `bannerBody` style in `AppTypography`).

This is a **suggestion** (low severity) — not blocking, but worth flagging to
avoid the token set drifting.

---

#### 8. `Breakpoints` private constructor is vestigial on `abstract final class`

**File**: `lib/app/layout/breakpoints.dart:43`

`abstract final class Breakpoints` already prevents instantiation via the
`abstract` modifier. The `const Breakpoints._()` private constructor adds no
additional protection and is a pattern carried over from pre-`final` Dart
conventions. The same observation applies to `ResponsiveLayout._()` and
`AppTypography._()` in other files (the last two are out of scope for this PR,
but the pattern lands in PR4 via `Breakpoints`).

**Suggested simplification**: Remove the `const Breakpoints._()` constructor
body. The class remains non-instantiable through `abstract final`.

**LOC saved**: 1 line in scope (plus 1 in `ResponsiveLayout` as a bonus).

---

### Code to Remove

| File | Lines | Reason | Est. LOC reduction |
|------|-------|--------|--------------------|
| `lib/app/layout/master_detail_scaffold.dart` | 21–22, 33–39, params in ctor | `masterFlex`/`childFlex` — YAGNI, no non-default caller | ~10 |
| `lib/features/pokemon/presentation/pages/pokemon_list_screen.dart` | 456–462 | `_filterIsEffectivelyEmpty` — moves to `PokemonFilter.isEmpty` getter | ~6 net |
| `lib/app/layout/responsive_layout.dart` | 41–42, 48–49, 55 | `isScrollControlled`/`useRootNavigator` — no non-default callers | ~8 |
| `lib/core/ui/states/offline_error_widget.dart` | 18, 24–29, 30, 62 | `retryLabel` param — semantic mismatch, single non-default use | ~5 |
| `lib/core/ui/states/generic_error_widget.dart` | 17, 23–25, 26, 57 | `retryLabel` param — same as above | ~5 |
| `lib/core/ui/states/stale_cache_banner.dart` | 13–14, 19 | `message` param — no non-default callers | ~5 |
| `lib/app/layout/breakpoints.dart` | 43 | Vestigial private ctor on `abstract final class` | ~1 |

**Total estimated removal**: ~40 LOC

---

### Simplification Recommendations

1. **Remove `masterFlex` / `childFlex` from `MasterDetailScaffold`** (Important)
   - Current: two public `int` params defaulting to 2/3, forwarded to `Expanded.flex`
   - Proposed: hardcode `flex: 2` and `flex: 3` directly in `build`; remove fields and ctor params
   - Impact: ~10 LOC, eliminates a YAGNI knob with zero callers

2. **Move `_filterIsEffectivelyEmpty` to `PokemonFilter.isEmpty`** (Important)
   - Current: private View-layer method that re-enumerates the domain entity's fields
   - Proposed: `bool get isEmpty => types.isEmpty && weaknesses.isEmpty && height == null && weight == null;` on the Freezed entity; call site becomes `filter?.isEmpty ?? true`
   - Impact: puts domain knowledge in the domain layer; prevents silent drift when new filter axes are added

3. **Remove `isScrollControlled` and `useRootNavigator` from `showSheetOrDialog`** (Important)
   - Current: two optional pass-through params with no non-default call sites
   - Proposed: hardcode `isScrollControlled: true` in the sheet branch; remove both params
   - Impact: ~8 LOC, cleaner API surface

4. **Remove `retryLabel` from `OfflineErrorWidget` and `GenericErrorWidget`; rename `onRetry` on detail to `onBack`** (Suggestion)
   - Current: `retryLabel` param used only in the detail screen to pass `'Back'`
   - Proposed: fix the label at `'Retry'`; give the detail `_Error` widget its own back button or accept a dedicated `onBack` callback on the error widgets with its own label
   - Impact: ~6 LOC, cleaner semantics

5. **Remove `message` from `StaleCacheBanner`** (Suggestion)
   - Current: optional `message` param, never overridden, single call site always uses default
   - Proposed: inline the string constant in `build`
   - Impact: ~5 LOC

6. **Remove vestigial `const Breakpoints._()` constructor** (Suggestion)
   - Current: private ctor on `abstract final class` — redundant guard
   - Proposed: delete the constructor; `abstract final` is sufficient
   - Impact: 1 LOC; small but consistent with the codebase pattern already challenged

---

### YAGNI Violations

| Violation | Why it violates YAGNI | Recommendation |
|-----------|----------------------|----------------|
| `masterFlex` / `childFlex` params on `MasterDetailScaffold` | No caller uses non-default values; they exist "in case a future screen wants a different split" | Remove; restore when a second call site exists |
| `isScrollControlled` / `useRootNavigator` on `showSheetOrDialog` | Three call sites all use defaults; `isScrollControlled` is inapplicable to the dialog path anyway | Remove; restore if a sheet caller needs `isScrollControlled: false` |
| `retryLabel` on `OfflineErrorWidget` / `GenericErrorWidget` | The detail screen could render its own back affordance rather than bending the retry-semantics API | Remove or rename to `ctaLabel` |
| `message` on `StaleCacheBanner` | List-only widget (per plan); single call site; message is fixed by the TE-02 spec | Remove |
| `generationLabel` nullable fallback on `EmptyGenerationWidget` | The only call site always computes the label (`'Gen ${state.generationId}'`); the `null` path ("this generation") exists for a hypothetical caller that doesn't have the label | Make `generationLabel` required; remove the null fallback |

---

### Final Assessment

**Total potential LOC reduction**: ~40 lines (~12% of the PR4 additions, not
counting comments and blank lines).

**Complexity score**: Low — the PR is well-structured and the widgets are
individually straightforward. The issues are all in the optional-parameter
layer: parameters added ahead of need with no current non-default callers.

**Recommended action**: Needs work — the `masterFlex`/`childFlex` and
`isScrollControlled`/`useRootNavigator` removals are worth doing before merge
(they shrink the API surface where YAGNI violations are most expensive). The
`_filterIsEffectivelyEmpty` relocation is a correctness / maintenance hazard
that should move to the domain entity. The remaining findings are clean-up
suggestions that can be batched.
