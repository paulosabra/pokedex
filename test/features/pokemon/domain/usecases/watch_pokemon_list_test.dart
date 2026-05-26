import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';

class _MockRepository extends Mock implements PokemonRepository {}

const _bulbasaur = Pokemon(
  id: 1,
  name: 'bulbasaur',
  imageUrl: 'https://img/1.png',
  generationId: 1,
  types: [PokemonTypeId.grass, PokemonTypeId.poison],
);

const _ivysaur = Pokemon(
  id: 2,
  name: 'ivysaur',
  imageUrl: 'https://img/2.png',
  generationId: 1,
  types: [PokemonTypeId.grass, PokemonTypeId.poison],
);

void main() {
  late _MockRepository repository;
  late WatchPokemonList useCase;

  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
  });

  setUp(() {
    repository = _MockRepository();
    useCase = WatchPokemonList(repository);
  });

  group('WatchPokemonList', () {
    test('propagates the initial emission from the repository', () async {
      when(
        () => repository.watchCachedSummaries(
          sort: any(named: 'sort'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => Stream.value(const [_bulbasaur]));

      final first = await useCase(sort: SortCriteria.numberAsc).first;

      expect(first, [_bulbasaur]);
      verify(
        () => repository.watchCachedSummaries(sort: SortCriteria.numberAsc),
      ).called(1);
    });

    test('propagates subsequent emissions in order', () async {
      when(
        () => repository.watchCachedSummaries(
          sort: any(named: 'sort'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable(const [
          [_bulbasaur],
          [_bulbasaur, _ivysaur],
        ]),
      );

      final emitted = await useCase(sort: SortCriteria.numberAsc).toList();

      expect(emitted, [
        [_bulbasaur],
        [_bulbasaur, _ivysaur],
      ]);
    });

    test('forwards filter alongside sort verbatim', () async {
      const filter = PokemonFilter(types: {PokemonTypeId.grass});
      when(
        () => repository.watchCachedSummaries(
          sort: any(named: 'sort'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      await useCase(sort: SortCriteria.nameAsc, filter: filter).drain<void>();

      verify(
        () => repository.watchCachedSummaries(
          sort: SortCriteria.nameAsc,
          filter: filter,
        ),
      ).called(1);
    });

    test(
      'static return type is Stream<List<Pokemon>>, not Stream<Result<...>>',
      () {
        when(
          () => repository.watchCachedSummaries(
            sort: any(named: 'sort'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        // The variable's static type is the load-bearing assertion: if the
        // use case ever drifts to Stream<Result<List<Pokemon>>>, this file
        // refuses to compile. The runtime expect is a sanity check.
        // ignore: omit_local_variable_types
        final Stream<List<Pokemon>> stream = useCase(
          sort: SortCriteria.numberAsc,
        );

        expect(stream, isNotNull);
      },
    );
  });
}
