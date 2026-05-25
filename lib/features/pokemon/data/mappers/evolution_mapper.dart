import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';

const _artworkBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
    'pokemon/other/official-artwork';

/// Maps an [EvolutionChainDto] to the recursive [EvolutionChain] entity
/// (RN-13), preserving branching lines such as Eevee.
EvolutionChain evolutionChainFromDto(EvolutionChainDto dto) =>
    EvolutionChain(root: _nodeFromLink(dto.chain));

EvolutionNode _nodeFromLink(ChainLinkDto link) => EvolutionNode(
  stage: EvolutionStage(
    id: link.species.idFromUrl ?? 0,
    name: link.species.name,
    imageUrl: _artworkUrl(link.species.idFromUrl),
    condition: _conditionFrom(link.evolutionDetails),
  ),
  evolvesTo: link.evolvesTo.map(_nodeFromLink).toList(),
);

String _artworkUrl(int? id) => id == null ? '' : '$_artworkBase/$id.png';

/// Derives a human-readable evolution condition from the first detail, picking
/// the first populated trigger (level / item / trade / happiness / …).
String? _conditionFrom(List<EvolutionDetailDto> details) {
  if (details.isEmpty) return null;
  final detail = details.first;
  if (detail.minLevel != null) return 'Level ${detail.minLevel}';
  if (detail.item != null) return 'Use ${_humanize(detail.item!.name)}';
  if (detail.trigger.name == 'trade') return 'Trade';
  if (detail.minHappiness != null) return 'High friendship';
  if (detail.heldItem != null) {
    return 'Hold ${_humanize(detail.heldItem!.name)}';
  }
  if (detail.knownMove != null) {
    return 'Knows ${_humanize(detail.knownMove!.name)}';
  }
  final time = detail.timeOfDay;
  if (time != null && time.isNotEmpty) return 'During $time';
  if (detail.location != null) return 'At ${_humanize(detail.location!.name)}';
  return null;
}

String _humanize(String value) => value.replaceAll('-', ' ');
