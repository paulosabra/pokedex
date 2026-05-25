import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('EvolutionChainDto.fromJson', () {
    test('parses a linear chain (Bulbasaur → Ivysaur → Venusaur)', () {
      final chain = EvolutionChainDto.fromJson(
        fixtureJson('evolution_chain_bulbasaur.json'),
      );

      expect(chain.chain.species.name, 'bulbasaur');
      expect(chain.chain.isBaby, isFalse);

      final ivysaur = chain.chain.evolvesTo.single;
      expect(ivysaur.species.name, 'ivysaur');

      final venusaur = ivysaur.evolvesTo.single;
      expect(venusaur.species.name, 'venusaur');
      expect(venusaur.evolvesTo, isEmpty);

      // Evolution conditions are present on the recursive nodes.
      expect(ivysaur.evolutionDetails.single.minLevel, 16);
    });

    test('parses a branching chain (Eevee → 8 evolutions)', () {
      final chain = EvolutionChainDto.fromJson(
        fixtureJson('evolution_chain_eevee.json'),
      );

      expect(chain.chain.species.name, 'eevee');
      expect(chain.chain.evolvesTo, hasLength(8));
      expect(
        chain.chain.evolvesTo.map((node) => node.species.name),
        contains('vaporeon'),
      );
    });
  });
}
