import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';

class _MockRepository extends Mock implements PokemonRepository {}

void main() {
  late _MockRepository repository;
  late GetPokemonList useCase;

  setUp(() {
    repository = _MockRepository();
    useCase = GetPokemonList(repository);
  });

  group('GetPokemonList', () {
    test('forwards limit + offset and returns the Ok page verbatim', () async {
      const page = PokemonPage(hasMore: true);
      when(
        () => repository.getPokemonList(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Ok(page));

      final result = await useCase(limit: 20, offset: 40);

      expect(result, isA<Ok<PokemonPage>>());
      expect((result as Ok<PokemonPage>).value, same(page));
      verify(() => repository.getPokemonList(limit: 20, offset: 40)).called(1);
    });

    test('propagates an Err from the repository unchanged', () async {
      when(
        () => repository.getPokemonList(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      final result = await useCase(limit: 20, offset: 0);

      expect((result as Err<PokemonPage>).failure, isA<NetworkFailure>());
    });
  });
}
