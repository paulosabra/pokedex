# VGV Code Review — Foundation PR3 (T-04 · Theme + design tokens + `PokemonTypeTheme`)

- **Branch:** `feature/foundation-part3` (stacked on merged PR1 + PR2) → target `epic/foundation`
- **Scope reviewed:** `lib/core/pokemon/pokemon_type_id.dart`, `lib/app/theme/app_colors.dart`, `lib/app/theme/app_typography.dart`, `lib/app/theme/app_theme.dart`, `lib/app/theme/pokemon_type_theme.dart`, `lib/app/app.dart`, `test/app/theme/pokemon_type_theme_test.dart`, `test/app/app_boot_test.dart`
- **Source of truth:** `docs/plan/2026-05-24-chore-foundation-setup-plan.md` (PR3 — Theme section), Tech Spec §10.1 / §10.2 / §10.3
- **Reviewed:** 2026-05-24

## Summary

A clean, faithful, well-scoped implementation of the foundation theme slice. All 18 §10.3 badge hexes are transcribed **exactly**; the two exact §10.3 backgrounds (Grass `#8BBE8A`, Fire `#FFA756`) are correct; the provisional 50%-toward-white tint for the other 16 matches the plan's pinned formula. Typography re-expresses §10.2 (sizes/weights) and is mapped into Material 3 text roles while staying directly usable. `PokemonTypeId` is correctly placed in `core/` per the documented, plan-justified deviation, and `PokemonTypeStyle` is a record with a documented T-18 migration path to a class. Token holders use VGV-idiomatic `abstract final class` with a private constructor. `dart analyze` on the changed paths returns **No errors**; the full test suite passes with coverage; the boot test was correctly strengthened to assert the global theme. All three T-04 acceptance criteria are met.

The deliberate, plan/spec-justified decisions listed in the task brief (enum placement in `core/`, record-not-class for the style, provisional white-lerp tints for 16 types, Material-barrier-default modal opacity, per-value enum docs, typography mapped into `textTheme`) are correctly applied and are **not** flagged below.

**Process caveat (not a code defect):** PR3 files are currently untracked / uncommitted working-tree changes (`git status` shows `?? lib/app/theme/`, `?? lib/core/pokemon/`, `?? test/app/theme/`, plus modified `lib/app/app.dart` and `test/app/app_boot_test.dart`; no T-04 commit on the branch). The work is invisible to git/CI until committed. Noted for parity with the PR1/PR2 reviews; the code itself is ship-quality.

## Critical — Must Fix Before Merge

None.

## Important — Should Fix

None blocking. The one item worth a deliberate decision before merge (Material 3 surface color) is captured under Minor below because it does not affect the foundation acceptance and has no current consumer; promote it to a tracked T-18 item rather than fixing here.

## Minor

- **`lib/app/theme/app_theme.dart:13-15` — `ColorScheme.surface` is not the §10.1 `Background / White` (`#FFFFFF`).** `ThemeData` defaults to Material 3 (Flutter 3.44 / SDK `^3.12`), where `Scaffold`, `Card`, `BottomSheet`, `Dialog`, and `AppBar` derive their fills from `colorScheme.surface` / `surfaceContainer*`, **not** from `scaffoldBackgroundColor`. `ColorScheme.light()` ships `surface = #FFFFFBFE` (an off-white M3 tone), so sheets/cards/dialogs will not render pure §10.1 white. `scaffoldBackgroundColor` masks this for the bare `Scaffold` (and the boot test only asserts that field), but the first `showModalBottomSheet`/`Card` in the UI layer will reveal the gap.
  - Why: §10.1 specifies `Background / White #FFFFFF` for "fundo de telas/sheets". The current theme satisfies it only for the scaffold body, not for the surfaces Material 3 actually uses for sheets/cards.
  - Fix (when the UI layer lands, e.g. T-18): set `surface` (and the relevant `surfaceContainer*` roles) on the `ColorScheme`, e.g. `ColorScheme.light(surface: AppColors.backgroundWhite, onSurface: AppColors.textBlack)`, and consider `appBarTheme`/`bottomSheetTheme`/`cardTheme` backgrounds. Acceptable to defer, but track it explicitly so it is not silently lost.

- **`lib/app/theme/app_colors.dart:17,24` — `backgroundInput` and `backgroundModal` are defined but unwired (no current consumer).** Confirmed by grep: neither token is referenced outside its own declaration. This is fine for a token-definitions slice, but note that `backgroundModal`'s documented "Material barrier default (54%)" decision is currently inert — the actual scrim is whatever `showModalBottomSheet`/`ModalBarrier` uses at call time, not this constant. When sheets land, wire `backgroundInput` into an `InputDecorationTheme` and either use `backgroundModal` at the `showModalBottomSheet(barrierColor:)` call or drop the token to avoid a divergent source of truth.
  - Why: an unused styled token that documents a specific behavioral choice can drift from the actual runtime behavior and create false confidence.

