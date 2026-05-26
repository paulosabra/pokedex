import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';

class _MockRepository extends Mock implements PokemonRepository {}

class _FakeChain extends Fake implements EvolutionChain {}

void main() {
  late _MockRepository repository;
  late GetEvolutionChain useCase;

  setUp(() {
    repository = _MockRepository();
    useCase = GetEvolutionChain(repository);
  });

  group('GetEvolutionChain', () {
    test('forwards the id and returns the Ok chain verbatim', () async {
      final chain = _FakeChain();
      when(
        () => repository.getEvolutionChain(any()),
      ).thenAnswer((_) async => Ok(chain));

      final result = await useCase(1);

      expect((result as Ok<EvolutionChain>).value, same(chain));
      verify(() => repository.getEvolutionChain(1)).called(1);
    });

    test('propagates an Err from the repository unchanged', () async {
      when(
        () => repository.getEvolutionChain(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      final result = await useCase(1);

      expect((result as Err<EvolutionChain>).failure, isA<NetworkFailure>());
    });
  });
}
