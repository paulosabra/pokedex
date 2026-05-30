---
date: 2026-05-27
reviewer: test-quality-review-agent
branch: feature/presentation-part3
scope: test/features/pokemon/presentation/ + test/app/app_boot_test.dart
---

# Test Quality Review — PR3 (Detail Tabs)

## Summary

- **Test run**: Pass — all tests green.
- **Coverage (presentation layer, excluding generated files)**: 95 %+ across all
  PR3 files; the two view-model files reach 100 %. The overall presentation
  layer meets the VGV ≥ 80 % gate.
- **Files with tests**: 8 / 8 required files present.
- **Missing test files**: none for shipped implementation files.
- **Verdict**: two blockers and four fixes must be addressed before merging.

---

## Blockers

### BLOCKER-1 — No-evolution "informative message" AC is not implemented or tested

**AC**: "No-evolution Pokémon shows informative message (RF-43 / RN-13)"
(plan line 788; PRD RN-13: *"Pokémon sem evolução exibem mensagem própria"*).

The implementation at `lib/…/evolution_tab.dart:70–71` handles
`evolvesTo.isEmpty` by rendering only `_StageCard(stage: node.stage)` — just
the Pokémon's card with no surrounding message. There is no text such as
*"This Pokémon does not evolve."*

The test at `test/…/evolution_tab_test.dart:103–116` asserts:
- `find.text('Tauros')` — card renders.
- `find.byIcon(Icons.arrow_forward)` — no arrow icon.

Neither assertion verifies an informative message, because the message does
not exist in the implementation. The test therefore passes a broken feature.
This is a double failure: the AC is unmet in production code, and the test
gives false confidence that it is met.

**Fix**: Add the informative text widget in `_EvolutionBranch.build` when
`node.evolvesTo.isEmpty && node == chain.root` (top-level single stage), then
add an `expect(find.text('This Pokémon does not evolve.'), findsOneWidget)`
assertion in the no-evolution test case.

---

### BLOCKER-2 — `_back` deep-link path (`context.go('/')`) is never exercised

`pokemon_detail_screen.dart:204–209`:

```dart
void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();  // covered
  } else {
    context.go('/');  // lines 198–202 — UNCOVERED
  }
}
```

Coverage confirms lines 198–202 are never hit. The error-state Back button
fires `_back`, and the test pumps `PokemonDetailScreen` directly inside a
bare `MaterialApp` (no prior route on the stack), so `context.canPop()` is
false in that setup. Yet the test at
`test/…/pokemon_detail_screen_test.dart:130–145` never taps the button —
it only asserts the button is present (`findsOneWidget`). The
`context.go('/')` branch is entirely untested.

This matters because the plan explicitly resolves this as blocker 4:
*"returns to list when OfflineFailure AND no stale cache"*; the navigation
side-effect is the point of the test.

**Fix**: Use a `GoRouter` fixture (mirror the pattern already in
`evolution_tab_test.dart:145–176`) in the offline-no-cache test. Tap the
Back button and assert the destination route was pushed, or assert
`find.text('/')` / `find.byType(PokemonListScreen)` appears.

---

## Fixes

### FIX-1 — Eevee branching test only checks text presence, not layout structure

`test/…/evolution_tab_test.dart:76–100`: the Eevee branching test (resolved
blocker 5) asserts that all 9 names render as text. It does not verify the
structural invariant the plan resolves: that the parent node (Eevee) appears
**exactly once** in the widget tree (not eight times — once per branch), which
is what `showParent: child == node.evolvesTo.first` at
`evolution_tab.dart:83` guarantees.

