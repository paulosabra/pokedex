import '../rules/pokemon_format.dart';

/// A Pokédex index entry: enough to render a grid card without a detail call.
final class PokemonSummary {
  const PokemonSummary({required this.id, required this.name});

  /// Pokédex number, 1..151.
  final int id;

  /// Raw PokéAPI name, e.g. `mr-mime`.
  final String name;

  /// RN-03, e.g. `Mr. Mime`.
  String get displayName => PokemonFormat.displayName(name);

  /// RN-02, e.g. `#004`.
  String get number => PokemonFormat.number(id);

  /// D5: official artwork derived from the id (PRD §13.4).
  Uri get artworkUrl => Uri.parse(
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
    'pokemon/other/official-artwork/$id.png',
  );

  @override
  bool operator ==(Object other) =>
      other is PokemonSummary && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'PokemonSummary($id, $name)';
}
