---
date: 2026-05-27
reviewer: code-simplicity-agent
branch: feature/presentation-part2
scope: T-19/T-20/T-21/T-22/T-23
---

# Code Simplicity Review — PR2 (Home + Discovery Sheets)

## Core Purpose

`PokemonListViewModel` owns browse/discovery state for one screen and mediates
five domain calls. `PokemonListScreen` renders that state and opens three
stateful sheets. Six test files exercise the ViewModel, the screen, the adapter
widget, and the three sheets.

---

## Unnecessary Complexity Found

### 1. `_loadFirstPage` carries a dead `sort` parameter

`lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart:196-209`

`_loadFirstPage({required SortCriteria sort})` receives `sort` only to thread
it into `PokemonListState(sort: sort, ...)`. The call site always passes
`SortCriteria.numberAsc`, which is already the `@Default` value in
`PokemonListState`. The parameter adds a named-argument ceremony with zero
behavioural difference.

**Suggest** — drop the parameter and the named argument at both call sites:

```dart
// before
Future<PokemonListState> _loadFirstPage({required SortCriteria sort}) async {
  final result = await ref.read(getPokemonListProvider).call(...);
  return switch (result) {
    Ok(:final value) => PokemonListState(
        items: value.items,
        offset: value.items.length,
        hasMore: value.hasMore,
        sort: sort,               // always SortCriteria.numberAsc
      ),
    ...
  };
}

// after
Future<PokemonListState> _loadFirstPage() async {
  final result = await ref.read(getPokemonListProvider).call(...);
  return switch (result) {
    Ok(:final value) => PokemonListState(
        items: value.items,
        offset: value.items.length,
        hasMore: value.hasMore,
      ),
    ...
  };
}
```

Remove the `sort:` named arg from both `build()` call sites simultaneously.
Impact: −4 lines, cleaner API.

---

### 2. Null-clearing in `onDispose` is redundant

`lib/features/pokemon/presentation/view_models/pokemon_list_view_model.dart:42-47`

```dart
ref.onDispose(() {
  _debounce?.cancel();
  _debounce = null;      // <- never read after this point
  _streamSub?.cancel().ignore();
  _streamSub = null;     // <- never read after this point
});
```

`onDispose` fires on provider teardown. After teardown the notifier instance
is unreachable, so nulling the fields guards nothing — no code path can
subsequently call `_debounce?.cancel()` on a disposed notifier. The pattern
is a habit carried in from `StatefulWidget.dispose` where the widget tree can
still hold a stale reference. It does not apply here.

**Suggest** — remove the null assignments:

```dart
ref.onDispose(() {
  _debounce?.cancel();
  _streamSub?.cancel().ignore();
});
```

Impact: −2 lines.

---

### 3. `_toggleType` and `_toggleWeakness` are identical toggle logic on two different sets

`lib/features/pokemon/presentation/widgets/sheets/filters_sheet.dart:42-63`

```dart
void _toggleType(PokemonTypeId type) {
  setState(() {
    if (_types.contains(type)) { _types.remove(type); } else { _types.add(type); }
  });
}

void _toggleWeakness(PokemonTypeId type) {
  setState(() {
    if (_weaknesses.contains(type)) { _weaknesses.remove(type); } else { _weaknesses.add(type); }
  });
}
```

Both methods are structurally identical except for which `Set` they target.
A single helper that accepts the target set would remove 9 lines without any
abstraction overhead — the helper would still live inside the private
`_FiltersSheetState` class.

**Suggest**:

```dart
void _toggle(Set<PokemonTypeId> set, PokemonTypeId type) {
  setState(() => set.contains(type) ? set.remove(type) : set.add(type));
}
```

Call sites become `onToggle: (t) => _toggle(_types, t)` and
`onToggle: (t) => _toggle(_weaknesses, t)`. Impact: −9 lines.

---

### 4. `_FilterSection` is a 13-line private widget used exactly twice, both times inline in `_FiltersSheetState.build`

`lib/features/pokemon/presentation/widgets/sheets/filters_sheet.dart:130-147`

