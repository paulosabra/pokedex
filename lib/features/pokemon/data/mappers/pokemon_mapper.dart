import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/generation_ranges.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';

/// Maps a [PokemonDto] to the [Pokemon] list-card entity.
///
/// Types are ordered primary-first by slot (RN-05); unknown type names are
/// dropped (TE-10). The image is the official artwork (empty when absent), and
/// the generation is derived from the National Dex id (RN-15).
Pokemon pokemonFromDto(PokemonDto dto) {
  final ordered = dto.types.toList()..sort((a, b) => a.slot.compareTo(b.slot));
  final types = ordered
      .map((slot) => pokemonTypeIdFromName(slot.type.name))
      .whereType<PokemonTypeId>()
      .toList();

  return Pokemon(
    id: dto.id,
    name: dto.name,
    imageUrl: dto.sprites?.other?.officialArtwork?.frontDefault ?? '',
    generationId: generationForId(dto.id),
    types: types,
  );
}
