import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';

class _MockRepository extends Mock implements PokemonRepository {}

class _FakeDetail extends Fake implements PokemonDetail {}

void main() {
  late _MockRepository repository;
  late GetPokemonDetail useCase;

  setUp(() {
    repository = _MockRepository();
    useCase = GetPokemonDetail(repository);
  });

  group('GetPokemonDetail', () {
    test('forwards the id and returns the Ok detail verbatim', () async {
      final detail = _FakeDetail();
      when(
        () => repository.getPokemonDetail(any()),
      ).thenAnswer((_) async => Ok(detail));

      final result = await useCase(25);

      expect((result as Ok<PokemonDetail>).value, same(detail));
      verify(() => repository.getPokemonDetail(25)).called(1);
    });

    test('propagates an Err from the repository unchanged', () async {
      when(
        () => repository.getPokemonDetail(any()),
      ).thenAnswer((_) async => const Err(NotFoundFailure()));

      final result = await useCase(9999);

      expect((result as Err<PokemonDetail>).failure, isA<NotFoundFailure>());
    });
  });
}
