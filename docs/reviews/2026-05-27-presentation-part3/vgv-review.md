# VGV Engineering Review — Presentation PR3 (Detail screen + 3 tabs)

**Branch:** `feature/presentation-part3`
**Reviewer:** vgv-review-agent (Opus 4.7)
**Date:** 2026-05-27

## Summary

**Ready to merge with minor fixes.** The plan-time collapses (drop the
`PokemonDetailState` Freezed wrapper; demote `PokemonEvolutionViewModel`
to a function provider) are justified, narrowly scoped, and well-
documented in the source — both files cite their YAGNI reasoning and
point to the migration path if intents reappear. Layer separation is
clean (no `data/` imports under `presentation/`), Riverpod 3.x family
syntax is canonical (positional `build(int id)` over the deprecated
`.family` modifier), goldens are self-baselined, mocktail +
`ProviderContainer.overrides` is the canonical test wiring, and the
recursive `_EvolutionBranch` correctly handles Eevee's 8-way branch
plus the single-stage and linear cases. Two `Fix`-level issues warrant
attention before merge — both around defensive UI behavior — and a
handful of `Suggests` are judgment calls.

| Severity | Count |
| -------- | ----- |
| Blocker  | 0     |
| Fix      | 2     |
| Suggest  | 6     |

---

## Blockers

_(None.)_

---

## Fixes — should fix before merge

### F1. `types.first` will throw on a Pokémon with zero recognised types

**Files:**
- `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:49-51`
- `lib/features/pokemon/presentation/widgets/detail/about_tab.dart:26-28`
- `lib/features/pokemon/presentation/widgets/detail/stats_tab.dart:27-29`

`Pokemon.types` is declared `@Default(<PokemonTypeId>[])` and the data
mapper at `lib/features/pokemon/data/mappers/pokemon_mapper.dart:14-16`
filters unknown types via `.whereType<PokemonTypeId>()`. If a future
Pokémon (or a corrupted cache row) yields zero recognised types,
`detail.summary.types.first` throws a `StateError` and the entire
detail screen crashes inside `_Loaded.build` — `AsyncValue` has already
resolved, so the `error: (...)` branch on the parent is bypassed.

The same hazard exists pre-PR3 in `lib/core/ui/components/pokemon_card.dart`
and the list-tab analogue, but this PR widens the blast radius (three
new tab widgets now rely on `types.first`). Decide on a consistent
fallback at the presentation boundary.

**Fix sketch:**
```dart
final primary = types.isEmpty ? PokemonTypeId.normal : types.first;
```
…or surface the empty-types case as a domain invariant (assert in
`pokemonFromDto`). Either way, pick one and add a test fixture variant.

### F2. `cached_network_image` placeholder loop on the detail header

**File:** `lib/features/pokemon/presentation/widgets/detail/detail_header.dart:184-198`

`_Artwork` shows the broken-image placeholder when `imageUrl.isEmpty`
**or** when network fetch fails (`errorWidget`), but never renders a
`placeholder:` while the network image is in flight. The artwork
circle is 125×125 on the colored type background — during a slow
network leg the user sees the colored circle with nothing in it for
the duration of the fetch (no progress, no shimmer, no broken-image
icon). This is jarring during normal use, not just edge cases.

Compare with `lib/core/ui/components/pokemon_card.dart:140-159` which
also omits the placeholder — same omission, but the card is small
enough that the empty slot reads as intentional. At 125×125 it reads
as a layout bug.

**Fix sketch:**
```dart
CachedNetworkImage(
  imageUrl: imageUrl,
  fit: BoxFit.contain,
  placeholder: (_, _) => const _ArtworkPlaceholder(),
  errorWidget: (_, _, _) => const _ArtworkPlaceholder(),
)
```
Or use a faint shimmer if `cached_network_image` is already pulling
one in transitively — but matching `errorWidget` is the lowest-cost
correctness fix.

---

## Suggests — judgment calls

### S1. `_Error` treats `TimeoutFailure` as a generic failure

**File:** `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:151`

The offline-vs-generic split only matches `NetworkFailure ||
CacheFailure`. `TimeoutFailure` is, semantically, an offline-ish
condition (and arguably the most common transient error in the
field). It currently falls through to "Could not load this Pokémon"
which obscures the most actionable signal for the user. PR4 will
replace this with `OfflineErrorWidget` (TE-01) — at that boundary,
audit the mapping. Until then, consider widening:

```dart
final isOffline = error is NetworkFailure
    || error is CacheFailure
    || error is TimeoutFailure;
```

### S2. Five `_capitalize` implementations across the presentation tree

**Files:**
- `lib/features/pokemon/presentation/widgets/detail/detail_header.dart:135-136`
- `lib/features/pokemon/presentation/widgets/detail/about_tab.dart:258-259`
- `lib/features/pokemon/presentation/widgets/detail/stats_tab.dart:86-87`
- `lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart:209-210`
- (existing) `lib/core/ui/components/pokemon_card.dart:164-165`

Duplication is fine when each instance is local, but five copies of
the exact same one-liner is past the threshold. Lift to a
`String.capitalized` extension under `lib/core/extensions/` (or `lib/
core/text/`) — small, focused, no premature abstraction. This is a
YAGNI-friendly DRY: a single dedicated extension is cheaper than
five inlined copies and easier to localise if i18n ever shows up.

### S3. AboutTab renders `0` for absent numeric Pokédex fields

