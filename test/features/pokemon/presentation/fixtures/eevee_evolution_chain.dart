import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';

/// Hand-crafted Eevee evolution tree — the canonical branching case.
///
/// Eevee (#133) has eight known evolutions in canon; this fixture pins the
/// shape of [EvolutionNode.evolvesTo] for the `evolution_tab` recursive
/// rendering test (resolved blocker 5). Uses the same `imageUrl` for every
/// stage to keep the fixture minimal — widget tests assert structure, not
/// pixels.
const String _placeholderImage = 'https://img.test/eevee.png';

EvolutionStage _stage(int id, String name, {String? condition}) =>
    EvolutionStage(
      id: id,
      name: name,
      imageUrl: _placeholderImage,
      condition: condition,
    );

EvolutionNode _leaf(int id, String name, {required String condition}) =>
    EvolutionNode(stage: _stage(id, name, condition: condition));

/// Eevee's recursive 8-branch evolution chain.
EvolutionChain eeveeEvolutionChain() => EvolutionChain(
  root: EvolutionNode(
    stage: _stage(133, 'eevee'),
    evolvesTo: [
      _leaf(134, 'vaporeon', condition: 'Use Water Stone'),
      _leaf(135, 'jolteon', condition: 'Use Thunder Stone'),
      _leaf(136, 'flareon', condition: 'Use Fire Stone'),
      _leaf(196, 'espeon', condition: 'Level up with high friendship at day'),
      _leaf(
        197,
        'umbreon',
        condition: 'Level up with high friendship at night',
      ),
      _leaf(470, 'leafeon', condition: 'Level near Moss Rock'),
      _leaf(471, 'glaceon', condition: 'Level near Ice Rock'),
      _leaf(700, 'sylveon', condition: 'Level up with Fairy move + affection'),
    ],
  ),
);

/// Linear chain — Bulbasaur → Ivysaur → Venusaur. Used by tests that need
/// the non-branching shape.
EvolutionChain bulbasaurEvolutionChain() => EvolutionChain(
  root: EvolutionNode(
    stage: _stage(1, 'bulbasaur'),
    evolvesTo: [
      EvolutionNode(
        stage: _stage(2, 'ivysaur', condition: 'Level 16'),
        evolvesTo: [
          EvolutionNode(stage: _stage(3, 'venusaur', condition: 'Level 32')),
        ],
      ),
    ],
  ),
);

/// A stage with no further evolutions (e.g., Tauros). Used for the
/// RN-13 no-evolution case.
EvolutionChain singleStageChain({int id = 128, String name = 'tauros'}) =>
    EvolutionChain(root: EvolutionNode(stage: _stage(id, name)));
