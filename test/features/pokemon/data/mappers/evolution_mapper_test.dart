import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/evolution_mapper.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('evolutionChainFromDto', () {
    test('maps a linear chain with conditions (Bulbasaur line, RN-13)', () {
      final chain = evolutionChainFromDto(
        EvolutionChainDto.fromJson(
          fixtureJson('evolution_chain_bulbasaur.json'),
        ),
      );

      expect(chain.root.stage.name, 'bulbasaur');
      expect(chain.root.stage.condition, isNull);
      expect(chain.root.stage.imageUrl, contains('official-artwork/1.png'));

      final ivysaur = chain.root.evolvesTo.single;
      expect(ivysaur.stage.name, 'ivysaur');
      expect(ivysaur.stage.condition, 'Level 16');

      final venusaur = ivysaur.evolvesTo.single;
      expect(venusaur.stage.name, 'venusaur');
      expect(venusaur.stage.condition, 'Level 32');
      expect(venusaur.evolvesTo, isEmpty);
    });

    test('maps a branching chain (Eevee → 8 nodes, RN-13)', () {
      final chain = evolutionChainFromDto(
        EvolutionChainDto.fromJson(fixtureJson('evolution_chain_eevee.json')),
      );

      expect(chain.root.stage.name, 'eevee');
      expect(chain.root.evolvesTo, hasLength(8));

      final vaporeon = chain.root.evolvesTo.firstWhere(
        (node) => node.stage.name == 'vaporeon',
      );
      expect(vaporeon.stage.condition, 'Use water stone');
    });

    test('derives held-item and known-move conditions', () {
      // Level-up triggers (not trade) so the held-item / known-move branches
      // are reached rather than short-circuited by the "Trade" trigger.
      const dto = EvolutionChainDto(
        id: 1,
        chain: ChainLinkDto(
          species: NamedApiResourceDto(
            url: 'https://pokeapi.co/api/v2/evolution-chain/1/',
            name: 'base',
          ),
          evolvesTo: [
            ChainLinkDto(
              species: NamedApiResourceDto(url: '/2/', name: 'gliscor'),
              evolutionDetails: [
                EvolutionDetailDto(
                  trigger: NamedApiResourceDto(url: '', name: 'level-up'),
                  heldItem: NamedApiResourceDto(url: '', name: 'razor-fang'),
                ),
              ],
            ),
            ChainLinkDto(
              species: NamedApiResourceDto(url: '/3/', name: 'sylveon'),
              evolutionDetails: [
                EvolutionDetailDto(
                  trigger: NamedApiResourceDto(url: '', name: 'level-up'),
                  knownMove: NamedApiResourceDto(url: '', name: 'fairy-wind'),
                ),
              ],
            ),
          ],
        ),
      );

      final chain = evolutionChainFromDto(dto);
      final byName = {
        for (final node in chain.root.evolvesTo) node.stage.name: node,
      };

      expect(byName['gliscor']!.stage.condition, 'Hold razor fang');
      expect(byName['sylveon']!.stage.condition, 'Knows fairy wind');
    });

    test('derives happiness, time-of-day and location conditions', () {
      const dto = EvolutionChainDto(
        id: 1,
        chain: ChainLinkDto(
          species: NamedApiResourceDto(url: '/1/', name: 'base'),
          evolvesTo: [
            ChainLinkDto(
              species: NamedApiResourceDto(url: '/2/', name: 'espeon'),
              evolutionDetails: [
                EvolutionDetailDto(
                  trigger: NamedApiResourceDto(url: '', name: 'level-up'),
                  minHappiness: 220,
                ),
              ],
            ),
            ChainLinkDto(
              species: NamedApiResourceDto(url: '/3/', name: 'umbreon'),
              evolutionDetails: [
                EvolutionDetailDto(
                  trigger: NamedApiResourceDto(url: '', name: 'level-up'),
                  timeOfDay: 'night',
                ),
              ],
            ),
            ChainLinkDto(
              species: NamedApiResourceDto(url: '/4/', name: 'leafeon'),
              evolutionDetails: [
                EvolutionDetailDto(
                  trigger: NamedApiResourceDto(url: '', name: 'level-up'),
                  location: NamedApiResourceDto(url: '', name: 'mossy-rock'),
                ),
              ],
            ),
          ],
        ),
      );

      final byName = {
        for (final node in evolutionChainFromDto(dto).root.evolvesTo)
          node.stage.name: node,
      };

      expect(byName['espeon']!.stage.condition, 'High friendship');
      expect(byName['umbreon']!.stage.condition, 'During night');
      expect(byName['leafeon']!.stage.condition, 'At mossy rock');
    });
  });
}
