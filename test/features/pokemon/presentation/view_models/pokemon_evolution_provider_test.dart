import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_evolution_provider.dart';

import '../fixtures/eevee_evolution_chain.dart';

class _MockGetEvolutionChain extends Mock implements GetEvolutionChain {}

void main() {
  late _MockGetEvolutionChain getChain;
  late ProviderContainer container;

  setUp(() {
    getChain = _MockGetEvolutionChain();
    container = ProviderContainer(
      overrides: [getEvolutionChainProvider.overrideWithValue(getChain)],
    );
  });

  tearDown(() => container.dispose());

  group('pokemonEvolutionProvider', () {
    test('returns the chain on Ok', () async {
      final eevee = eeveeEvolutionChain();
      when(() => getChain.call(133)).thenAnswer((_) async => Ok(eevee));

      container.listen(pokemonEvolutionProvider(133), (_, _) {});
      final result = await container.read(
        pokemonEvolutionProvider(133).future,
      );

      expect(result, same(eevee));
      expect(result.root.evolvesTo.length, 8);
    });

    test('returns a single-stage chain for no-evolution Pokémon', () async {
      final tauros = singleStageChain();
      when(() => getChain.call(128)).thenAnswer((_) async => Ok(tauros));

      container.listen(pokemonEvolutionProvider(128), (_, _) {});
      final result = await container.read(
        pokemonEvolutionProvider(128).future,
      );

      expect(result.root.evolvesTo, isEmpty);
    });

    test('surfaces AsyncError on Err', () async {
      when(
        () => getChain.call(1),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      container.listen(pokemonEvolutionProvider(1), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final async = container.read(pokemonEvolutionProvider(1));
      expect(async.hasError, isTrue);
      expect(async.error, isA<NetworkFailure>());
    });

    test('family keying: id 1 and id 133 are independent', () async {
      when(
        () => getChain.call(1),
      ).thenAnswer((_) async => Ok(bulbasaurEvolutionChain()));
      when(
        () => getChain.call(133),
      ).thenAnswer((_) async => Ok(eeveeEvolutionChain()));

      container
        ..listen(pokemonEvolutionProvider(1), (_, _) {})
        ..listen(pokemonEvolutionProvider(133), (_, _) {});

      final results = await Future.wait([
        container.read(pokemonEvolutionProvider(1).future),
        container.read(pokemonEvolutionProvider(133).future),
      ]);

      expect(results[0].root.stage.id, 1);
      expect(results[1].root.stage.id, 133);
    });
  });
}
