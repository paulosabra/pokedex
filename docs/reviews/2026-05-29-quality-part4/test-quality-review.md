# Test Quality Review — T-31 (PR4): Web Deploy + C-1 Router Fix

> **Branch:** `feature/quality-part4`
> **Reviewer:** Test Quality Review Agent
> **Date:** 2026-05-29
> **Scope:** `test/app/router/route_error_screen_test.dart` (NEW) and `integration_test/app_test.dart` (MODIFIED — C-1 E2E added)

---

## Coverage Summary

- **Test run:** Not executed locally (integration tests require `flutter drive` on a web-server target; unit tests require sqlite3 native library unavailable in this review environment). Static analysis via `dart analyze` is the verification proxy.
- **Coverage gate:** ≥ 80% (hand-written code baseline 94.8% from T-29). `RouteErrorScreen` is a `ConsumerWidget` with a single `build` method — fully exercised by the three unit tests. `app_router.dart`'s C-1 branches (`tryParse` null path, `errorBuilder`) are covered exclusively at the E2E layer, which is intentionally excluded from the coverage lcov (per CI design). See §"Coverage Decision: E2E-only for Router Logic" below.
- **Files with tests:** 2/2 touched implementation files have test coverage.
  - `lib/app/router/route_error_screen.dart` — `test/app/router/route_error_screen_test.dart` (NEW)
  - `lib/app/router/app_router.dart` — `integration_test/app_test.dart` (C-1 test added); no new `app_router_test.dart` (see §"Coverage Decision")
- **Missing test files:** None for the stated scope.

### C-1 coverage matrix

| Code path | Covered by | Assertion type |
|---|---|---|
| `RouteErrorScreen` renders TE-03 message | Unit — `route_error_screen_test.dart` | `findsOneWidget` on message text |
| `RouteErrorScreen` renders Go home CTA | Unit — `route_error_screen_test.dart` | `findsOneWidget` on `ElevatedButton` |
| `error_shown` emitted once on mount | Unit — `route_error_screen_test.dart` | `hasLength(1)` + full parameter map equality |
| Go home CTA navigates to `/` | Unit — `route_error_screen_test.dart` | `findsOneWidget` on destination scaffold |
| `int.tryParse` null → `RouteErrorScreen` | E2E — `app_test.dart` | `findsOneWidget` on message text via real router |
| `errorBuilder` → `RouteErrorScreen` | E2E — `app_test.dart` | `findsOneWidget` on message text via real router |
| CTA recovery from deep-link error | E2E — `app_test.dart` | `findsWidgets` on `PokemonCard` list |

---

## Unit Test Quality: `route_error_screen_test.dart`

### Test 1 — `renders the TE-03 message and a Go home CTA`

**Result:** Pass

Uses a bare `ProviderScope` (no overrides), which resolves `analyticsServiceProvider` to `NoopAnalyticsSink`. The `error_shown` event fires and is silently dropped — this is correct for a render-focused test. The two assertions are meaningful and non-tautological: they verify the exact user-facing string from the PRD spec and the specific button type, not just that "something exists". The test is appropriately scoped: it is testing UI composition, not analytics, so the noop sink is the right choice.

**One minor concern:** The test title says "Go home CTA" but does not assert that the CTA is _tappable_ (i.e. `onPressed` is not null). However, since Test 3 taps the same button and verifies a navigation side-effect, the combined coverage is sufficient. No fix required.

### Test 2 — `emits error_shown TE-03 once on mount`

**Result:** Pass

This is the strongest analytics test in the PR. Key qualities:

