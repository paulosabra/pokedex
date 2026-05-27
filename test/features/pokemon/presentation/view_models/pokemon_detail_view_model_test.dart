import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_detail_view_model.dart';

import '../fixtures/pokemon_detail_builder.dart';

class _MockGetPokemonDetail extends Mock implements GetPokemonDetail {}

void main() {
  late _MockGetPokemonDetail getDetail;
  late ProviderContainer container;

  setUp(() {
    getDetail = _MockGetPokemonDetail();
    container = ProviderContainer(
      overrides: [getPokemonDetailProvider.overrideWithValue(getDetail)],
    );
  });

  tearDown(() => container.dispose());

  group('PokemonDetailViewModel — build', () {
    test('returns the detail on Ok', () async {
      final detail = bulbasaurDetail();
      when(() => getDetail.call(1)).thenAnswer((_) async => Ok(detail));

      container.listen(pokemonDetailViewModelProvider(1), (_, _) {});
      final result = await container.read(
        pokemonDetailViewModelProvider(1).future,
      );

      expect(result, same(detail));
      verify(() => getDetail.call(1)).called(1);
    });

    test('surfaces AsyncError on Err', () async {
      when(
        () => getDetail.call(1),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      container.listen(pokemonDetailViewModelProvider(1), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final async = container.read(pokemonDetailViewModelProvider(1));
      expect(async.hasError, isTrue);
      expect(async.error, isA<NetworkFailure>());
    });
  });

  group('PokemonDetailViewModel — family keying', () {
    test('vm(1) and vm(4) hold independent state', () async {
      final bulba = bulbasaurDetail();
      final charmander = bulba.copyWith(
        summary: bulba.summary.copyWith(id: 4, name: 'charmander'),
      );

      when(() => getDetail.call(1)).thenAnswer((_) async => Ok(bulba));
      when(() => getDetail.call(4)).thenAnswer((_) async => Ok(charmander));

      container
        ..listen(pokemonDetailViewModelProvider(1), (_, _) {})
        ..listen(pokemonDetailViewModelProvider(4), (_, _) {});

      final results = await Future.wait([
        container.read(pokemonDetailViewModelProvider(1).future),
        container.read(pokemonDetailViewModelProvider(4).future),
      ]);

      expect(results[0].summary.id, 1);
      expect(results[1].summary.id, 4);
      verify(() => getDetail.call(1)).called(1);
      verify(() => getDetail.call(4)).called(1);

      // The two providers must not share state — switching one leaves the
      // other untouched.
      final stillOne = container.read(pokemonDetailViewModelProvider(1));
      expect(stillOne.value, isA<PokemonDetail>());
      expect(stillOne.value!.summary.id, 1);
    });
  });
}
