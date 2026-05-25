/// The 18 Pokémon types.
///
/// Defined in `core/` (not `app/theme/`) so both the theme layer and the later
/// domain layer can depend on it without inverting the layer dependency rule.
enum PokemonTypeId {
  /// The Grass type.
  grass,

  /// The Poison type.
  poison,

  /// The Fire type.
  fire,

  /// The Water type.
  water,

  /// The Electric type.
  electric,

  /// The Bug type.
  bug,

  /// The Normal type.
  normal,

  /// The Flying type.
  flying,

  /// The Ground type.
  ground,

  /// The Fairy type.
  fairy,

  /// The Fighting type.
  fighting,

  /// The Psychic type.
  psychic,

  /// The Rock type.
  rock,

  /// The Ghost type.
  ghost,

  /// The Ice type.
  ice,

  /// The Dragon type.
  dragon,

  /// The Dark type.
  dark,

  /// The Steel type.
  steel,
}
