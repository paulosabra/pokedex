/// The 18 elemental types plus [unknown] for anything the app does not know
/// (RN-10).
enum PokemonType {
  bug,
  dark,
  dragon,
  electric,
  fairy,
  fighting,
  fire,
  flying,
  ghost,
  normal,
  grass,
  ground,
  ice,
  poison,
  psychic,
  rock,
  steel,
  water,
  unknown;

  static final _byApiName = {for (final type in values) type.name: type};

  /// Maps a PokéAPI type name (e.g. `"grass"`); unknown names → [unknown].
  static PokemonType fromApi(String name) => _byApiName[name] ?? unknown;

  /// Chip label, e.g. `Grass`.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}