- **`lib/app/theme/app_theme.dart:16` + `app_typography.dart:8` — the `'SF Pro Display'` family string is duplicated.** It is a private `_fontFamily` constant in `AppTypography` but a bare string literal in `AppTheme.light`. A future rename touches two places.
  - Why: single-source-of-truth for tokens; the rest of this slice is exemplary about centralization.
  - Fix: expose the family from one place (e.g. `AppTypography.fontFamily` or an `AppFonts` constant) and reference it in `ThemeData(fontFamily: ...)`.

- **`pubspec.yaml:42-43` — the Semibold (weight 600) font asset is bundled but never referenced by §10.2 / `AppTypography`.** Every `AppTypography` style uses 400/500/700; 600 is declared in `fonts:` but no token requests it. PR1's stated rationale was to ship only the weights the design uses; 600 currently earns no keep in this slice.
  - Why: a ~2.3 MB asset with no consumer contradicts the foundation's own font-trimming decision and inflates the web payload.
  - Fix: either drop the Semibold weight until a §10/Figma token demands it, or add a tracking note that T-18 will introduce a Semibold token. (Out of strict PR3 scope since fonts landed in PR1 — flag, don't block.)

## Suggestion

- **`lib/app/theme/app_theme.dart:13` — `static ThemeData get light` rebuilds the `ThemeData` on every access.** `ThemeData` is not const-constructible here, but `MaterialApp` reads `theme` on each build; a getter re-allocates each time. Consider a `static final ThemeData light = _build();` (or a cached late-final) so the instance is created once. Negligible at one call site today; cheap to make idiomatic before more consumers read it.

- **`test/app/theme/pokemon_type_theme_test.dart:8-22` — the RN-04 widget test reuses `find.byType(ColoredBox)` across two `pumpWidget` calls.** This works (the second pump replaces the tree) and is correct, but a reader may briefly wonder whether two boxes coexist. A one-line comment, or distinct `Key`s, would make the intent obvious. Optional.

- **`test/app/theme/pokemon_type_theme_test.dart:34-47` — the derived-background assertion only checks `water` is `isNot(water.color)`.** It proves the tint differs from the badge color but not that it equals the pinned `Color.lerp(color, white, 0.5)` formula. A single positive assertion against the computed lerp value (for one type) would lock the documented formula against accidental drift before T-18 reconciles it. Optional, since the formula is explicitly provisional.

## Acceptance verification (T-04)

- [x] **`ThemeData` with §10.1 base colors + SF Pro Display typography** — `AppTheme.light` sets `fontFamily: 'SF Pro Display'`, `scaffoldBackgroundColor` = §10.1 white, `onSurface` = §10.1 `#17171B`, and maps §10.2 styles into `textTheme`. (Caveat: `ColorScheme.surface` not white — see Minor; does not block acceptance.)
- [x] **`PokemonTypeTheme` covers all 18 types with §10.3 colors + derived bg tints** — `_colors` has all 18 enum keys; `styleOf` force-unwraps `_colors[type]!`, so a missing key would throw (and the "18 unique colors" test guards completeness). Exact backgrounds for Grass/Fire; lerp tint for the other 16.
- [x] **Theme applied globally; color-by-type verified in a widget test** — `app.dart:13` wires `theme: AppTheme.light`; `pokemon_type_theme_test.dart` asserts fire vs water resolve to distinct §10.3 colors (RN-04); `app_boot_test.dart` asserts the global theme is present.

### §10.3 hex transcription — verified exact (18/18)

| Type | §10.3 | impl | Type | §10.3 | impl |
| --- | --- | --- | --- | --- | --- |
| grass | `62B957` | ✓ | poison | `A552CC` | ✓ |
| fire | `FD7D24` | ✓ | water | `4A90DA` | ✓ |
| electric | `EED535` | ✓ | bug | `8CB230` | ✓ |
| normal | `9DA0AA` | ✓ | flying | `748FC9` | ✓ |
| ground | `DD7748` | ✓ | fairy | `ED6EC7` | ✓ |
| fighting | `D04164` | ✓ | psychic | `EA5D60` | ✓ |
| rock | `BAAB82` | ✓ | ghost | `556AAE` | ✓ |
| ice | `61CEC0` | ✓ | dragon | `0F6AC0` | ✓ |
| dark | `58575F` | ✓ | steel | `417D9A` | ✓ |

Backgrounds: Grass `#8BBE8A` ✓, Fire `#FFA756` ✓ (both exact §10.3). §10.1 base colors and §10.2 sizes/weights also transcribed correctly.

### Verification performed

- `dart analyze` (MCP) on `lib/app/theme`, `lib/core/pokemon`, `lib/app/app.dart`, `test/app` → **No errors**.
- Full test suite with coverage (very_good test) → **passed**.
- Hex / token cross-check against Tech Spec §10.1–§10.3 → all exact.

---

**Verdict:** Ready to merge — 0 critical, 0 blocking-important issues; minor items (Material 3 `surface`, unwired tokens, font-family duplication, Semibold asset) are defer-to-T-18 / nice-to-have, plus the standard "commit before CI" process caveat.