- Uses `RecordingAnalytics` (the project-standard recording fake) injected via `ProviderScope.overrides` — correct pattern, consistent with all prior `error_shown` tests in the codebase.
- `hasLength(1)` enforces the "once on mount" contract from `GenericErrorWidget.initState`. Because `initState` calls `onShown` exactly once and does not wire `didUpdateWidget`, a second pump would not re-fire. The single-emission contract is verified correctly.
- `shown.single.parameters` with a full map literal `{'te_code': 'TE-03', 'screen': 'route_error'}` asserts both the TE code and the screen name in one shot. This is full equality (not a subset), so any accidental extra key or typo in either value causes a failure. Sound.
- No `pumpAndSettle` between the initial pump and the assertion — correct, because `initState` fires synchronously during the first frame; no additional settle is needed.

**No issues found.**

### Test 3 — `Go home CTA navigates to /`

**Result:** Pass with one suggestion

Sets up a minimal `GoRouter` with two routes (`/` and `/oops`), starts at `/oops` which renders `RouteErrorScreen`, then taps "Go home" and verifies the destination renders `'home'`.

Strengths:
- `addTearDown(router.dispose)` is correctly present — resource leak avoided.
- `pumpAndSettle()` called after both the initial pump and the tap — correct async handling.
- The destination assertion (`find.text('home')`) is a behavioral assertion, not an implementation detail.

**Suggestion:** The route under test is `/oops` which is a GoRouter-defined route (not a GoRouter error path). This means the test exercises the widget's `onRetry` callback correctly, but it does not test the specific entry path of the real app (i.e. the GoRouter `errorBuilder` returning `RouteErrorScreen` from a matched-route context). This distinction is immaterial because `RouteErrorScreen` is stateless and its `onRetry` is always `() => context.go('/')` regardless of how the widget was mounted — the test correctly isolates the widget's own behavior. No fix required; noting for completeness.

---

## E2E Test Quality: `integration_test/app_test.dart` (C-1 addition)

### Test — `C-1: malformed and unmatched deep links render TE-03`

**Result:** Pass

