import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/states/empty_generation_widget.dart';
import 'package:pokedex/core/ui/states/generic_error_widget.dart';
import 'package:pokedex/core/ui/states/offline_error_widget.dart';
import 'package:pokedex/core/ui/states/stale_cache_banner.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_list_view_model.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/pokemon_card.dart'
    as adapter;
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/filters_sheet.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/generations_sheet.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/sort_sheet.dart';

import '../../../../helpers/recording_observability.dart';

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

class _StubRepository extends Mock implements PokemonRepository {}

class _StubConnectivity extends Mock implements Connectivity {}

/// Catalogue-coverage providers (IndexCoordinator / BackfillCoordinator) ride
/// off the shared repository + connectivity, so a screen test needs both to be
/// stubbed even when the test only exercises the list ViewModel. These
/// defaults keep the kickoff coroutine a quiet no-op.
({_StubRepository repo, _StubConnectivity connectivity})
_catalogueCoverageStubs() {
  final repo = _StubRepository();
  final connectivity = _StubConnectivity();
  // Return a `ready` index so any sheet opened during the test (Filters,
  // Generations) renders its live components instead of the shimmer
  // placeholder — shimmer's infinite animation never settles, so
  // `pumpAndSettle` would otherwise hang the test indefinitely.
  when(repo.readIndexState).thenAnswer(
    (_) async => const IndexState(
      status: IndexStatus.ready,
      minId: 1,
      maxId: 1025,
      totalCount: 1025,
      generationIds: {1, 2, 3, 4, 5, 6, 7, 8, 9},
    ),
  );
  when(
    () => repo.listGenerationMembers(any()),
  ).thenAnswer((_) async => <int>[]);
  when(
    connectivity.checkConnectivity,
  ).thenAnswer((_) async => [ConnectivityResult.none]);
  when(() => connectivity.onConnectivityChanged).thenAnswer(
    (_) => const Stream<List<ConnectivityResult>>.empty(),
  );
  return (repo: repo, connectivity: connectivity);
}

Pokemon _pokemon(int id, {String name = 'pkmn'}) => Pokemon(
  id: id,
  name: name,
  imageUrl: 'https://img/$id.png',
  generationId: 1,
  types: const [PokemonTypeId.grass],
);

List<Pokemon> _page(int start, int count) => [
  for (var i = 0; i < count; i++) _pokemon(start + i),
];

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