The widget wraps a `Column` with a title `Text` and a `SizedBox(height: 12)`.
It is used in two consecutive sibling positions in the same `build` method.
The only reason to extract it is reuse — and there are exactly two uses, both
side by side. Inlining the two occurrences directly inside the `Column` removes
the class without making the calling code harder to read.

This is a judgment call: if the project convention strongly favours extracting
every repeated structure into a widget class (the VGV style guide encourages
this for testability), leave it. But by pure YAGNI the abstraction earns
nothing here.

**Note** — if kept, no change needed. If inlined: −13 lines.

---

### 5. `_Handle` wrapper class in sheet tests is a single-field holder around a `Future`

`test/.../filters_sheet_test.dart:11-13`, `sort_sheet_test.dart:8-10`,
`generations_sheet_test.dart:7-9`

```dart
class _Handle {
  _Handle(this.result);
  final Future<PokemonFilter?> result;
}
```

This class exists solely to pass the `Future` from `_openSheet` back to the
test body. Because `_openSheet` already returns a `Future`, the `_Handle`
wrapper can be removed and `_openSheet` can return the `Future` directly.
The same pattern repeats identically across all three sheet test files (three
separate classes, three separate `_Handle(completer.future)` return calls).

**Suggest** — for all three files, drop `_Handle` and return the `Future`
directly from `_openSheet`:

```dart
// filters_sheet_test.dart — before
Future<_Handle> _openSheet(WidgetTester tester, {PokemonFilter? initial}) async {
  ...
  return _Handle(completer.future);
}
// usage: final handle = await _openSheet(tester); ... final result = await handle.result;

// after
Future<Future<PokemonFilter?>> _openSheet(WidgetTester tester, {PokemonFilter? initial}) async {
  ...
  return completer.future;
}
// usage: final resultFuture = await _openSheet(tester); ... final result = await resultFuture;
```

Alternatively, keep the `Completer` but return a record `(future: completer.future)`
or simply expose `completer` directly. Any of these removes the class.
Impact: −9 lines across three files (3 × 3-line class).

---

### 6. `_capitalize` helper in `filters_sheet_test.dart` is used only for `'fire'`

`test/.../filters_sheet_test.dart:50-51`

```dart
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
```

The function is called as `find.text(_capitalize('fire')).first` in two test
bodies. `_capitalize('fire')` evaluates to the string literal `'Fire'`. The
`PokemonTypeId.fire.name` approach would also work. Either way, the helper
function adds noise; inlining `'Fire'` directly removes it.

**Suggest** — replace `find.text(_capitalize('fire')).first` with
`find.text('Fire').first` and delete the function. Impact: −3 lines.

---

### 7. `_lastVisited` module-level map in `pokemon_card_test.dart` is an overcomplicated tap-spy

`test/.../pokemon_card_test.dart:48-52`

```dart
addTearDown(router.dispose);
_lastVisited[router] = () => lastVisited;
...
final Map<GoRouter, String? Function()> _lastVisited = {};
...
expect(_lastVisited[router]!(), '/pokemon/1');
```

The test needs to check what route was navigated to after a tap. A module-level
map keyed by the router instance is a roundabout way to expose a local
`String?` variable. Because `_pump` is always `await`-ed and the test only
ever creates one router at a time, a simpler approach is to return the
`lastVisited` variable reference directly via a record or a simple getter
closure without the map lookup.

The code works correctly, but the ceremony — a module-level mutable map, a
`() => lastVisited` lambda, and a `!()` double-dereference at the call site —
is out of proportion for "capture one route string".

**Suggest** — return a `({String? Function() lastVisited})` record from
`_pump` and drop the map:

```dart
Future<({String? Function() lastVisited})> _pump(
  WidgetTester tester,
  Pokemon pokemon,
) async {
  String? captured;
  final router = GoRouter(routes: [...
      builder: (context, state) {
        captured = state.uri.toString();
        ...
      }
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  addTearDown(router.dispose);
  return (lastVisited: () => captured);
}

// Usage:
final r = await _pump(tester, _bulbasaur);
...
expect(r.lastVisited(), '/pokemon/1');
```