**File:** `lib/features/pokemon/presentation/widgets/detail/about_tab.dart:54-60, 82-85`

The data mapper at
`lib/features/pokemon/data/mappers/pokemon_detail_mapper.dart:46-47`
defaults `catchRate` / `baseFriendship` to `0` when the species DTO
is missing. The AboutTab renders these via `.toString()` — so a
Pokémon with no species data shows "Catch Rate: 0" / "Base
Friendship: 0", indistinguishable from a legitimately captured 0.
TE-10 says missing fields render as `—`. Two paths:

- Lift to nullable in the entity (`int? catchRate`) and render `—`
  for null. The data mapper would emit `null` instead of `0`.
- Leave the entity, but document the convention (presented-as-0 is
  treated-as-present) explicitly in the entity doc-comment.

The first is the right fix; the second is acceptable if the
convention is documented and tested. Either way, surface the choice.

### S4. `_Error` Back CTA does not retry — only navigates

**File:** `lib/features/pokemon/presentation/pages/pokemon_detail_screen.dart:182-186`

The plan's resolved-blocker-4 calls out an `OfflineErrorWidget + back
CTA` for the detail × offline × no-cache case. The current
implementation has no Retry affordance — only "Back". A user who
flips airplane mode off has to back out, re-tap the row, and re-load.
A Retry CTA would call `ref.invalidate(pokemonDetailViewModelProvider(id))`.

PR4 introduces the `OfflineErrorWidget` (TE-01) — at that integration
point, decide whether Retry belongs alongside Back. If PR4 stays
strictly Back-only per the plan, leave this. If it splits offline /
generic, wire Retry for generic.

### S5. Evolution tap navigates with `context.go`, dropping the back stack

**File:** `lib/features/pokemon/presentation/widgets/detail/evolution_tab.dart:173`

Tapping Bulbasaur → Ivysaur → Venusaur via the chain card uses
`context.go('/pokemon/3')`, which **replaces** the current route in
go_router. After the third tap, the back stack contains a single
entry (`/pokemon/3`), and `_back()`'s `canPop()` returns false →
lands on `/`. This is consistent with `pokemon_card.dart:27` and the
plan's resolved-refine-3, so it isn't a regression — but the
user-visible UX is "back loses my chain history". Consider
`context.push('/pokemon/${stage.id}')` from chain taps so the user
can walk back up the chain via the system back gesture. If the
project's stance is firmly "go everywhere, no push", leave the note.

### S6. Hardcoded magic numbers in `DetailHeader` positions

**File:** `lib/features/pokemon/presentation/widgets/detail/detail_header.dart:62-129`

`Positioned(top: 15, left: 40, top: 30, top: 85, top: 104, top:
123, top: 166, ...)` is the literal Figma layout, but scattered
across seven `Positioned` blocks with no shared constant. A
private `const _layout = (...)`record, or even one `static const`
group at the top of the class, would let the next maintainer audit
the layout shape without re-deriving the geometry. Same observation
for the four `_Section`/`_Row` `width: 95` / `width: 56` magic
numbers in About/Stats.

This is the kind of code that "everyone knows" the moment they wrote
it and is opaque to everyone else.

---

## Notes

- **State management:** the `PokemonDetailViewModel` collapse to
  `AsyncValue<PokemonDetail>` is well-defended in the source
  doc-comment (`pokemon_detail_view_model.dart:13-20`) and cites the
  migration path for future pull-to-refresh. Acceptable YAGNI.
- **`pokemonEvolutionProvider` as `@riverpod` function:** correct
  call — the Evolution tab has no intents to expose, so a
  `FutureProvider`-equivalent function is right-sized. The
  `@riverpod` codegen path is identical to the list VM's, so the
  convention is preserved.
- **Test discipline:** the 18-test detail suite plus the
  `_makeHarness` / `_pumpScreen` factories in
  `pokemon_detail_screen_test.dart` are the cleanest expression of
  test-setup composition in the project. The Eevee fixture is well-
  chosen for the worst-case branching shape and is reused across
  three test files without duplication.
- **Recursive `_EvolutionBranch`:** the implementation
  (`evolution_tab.dart:63-89`) deviates from the plan's sketch
  (which used a `Row` for branches) and instead lays branches
  vertically with the parent suppressed on subsequent children
  (`showParent: child == node.evolvesTo.first`). This is closer to
  the Figma `268:513` two-row layout for Eevee and renders correctly
  for both linear and branching cases. The linear-chain test
  (`evolution_tab_test.dart:67-71`) documents the "Ivysaur appears
  twice" property — good signal that the deviation was intentional.
- **Goldens:** three goldens committed
  (`detail_header.png`, `about_tab.png`, `stats_tab.png`). The
  evolution tab has no golden — given the recursive layout and
  reliance on the Eevee fixture, a branching-Eevee golden would be
  a high-signal addition (deferred to PR4 alongside the responsive
  goldens? worth a checkbox in the next plan).
- **Deep-link smoke (`test/app/app_boot_test.dart:104-136`):** the
  updated override stubs both `getPokemonDetailProvider` and
  `getEvolutionChainProvider` with `Err(NetworkFailure)` to keep
  `pumpAndSettle` finite. The inline comment documents the
  rationale. Clean.
- **`build.gradle.kts` / linting:** `dart analyze` on both
  `lib/features/pokemon/presentation/` and
  `test/features/pokemon/presentation/` is clean. No suppressions
  introduced.
