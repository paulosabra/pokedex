import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

/// Common Latin diacritics mapped to their base letter, for name normalization.
const _diacritics = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Normalizes a Pokémon name for accent/case-insensitive search (RN-07):
/// lowercased with common Latin diacritics stripped.
///
/// Used both to populate `PokemonSummaries.nameNormalized` (the PR3 cache
/// mapper) and to normalize the search term in the DAO, so the stored value and
/// the query term always agree.
String normalizeName(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}

/// Canonical weakness bitmask encoding (RF-15): bit `i` corresponds to
/// `PokemonTypeId.values[i]`.
///
/// Shared by the DAO's SQL weakness filter (PR2) and the repository's mask
/// population (PR3) so both agree on the bit layout.
int typeWeaknessMask(Iterable<PokemonTypeId> types) =>
    types.fold(0, (mask, type) => mask | (1 << type.index));
