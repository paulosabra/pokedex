import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/observability/analytics_event.dart';

void main() {
  group('AnalyticsEvent', () {
    test('ListViewed maps origin + count', () {
      const event = ListViewed(origin: ListOrigin.warm, count: 24);
      expect(event.name, 'list_viewed');
      expect(event.parameters, {'origin': 'warm', 'count': 24});
    });

    test(
      'SearchPerformed exposes only result_count — never the term (RNF-09)',
      () {
        const event = SearchPerformed(resultCount: 7);
        expect(event.name, 'search_performed');
        expect(event.parameters, {'result_count': 7});
        // The raw query must never leak into analytics.
        expect(event.parameters.keys, isNot(contains('term')));
        expect(event.parameters.keys, isNot(contains('query')));
      },
    );

    test('FilterApplied maps presence flags only', () {
      const event = FilterApplied(
        hasType: true,
        hasWeakness: false,
        hasHeight: true,
      );
      expect(event.name, 'filter_applied');
      expect(event.parameters, {
        'has_type': true,
        'has_weakness': false,
        'has_height': true,
      });
    });

    test('SortChanged maps criteria', () {
      const event = SortChanged(criteria: 'numberAsc');
      expect(event.name, 'sort_changed');
      expect(event.parameters, {'criteria': 'numberAsc'});
    });

    test('GenerationSelected maps generation', () {
      const event = GenerationSelected(generation: 3);
      expect(event.name, 'generation_selected');
      expect(event.parameters, {'generation': 3});
    });

    test('PokemonOpened maps id + primary_type', () {
      const event = PokemonOpened(id: 25, primaryType: 'electric');
      expect(event.name, 'pokemon_opened');
      expect(event.parameters, {'id': 25, 'primary_type': 'electric'});
    });

    test('DetailTabChanged maps tab', () {
      const event = DetailTabChanged(tab: DetailTab.evolution);
      expect(event.name, 'detail_tab_changed');
      expect(event.parameters, {'tab': 'evolution'});
    });

    test('EvolutionNavigated maps source_id + dest_id', () {
      const event = EvolutionNavigated(sourceId: 133, destId: 134);
      expect(event.name, 'evolution_navigated');
      expect(event.parameters, {'source_id': 133, 'dest_id': 134});
    });

    test('ErrorShown maps te_code + screen', () {
      const event = ErrorShown(teCode: 'TE-01', screen: 'list');
      expect(event.name, 'error_shown');
      expect(event.parameters, {'te_code': 'TE-01', 'screen': 'list'});
    });

    test('all parameter values are non-null (Firebase/PostHog contract)', () {
      const events = <AnalyticsEvent>[
        ListViewed(origin: ListOrigin.cold, count: 0),
        SearchPerformed(resultCount: 0),
        FilterApplied(hasType: false, hasWeakness: false, hasHeight: false),
        SortChanged(criteria: 'numberAsc'),
        GenerationSelected(generation: 1),
        PokemonOpened(id: 1, primaryType: 'grass'),
        DetailTabChanged(tab: DetailTab.about),
        EvolutionNavigated(sourceId: 1, destId: 2),
        ErrorShown(teCode: 'TE-09', screen: 'detail'),
      ];
      for (final event in events) {
        expect(event.name, isNotEmpty);
        expect(event.parameters.values, everyElement(isNotNull));
      }
    });
  });
}