**Router access pattern (line 102):**
```dart
final router = ProviderScope.containerOf(
  tester.element(find.byType(PokedexApp)),
).read(routerProvider)..go('/pokemon/abc');
```
The Dart cascade (`..go()`) is valid: `read(routerProvider)` returns the `GoRouter` instance (assigned to `router`), and `..go('/pokemon/abc')` calls `go()` on that instance before the statement completes. `GoRouter.go()` is synchronous (it updates the router's internal location state); the subsequent `pumpAndSettle()` drives the widget tree to reflect that state change. This is the correct pattern and consistent with how router navigation is driven in widget tests throughout the Flutter ecosystem.

**Assertions:**

- Both error paths assert `find.text("This page doesn't exist.")` with `findsOneWidget`. This is a meaningful behavioral assertion: it verifies the user-visible TE-03 message appears rather than an empty screen, a crash, or a different error. The string matches the exact constant in `RouteErrorScreen`'s `GenericErrorWidget` invocation.
- The recovery assertion (`find.byType(adapter.PokemonCard), findsWidgets`) verifies that tapping "Go home" returns to a working list screen, not merely that navigation fired. This is behavioral and non-trivial.
- `pumpAndSettle()` is called after each `go()` and after the tap — correct async handling throughout.

**No anti-patterns found.** No tautological assertions, no unverified interactions, no missing awaits.

---

## Coverage Decision: E2E-only for Router Logic

The plan deliberately colocates the `tryParse`-null and `errorBuilder` verification at the E2E layer. This warrants explicit assessment.

**Case for this being reasonable:**

The C-1 fix lives in `app_router.dart`'s `router` provider function — a Riverpod-generated factory that constructs a `GoRouter` with specific `routes` and `errorBuilder`. Unit-testing a provider that returns a `GoRouter` requires either:
1. Standing up `MaterialApp.router(routerConfig: ...)` with the real provider output, which is effectively what the E2E does; or
2. Navigating a bare `GoRouter` instance in a `WidgetTest`, which is what Unit Test 3 does for the `RouteErrorScreen` widget — but this bypasses the `routerProvider` factory entirely and cannot verify that `int.tryParse` is the guard in the route builder.

The E2E accesses the actual `routerProvider` from the live container, sends both problem inputs (`/pokemon/abc` and `/no-such-route`) through the real routing pipeline, and observes the correct screen. This is a higher-fidelity verification of the fix than any unit test could provide without duplicating the router setup.

**Remaining gap (suggestion, not critical):**

No unit test exercises the `app_router.dart` factory at the level of "given path `/pokemon/abc`, the route builder calls `int.tryParse` and returns `RouteErrorScreen`." A dedicated `GoRouter`-level widget test (not the full E2E) could cover this with sub-second latency and without requiring a browser. However, given that:
- The E2E deterministically exercises this path on the real router,
- The unit tests cover `RouteErrorScreen`'s own behavior exhaustively, and
- The `int.tryParse` guard is a two-line change with no branching complexity beyond what the E2E already exercises,

...the absence of a router-level unit test is a minor gap in test pyramid shape, not a correctness risk.

**The web-safety rationale for choosing non-numeric over int64-overflow is sound.** Dart's `int` on web (JS number) silently coerces values beyond `Number.MAX_SAFE_INTEGER`, making `int.tryParse('99999999999999999999')` non-null on web. Non-numeric input is the only deterministic web-safe probe for the `tryParse`-null branch.

---

## Anti-Pattern Detection

No anti-patterns found. Specifically:

| Pattern checked | Verdict |
|---|---|
| Tautological assertions | None — all assertions verify observable behavior or event state |
| Mocking the class under test | N/A — `RecordingAnalytics` fakes a dependency, not the widget |
| Missing async waiting after state changes | None — `pumpAndSettle()` follows every `go()` call and every tap |
| No assertions | None — every test has at least two meaningful assertions |
| Over-verification | None — no `verify()` calls; recording fake avoids mock-verification brittleness |
| Magic values | None — `'TE-03'`, `'route_error'`, `"This page doesn't exist."` are all spec-defined constants |
| Implementation mirroring | None — tests assert outputs, not internal call sequences |

---

## Suggestions (Non-blocking)

1. **Router-level widget test for `app_router.dart` C-1 branches** — A `testWidgets` test that creates the real `routerProvider` against an in-memory container, navigates to `/pokemon/abc` and `/no-such-route` via a `MaterialApp.router`, and asserts `RouteErrorScreen` appears would give sub-second sub-E2E coverage of the guard logic. This is not a blocking gap given the E2E coverage, but it would close the test pyramid shape and run in the `flutter test` gate (adding to the coverage denominator for `app_router.dart`).

2. **`app_router.dart` currently has zero unit-test coverage in the lcov gate** — because `app_router.g.dart` (the generated `routerProvider`) is excluded by the `lcov --remove '*.g.dart'` filter, but `app_router.dart` itself is hand-written and is not filtered. With only E2E coverage (excluded from the gate by CI design), the lines in `app_router.dart` contribute uncovered lines to the gate. Given the reported 94.8% baseline this is unlikely to breach the 80% floor, but it is worth noting.

3. **E2E does not verify `error_shown` emission** — the C-1 E2E test verifies the TE-03 _screen_ appears but does not check that the `error_shown` analytics event fires in the real app context. The unit test covers the emission contract, so this is not a gap in correctness; but an E2E-level smoke check (`expect(analytics.named('error_shown'), isNotEmpty)`) with a `RecordingAnalytics` override in `E2EHarness` would provide defense-in-depth. Low priority.

---

## Verdict

**Ready to merge.** Zero critical issues. Zero important issues. Three suggestions (all non-blocking).

The unit test suite for `RouteErrorScreen` is complete and correctly structured: render test, analytics emission test, and CTA navigation test each target a distinct behavior with meaningful, non-tautological assertions. The `RecordingAnalytics` pattern is applied correctly and consistently with the rest of the codebase. The E2E extension exercises the real `routerProvider` on both C-1 failure paths with correct async handling and behavioral assertions. The coverage decision to colocate verification at the E2E layer is well-reasoned and explicitly documented in the test file's doc comment.