_ListHarness _makeHarness({
  List<Pokemon>? firstPage,
  bool hasMore = true,
}) {
  final harness = _ListHarness(
    getList: _MockGetPokemonList(),
    findPokemon: _MockFindPokemon(),
    watch: _MockWatchPokemonList(),
    cacheController: StreamController<List<Pokemon>>.broadcast(),
  );
  when(
    () => harness.getList.call(
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer(
    (_) async =>
        Ok(PokemonPage(items: firstPage ?? _page(1, 24), hasMore: hasMore)),
  );
  when(
    () => harness.watch.call(
      sort: any(named: 'sort'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) => harness.cacheController.stream);
  when(
    () => harness.findPokemon.call(
      sort: any(named: 'sort'),
      query: any(named: 'query'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) async => Ok(_page(100, 3)));
  return harness;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _ListHarness harness,
  RecordingAnalytics? analytics,
  Size size = const Size(420, 1000),
}) async {
  // Pin devicePixelRatio so the surface size translates 1:1 to logical pixels.
  // Otherwise the default test DPR (3.0) shrinks `MediaQuery.sizeOf(context)`
  // to ~140 logical px, which constrains the PokemonCard layout below its
  // intrinsic minimum width.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(harness.cacheController.close);
  final coverage = _catalogueCoverageStubs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        getPokemonListProvider.overrideWithValue(harness.getList),
        findPokemonProvider.overrideWithValue(harness.findPokemon),
        watchPokemonListProvider.overrideWithValue(harness.watch),
        pokemonRepositoryProvider.overrideWithValue(coverage.repo),
        connectivityProvider.overrideWithValue(coverage.connectivity),
        if (analytics != null)
          analyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: const MaterialApp(home: PokemonListScreen()),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
    registerFallbackValue(const PokemonFilter());
  });

  group('PokemonListScreen', () {
    testWidgets('shows the skeleton while the first page is loading', (
      tester,
    ) async {
      final completer = Completer<Result<PokemonPage>>();
      final harness = _makeHarness();
      when(
        () => harness.getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      await _pumpScreen(tester, harness: harness);
      // First frame after pumpWidget — still loading.
      expect(find.byType(adapter.PokemonCard), findsNothing);
      expect(find.byType(ListView), findsOneWidget);

      completer.complete(const Ok(PokemonPage(hasMore: false)));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cards from state after build completes', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: _page(1, 6), hasMore: false);
      // ListView lazily renders only viewport-visible cards. Use a tall
      // surface so all six materialize without scrolling.
      await _pumpScreen(
        tester,
        harness: harness,
        size: const Size(420, 1600),
      );
      await tester.pumpAndSettle();

      expect(find.byType(adapter.PokemonCard), findsNWidgets(6));
    });

    testWidgets('deep-link smoke: PokemonListScreen mounts at /', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: const [], hasMore: false);
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      expect(find.byType(PokemonListScreen), findsOneWidget);
    });

    testWidgets('empty state shows TE-04 message when query is set', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: _page(1, 3));
      when(
        () => harness.findPokemon.call(
          sort: any(named: 'sort'),
          query: any(named: 'query'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => const Ok(<Pokemon>[]));

      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzz');
      // Past the 300 ms debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // The empty-search body embeds the query verbatim — we assert on the
      // quoted substring rather than the full sentence so copy tweaks past
      // the query token don't force a regression chase.
      expect(find.textContaining('"zzzz"'), findsOneWidget);
    });

    testWidgets(
      'empty state shows TE-05 message when a filter is set but no query '
      '(resolved test-quality B1)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 3));
        when(
          () => harness.findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Ok(<Pokemon>[]));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        // Apply a filter without entering a query so the empty branch hits
        // the filter-only message instead of the query message.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PokemonListScreen)),
        );
        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No Pokémon match the current filters.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'stream emission preserves scroll position (resolved blocker 3)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 40));
        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        final scrollable = tester.widget<ListView>(find.byType(ListView));
        final controller = scrollable.controller;
        expect(controller, isNotNull);

        controller!.jumpTo(400);
        await tester.pumpAndSettle();
        final pixelsBefore = controller.position.pixels;

        // Emit a fresh cache snapshot with 1 extra item.
        harness.cacheController.add(_page(0, 41));
        await tester.pumpAndSettle();

        // Position should not have jumped.
        expect(controller.position.pixels, closeTo(pixelsBefore, 1));
      },
    );

    testWidgets(
      'pure NetworkFailure with no cache renders OfflineErrorWidget (TE-01)',
      (tester) async {
        final harness = _makeHarness();
        when(
          () => harness.getList.call(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        await _pumpScreen(tester, harness: harness);
        // Pump twice: pumpAndSettle in tests may leave Riverpod in the
        // `AsyncLoading.copyWithPrevious(AsyncError)` micro-state.
        await tester.pumpAndSettle();
        await tester.pump();

        expect(find.byType(OfflineErrorWidget), findsOneWidget);
      },
    );

    testWidgets(
      'pure ServerFailure with no cache renders GenericErrorWidget '
      '(TE-03/06/07/09)',
      (tester) async {
        final harness = _makeHarness();
        when(
          () => harness.getList.call(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Err(ServerFailure()));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        expect(find.byType(GenericErrorWidget), findsOneWidget);
      },
    );

    testWidgets(
      'generation set AND active type filter with no items shows '
      'EmptyFilterWidget (not the generation variant)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 3));
        when(
          () => harness.findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Ok(<Pokemon>[]));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        // Combine: a generation AND a type filter active → not a backfill
        // case, render EmptyFilterWidget instead of EmptyGenerationWidget.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PokemonListScreen)),
        );
        container
            .read(pokemonListViewModelProvider.notifier)
            .selectGeneration(1);
        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No Pokémon match the current filters.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'generation set with no items shows EmptyGenerationWidget (RN-15)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 3));
        when(
          () => harness.findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Ok(<Pokemon>[]));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(PokemonListScreen)),
        );
        container
            .read(pokemonListViewModelProvider.notifier)
            .selectGeneration(2);
        await tester.pumpAndSettle();

        expect(find.byType(EmptyGenerationWidget), findsOneWidget);
      },
    );

    testWidgets(
      'short list (maxScrollExtent==0) does not trigger spurious loadMore '
      '(resolved review-100 #4)',
      (tester) async {
        // First page has 3 items with hasMore=true so loadMore would fire
        // if the scroll guard let it through.
        final harness = _makeHarness(firstPage: _page(1, 3));
        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        // The initial build fetches page-0 exactly once. If _onScroll
        // misfires on the short list (maxScrollExtent==0), a second call
        // for offset=24 would be issued.
        verify(
          () => harness.getList.call(limit: 24, offset: 0),
        ).called(1);
        verifyNever(
          () => harness.getList.call(limit: 24, offset: 24),
        );
      },
    );

    testWidgets(
      'failed refresh over a populated cache shows the StaleCacheBanner '
      '(TE-02)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 3));
        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();
        expect(find.byType(adapter.PokemonCard), findsWidgets);

        // Switch the next getPokemonList call to fail so the refresh surfaces
        // a banner over the still-rendered cache.
        when(
          () => harness.getList.call(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(PokemonListScreen)),
        );
        await container.read(pokemonListViewModelProvider.notifier).refresh();
        await tester.pumpAndSettle();

        expect(find.byType(StaleCacheBanner), findsOneWidget);
        // Cards stay visible alongside the banner.
        expect(find.byType(adapter.PokemonCard), findsWidgets);
      },
    );
  });

  group('PokemonListScreen — error_shown analytics (T-30b §4.3)', () {
    testWidgets('offline error widget emits error_shown TE-01', (tester) async {
      final harness = _makeHarness();
      when(
        () => harness.getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final analytics = RecordingAnalytics();

      await _pumpScreen(tester, harness: harness, analytics: analytics);
      await tester.pumpAndSettle();
      await tester.pump();

      final shown = analytics.named('error_shown');
      expect(shown, hasLength(1));
      expect(shown.single.parameters, {
        'te_code': 'TE-01',
        'screen': 'pokemon_list',
      });
    });

    testWidgets('generic error widget emits error_shown TE-07', (tester) async {
      final harness = _makeHarness();
      when(
        () => harness.getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Err(ServerFailure()));
      final analytics = RecordingAnalytics();

      await _pumpScreen(tester, harness: harness, analytics: analytics);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(analytics.named('error_shown').single.parameters, {
        'te_code': 'TE-07',
        'screen': 'pokemon_list',
      });
    });

    testWidgets('stale-cache banner emits error_shown TE-02', (tester) async {
      final harness = _makeHarness(firstPage: _page(1, 3));
      final analytics = RecordingAnalytics();
      await _pumpScreen(tester, harness: harness, analytics: analytics);
      await tester.pumpAndSettle();

      when(
        () => harness.getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PokemonListScreen)),
      );
      await container.read(pokemonListViewModelProvider.notifier).refresh();
      await tester.pumpAndSettle();

      final shown = analytics.named('error_shown');
      expect(shown, hasLength(1));
      expect(shown.single.parameters, {
        'te_code': 'TE-02',
        'screen': 'pokemon_list',
      });
    });
  });

  // Closes the "screen-level wiring from icon buttons to sheet openers is
  // entirely uncovered" gap from the PR2 test-quality review. Each test taps
  // the tooltip-keyed icon, settles the showModalBottomSheet animation, and
  // asserts the corresponding sheet is in the tree.
  group('PokemonListScreen — sheet openers', () {
    testWidgets('tapping the Filters icon opens FiltersSheet', (tester) async {
      final harness = _makeHarness(firstPage: _page(1, 3));
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filters'));
      // `pumpAndSettle` hangs here under FiltersSheet (`SortSheet` and
      // `GenerationsSheet` settle fine — see the tests below). Two manual
      // frames are enough to mount the modal route, which is all this
      // smoke needs.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FiltersSheet), findsOneWidget);
    });

    testWidgets('tapping the Sort icon opens SortSheet', (tester) async {
      final harness = _makeHarness(firstPage: _page(1, 3));
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();

      expect(find.byType(SortSheet), findsOneWidget);
    });

    testWidgets('tapping the Generations icon opens GenerationsSheet', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: _page(1, 3));
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Generations'));
      await tester.pumpAndSettle();

      expect(find.byType(GenerationsSheet), findsOneWidget);
    });

    testWidgets(
      'selecting a sort option dispatches changeSort to the ViewModel',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 3));
        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Sort'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Z-A'));
        await tester.pumpAndSettle();

        // The Sort dispatch flips to discovery, which routes through
        // findPokemon. The VM-level test covers the state change; this one
        // proves the screen wired the sheet result into the intent.
        verify(
          () => harness.findPokemon.call(
            sort: SortCriteria.nameDesc,
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).called(1);
      },
    );
  });
}