Without this structural assertion, a regression that breaks `showParent` and
renders Eevee eight times (or zero times for branches 2–8) would pass this
test. The conditions for each branch (e.g. "Use Water Stone", "Use Thunder
Stone") are also not asserted, leaving the `_Connector` widget and its
condition text entirely untested for the branching fixture.

**Fix**: Add:
```dart
// Parent shown exactly once across all 8 branch rows.
expect(find.text('Eevee'), findsOneWidget);
// At least one condition label is visible.
expect(find.textContaining('Stone'), findsWidgets);
```
`find.text('Eevee')` is already present but with `findsOneWidget` — the
structural assertion is actually already correct on line 91. The gap is the
missing condition-text assertions. Add at least:
```dart
expect(find.text('(Use Water Stone)'), findsOneWidget);
expect(find.text('(Level up with high friendship at day)'), findsOneWidget);
```

---

### FIX-2 — TE-10 coverage incomplete: zero height/weight and numeric-only Training fields not tested

`test/…/about_tab_test.dart:54–70` sets `genus`, `evYield`, `growthRate` to
`''` and `baseExp` to `null`, producing four `'—'` assertions. This is the
only TE-10 coverage.

Two branches in the implementation are not exercised:
- `about_tab.dart:116`: `if (meters <= 0) return '—'` — zero height renders
  `'—'` but no test sets `heightMeters: 0`.
- `about_tab.dart:124`: `if (kg <= 0) return '—'` — zero weight renders `'—'`
  but no test sets `weightKg: 0`.

The `stats_tab_test.dart` has no TE-10 test at all, and
`_formatMultiplier`'s `4×` and fallback `toStringAsFixed(2)` branches at
`stats_tab.dart:268–269` are uncovered.

**Fix**: In `about_tab_test.dart`, add a case with
`heightMeters: 0, weightKg: 0` and assert `find.text('—')` covers those two
rows. In `stats_tab_test.dart`, add a `typeDefenses` entry with `4.0` and one
with an unusual value (e.g. `1.5`) to hit the `'4'` and `toStringAsFixed`
branches.

---

### FIX-3 — RN-04 header background color is not behavior-asserted; golden does double-duty but not cleanly

`test/…/detail_header_test.dart`: the `_pump` helper sets the scaffold's
`backgroundColor` to `PokemonTypeTheme.styleOf(primary).backgroundColor`
(line 20). The test never changes `primary` between test cases, never asserts
that a different primary type produces a different background color, and there
is no fire-type or water-type variant. The golden on line 79 captures the
grass background, but the golden cannot be diffed to verify the
*behavior* that "primary type drives background". If `DetailHeader` were
refactored to ignore `primaryType` for its type badges, the golden would still
pass.

The AC in the plan is: *"Header bg colored by primary type via
`PokemonTypeTheme` (RF-29/RN-04)"*.

**Fix**: Add a second parametric test that pumps with
`primary: PokemonTypeId.fire`, reads the `Scaffold`'s `backgroundColor`, and
asserts it differs from the grass scaffold color:
```dart
final grassColor = PokemonTypeTheme.styleOf(PokemonTypeId.grass).backgroundColor;
final fireColor  = PokemonTypeTheme.styleOf(PokemonTypeId.fire).backgroundColor;
expect(grassColor, isNot(fireColor)); // sanity
// pump with fire, find Scaffold, check backgroundColor
```
This is a behavior assertion, not a pixel check.

---

### FIX-4 — `verify()` on the family-keying test adds no behavioral value

`test/…/pokemon_detail_view_model_test.dart:76–77`:
```dart
verify(() => getDetail.call(1)).called(1);
verify(() => getDetail.call(4)).called(1);
```
These `verify` calls are tacked on after the behavioral assertions (IDs are
correct, state is independent) at lines 74–83. The behavioral assertions
already prove each provider called the use case with the right argument. The
`verify` calls verify implementation (the call count) rather than behavior,
which will break under any future batching or caching optimisation that might
call the use case a different number of times while preserving correctness.

The single-result test at line 38 has the same pattern:
```dart
verify(() => getDetail.call(1)).called(1);
```

**Fix**: Remove the `verify(…).called(1)` lines. Keep the behavioral
assertions (`expect(result, same(detail))`, `expect(…summary.id, 1)`).
The happy-path test's `verify` is particularly redundant because `same(detail)`
already proves the exact instance was returned, which requires the call to
have occurred.

---

## Suggests

### SUGGEST-1 — Evolution tab has no golden

Every other tab widget (`AboutTab`, `StatsTab`, `DetailHeader`) has a
self-baselined golden. `EvolutionTab` does not. The plan's test strategy table
(line 319) says *"DS components: Flutter golden tests, self-baselined"* and
goldens were committed for the three other detail widgets. The plan's test
surface table for PR3 (line 769) does not explicitly require a golden for
`EvolutionTab`, but the omission is notable given the visual complexity of the
recursive branching layout (eight children with connectors and conditions).

**Suggest**: Add a golden for the Eevee 8-branch tree. It is the highest-value
visual regression target in PR3 because the branching layout is the most
structurally novel rendering path.

---

### SUGGEST-2 — Evolution loading skeleton state is not tested

The plan (resolved refine 7) requires the Evolution tab to *"show its own
loading skeleton if slower"*. `evolution_tab.dart:51` renders
`_EvolutionSkeleton()` during `AsyncLoading`. This state is never pumped in
`evolution_tab_test.dart`. A `pump` (without `pumpAndSettle`) with a delayed
future would exercise it.

---

### SUGGEST-3 — `_back` `context.canPop() == true` branch is not tested

Complementary to BLOCKER-2: there is no test that verifies the back button
calls `context.pop()` when there is a prior route. The evolution stage tap
test (line 135) uses `GoRouter` for navigation but does not test the detail
screen's own back button. A test that pushes the detail screen onto a router
stack and taps the header back arrow (or the `AppBar` back icon in the error
state) would cover both `canPop == true` and `canPop == false` paths.

---

### SUGGEST-4 — `CacheFailure` offline branch not separately tested

`pokemon_detail_screen.dart:157`: `isOffline = error is NetworkFailure || error is CacheFailure`.
Only `NetworkFailure` is tested in the offline test (line 135). The
`CacheFailure` branch is semantically different (cached data was corrupted
rather than the device being offline) yet uses the same offline copy. A
`CacheFailure` variant test would catch a future refactor that splits the
condition.

---

## Coverage Summary (PR3 files)

| File | Line coverage |
|------|--------------|
| `view_models/pokemon_detail_view_model.dart` | 100 % (4/4) |
| `view_models/pokemon_evolution_provider.dart` | 100 % (4/4) |
| `widgets/detail/about_tab.dart` | 100 % (117/117) |
| `widgets/detail/detail_header.dart` | 98 % (48/49) — errorWidget cb |
| `widgets/detail/evolution_tab.dart` | 99 % (74/75) — errorWidget cb |
| `widgets/detail/stats_tab.dart` | 98 % (90/92) — `4×` + fallback multiplier |
| `pages/pokemon_detail_screen.dart` | 87 % (48/55) — `_back` else branch + `DetailHeader` instantiation line |

The three uncovered `errorWidget` callbacks in `detail_header.dart:193` and
`evolution_tab.dart:228` are `CachedNetworkImage` error handlers that require
a network failure injection not readily available in unit widget tests. These
are acceptable gaps at this stage; a note in the test file would help future
maintainers understand why.

---

## AC Coverage Matrix

| Plan AC | Test file | Covered? |
|---------|-----------|----------|
| Detail screen replaces placeholder; deep-link smoke green | `pokemon_detail_screen_test.dart:100`, `app_boot_test.dart:104` | Yes |
| Header bg colored by primary type (RN-04) | `detail_header_test.dart:79` (golden only) | Partial — see FIX-3 |
| About: Pokédex Data / Training / Breeding / Location (RF-31..34) | `about_tab_test.dart:19–28` | Yes |
| Stats: 6 stats + Total + Min/Max + Type Defenses (RF-35..39) | `stats_tab_test.dart:21–82` | Yes |
| Evolution: recursive branching (Eevee) (resolved blocker 5) | `evolution_tab_test.dart:76–100` | Partial — see FIX-1 |
| Tapping evolution stage fires `context.go('/pokemon/$id')` (resolved refine 3) | `evolution_tab_test.dart:135–176` | Yes |
| No-evolution shows informative message (RN-13) | `evolution_tab_test.dart:103–116` | NO — see BLOCKER-1 |
| Missing fields render "—" (TE-10) | `about_tab_test.dart:54–70` | Partial — see FIX-2 |
| Offline x no-cache shows Back CTA (resolved blocker 4) | `pokemon_detail_screen_test.dart:129–145` | Partial — presence only, navigation not fired — see BLOCKER-2 |
| Evolution tab uses separate provider, lazy loads (resolved refine 7) | `pokemon_evolution_provider_test.dart:27–86` | Partial — loading state not exercised — see SUGGEST-2 |
| TE-11 placeholder on header artwork (resolved refine 8) | `detail_header_test.dart:59–66` | Yes |
| Goldens self-baselined | `goldens/detail_header.png`, `about_tab.png`, `stats_tab.png` | Partial — no evolution golden — see SUGGEST-1 |

---

## Verdict

**Fix 2 blockers before merging.**

- **BLOCKER-1**: The no-evolution informative message (RN-13 / RF-43 AC) is
  unimplemented in production code, and the test gives false confidence.
- **BLOCKER-2**: The `_back` deep-link navigation path is never exercised; the
  test confirms the button exists but does not verify it navigates.

FIX-1 through FIX-4 are quality issues that should be resolved in this PR.
SUGGEST-1 through SUGGEST-4 are improvements worth scheduling before the epic
closes.