Impact: −4 lines; removes the mutable module-level map.

---

### 8. `_ListHarness` class in `pokemon_list_screen_test.dart` is a thin holder with no methods

`test/.../pokemon_list_screen_test.dart:38-50`

```dart
class _ListHarness {
  _ListHarness({
    required this.getList,
    required this.findPokemon,
    required this.watch,
    required this.cacheController,
  });
  final _MockGetPokemonList getList;
  final _MockFindPokemon findPokemon;
  final _MockWatchPokemonList watch;
  final StreamController<List<Pokemon>> cacheController;
}
```

This is a data-only record (four fields, no methods). Dart 3 records or an
inline anonymous record type would serve the same purpose with less ceremony.
However, a plain record (`({...})`) cannot be used as a named parameter target
across file scope in older idioms. The harness class is used in four tests —
it has a real reuse role. Collapsing it into a record `({_MockGetPokemonList getList, ...})`
would be equivalent in size.

**Note** — not a strong simplification target; the class carries its weight.
If the project uses record types elsewhere for similar patterns, consider
aligning. Otherwise leave it.

---

### 9. `_openGenerations` callback in `pokemon_list_screen.dart` passes `state` but never reads it

`lib/features/pokemon/presentation/pages/pokemon_list_screen.dart:82-89`

```dart
Future<void> _openGenerations(PokemonListState state) async {
  final result = await showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => GenerationsSheet(initial: state.generationId),
  );
  if (!mounted) return;
  ref.read(pokemonListViewModelProvider.notifier).selectGeneration(result);
}
```

The `state` parameter is read once for `state.generationId`. `_openFilters`
and `_openSort` follow the same pattern (each takes `state` for one field).
This is consistent and necessary — state must be captured at the time the
button is tapped, not at the time the future resolves. No simplification.

**Note** — correct as-is; no action needed.

---

## YAGNI Violations

None found. Every method, class, and test serves a currently-required
behaviour. The `_composeFilter` private helper exists for the plan-mandated
AC and is covered by a dedicated test. The `isDiscovery` derived getter on
`PokemonListState` is a plan-ratified design decision. No extensibility hooks
were added beyond the plan's scope.

---

## Simplification Recommendations (prioritised)

| # | Location | Change | Impact |
|---|----------|--------|--------|
| 1 | `filters_sheet.dart:42-63` | Merge `_toggleType`/`_toggleWeakness` into one `_toggle(set, type)` | −9 lines |
| 2 | `*_sheet_test.dart` × 3 | Drop `_Handle` wrapper; return `Future` directly | −9 lines |
| 3 | `pokemon_list_view_model.dart:196-209` | Drop dead `sort` param from `_loadFirstPage` | −4 lines |
| 4 | `pokemon_card_test.dart:48-52` | Replace module-level `_lastVisited` map with record return | −4 lines |
| 5 | `pokemon_list_view_model.dart:44,46` | Remove null-assignments after `cancel()` in `onDispose` | −2 lines |
| 6 | `filters_sheet_test.dart:50-51,69,145` | Replace `_capitalize('fire')` with `'Fire'` literal | −3 lines |

Total potential LOC reduction: ~31 lines across production and test code.

---

## Final Assessment

**Total potential LOC reduction: ~5% of the PR's net new lines.**
Complexity score: **Low** — the code is well-structured and closely follows
the plan. No premature abstractions, no dead features, no over-engineered
helpers in the production path.

The ViewModel is the most complex piece and it earns every line: the
browse/discovery duality, the `AsyncLoading.copyWithPrevious` preservation,
the `_composeFilter` merge, and the debounce are all plan-mandated ACs, not
speculative additions.

The six findings above are all small and mechanical. Items 1–3 and 5–6 are
worth applying before merge. Item 4 (`_lastVisited` map) is a judgement
call — correct code, just a slightly odd idiom.

**Verdict: ready to merge with minor cleanup.**
