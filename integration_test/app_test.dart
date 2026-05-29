import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pokedex/app/app.dart';
import 'package:pokedex/app/router/app_router.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/about_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/pokemon_card.dart'
    as adapter;

import 'helpers/e2e_harness.dart';

/// Top-of-the-pyramid E2E flows (T-29). These drive the real provider graph on
/// in-memory I/O (see [E2EHarness]); the deep-link error path (`/pokemon/abc`
/// → TE-03) lands in T-31 alongside the `tryParse` + `errorBuilder` fix it
/// verifies.
///
/// Run on the host VM with `flutter test integration_test/app_test.dart`, or on
/// headless Chrome in CI with `flutter drive`. Deterministic by construction —
/// in-memory Drift, a fake PokéAPI, and a stubbed backfill mean no real I/O —
/// so each flow settles in a few seconds (dominated on web only by the one-time
/// `sqlite3.wasm` load).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The first id of page 1 and the last id of page 2 — used as stable, layout-
  // independent finders via the card's `#NNN` dex number.
  Finder cardNumber(int id) => find.text('#${id.toString().padLeft(3, '0')}');

  testWidgets('UC-02/06: search surfaces a match and opens its detail', (
    tester,
  ) async {
    await E2EHarness().pumpApp(tester);

    // The first page rendered as real cards (not skeletons/loading). Two
    // distinct top-of-list ids confirm a real page loaded; we don't assert all
    // 24 because the ListView only builds viewport-visible cards.
    expect(find.byType(adapter.PokemonCard), findsWidgets);
    expect(cardNumber(1), findsOneWidget);
    expect(cardNumber(2), findsOneWidget);

    // Search for a page-1 (already-hydrated) Pokémon by name.
    await tester.enterText(find.byType(TextField), 'bulba');
    // Clear the 300ms search debounce, then settle the discovery query.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Only the match remains in the list.
    expect(cardNumber(1), findsOneWidget);
    expect(cardNumber(2), findsNothing);

    // Open it and confirm the detail screen mounts with loaded content.
    await tester.tap(find.byType(adapter.PokemonCard).first);
    await tester.pumpAndSettle();

    final detail = tester.widget<PokemonDetailScreen>(
      find.byType(PokemonDetailScreen),
    );
    expect(detail.id, 1);
    // AboutTab only renders in the loaded state — proves the cache-first
    // compose succeeded (not an error/loading placeholder).
    expect(find.byType(AboutTab), findsOneWidget);
  });

  testWidgets('UC-01: scrolling to the end loads the next page', (
    tester,
  ) async {
    await E2EHarness().pumpApp(tester);

    expect(cardNumber(1), findsOneWidget);
    // Page 2's last id is not in the tree until pagination runs.
    expect(cardNumber(48), findsNothing);

    // Scroll to the bottom; reaching the end of page 1 fires `loadMore`, and
    // continued scrolling brings page 2's tail into view. Enough drags to clear
    // both pages' extent (~48 cards) at this surface size.
    const maxScrollSteps = 12;
    final list = find.byKey(const PageStorageKey<String>('pokemon-list'));
    for (var step = 0; step < maxScrollSteps; step++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }

    // The last id of page 2 is reachable → the next page was fetched.
    expect(cardNumber(48), findsOneWidget);
  });

  // C-1 (T-31): once the SPA rewrite serves index.html for every path, a
  // malformed or unknown deep link is reachable in-app. Both must render the
  // TE-03 page (RouteErrorScreen) rather than crashing. Driven through the real
  // router from `routerProvider`, colocated with the fix it verifies.
  testWidgets('C-1: malformed and unmatched deep links render TE-03', (
    tester,
  ) async {
    await E2EHarness().pumpApp(tester);

    // Non-numeric id → int.tryParse returns null → TE-03 (deterministic on web,
    // unlike an int64-overflow id whose web parse is lossy).
    final router = ProviderScope.containerOf(
      tester.element(find.byType(PokedexApp)),
    ).read(routerProvider)..go('/pokemon/abc');
    await tester.pumpAndSettle();
    expect(find.text("This page doesn't exist."), findsOneWidget);

    // Any unmatched path → GoRouter errorBuilder → the same TE-03 page.
    router.go('/no-such-route');
    await tester.pumpAndSettle();
    expect(find.text("This page doesn't exist."), findsOneWidget);

    // The "Go home" CTA recovers to the list.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Go home'));
    await tester.pumpAndSettle();
    expect(find.byType(adapter.PokemonCard), findsWidgets);
  });
}
