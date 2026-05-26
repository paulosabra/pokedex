import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';

class _MockRepository extends Mock implements PokemonRepository {}

void main() {
  late _MockRepository repository;
  late FindPokemon useCase;

  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
  });

  setUp(() {
    repository = _MockRepository();
    useCase = FindPokemon(repository);
  });

  group('FindPokemon', () {
    test(
      'forwards (query, filter, sort) verbatim and returns Ok unchanged',
      () async {
        const matches = <Pokemon>[
          Pokemon(
            id: 1,
            name: 'bulbasaur',
            imageUrl: 'https://img/1.png',
            generationId: 1,
            types: [PokemonTypeId.grass, PokemonTypeId.poison],
          ),
        ];
        const filter = PokemonFilter(types: {PokemonTypeId.grass});
        when(
          () => repository.findPokemon(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Ok(matches));

        final result = await useCase(
          sort: SortCriteria.numberAsc,
          query: 'bulba',
          filter: filter,
        );

        expect((result as Ok<List<Pokemon>>).value, same(matches));
        verify(
          () => repository.findPokemon(
            sort: SortCriteria.numberAsc,
            query: 'bulba',
            filter: filter,
          ),
        ).called(1);
      },
    );

    test('forwards a filter combining generationId with types', () async {
      const matches = <Pokemon>[
        Pokemon(
          id: 152,
          name: 'chikorita',
          imageUrl: 'https://img/152.png',
          generationId: 2,
          types: [PokemonTypeId.grass],
        ),
      ];
      const filter = PokemonFilter(
        types: {PokemonTypeId.grass},
        generationId: 2,
      );
      when(
        () => repository.findPokemon(
          sort: any(named: 'sort'),
          query: any(named: 'query'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => const Ok(matches));

      final result = await useCase(
        sort: SortCriteria.numberAsc,
        filter: filter,
      );

      expect((result as Ok<List<Pokemon>>).value, same(matches));
      // mocktail's verify treats an omitted named arg as "matches the
      // default value" — here, `query: null`. No wildcard semantics.
      verify(
        () => repository.findPokemon(
          sort: SortCriteria.numberAsc,
          filter: filter,
        ),
      ).called(1);
    });

    test('propagates an Err from the repository unchanged', () async {
      when(
        () => repository.findPokemon(
          sort: any(named: 'sort'),
          query: any(named: 'query'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => const Err(CacheFailure()));

      final result = await useCase(sort: SortCriteria.numberAsc);

      expect((result as Err<List<Pokemon>>).failure, isA<CacheFailure>());
    });
  });
}
