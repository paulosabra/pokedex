/// The 18 Pokémon types.
///
/// Defined in `core/` (not `app/theme/`) so both the theme layer and the later
/// domain layer can depend on it without inverting the layer dependency rule.
///
/// ⚠️ Each value's `index` is a PERSISTED contract: the data layer stores it in
/// the SQLite cache (`primaryTypeId`/`secondaryTypeId`) and encodes it into the
/// weakness bitmask (`1 << index`). Do NOT reorder or remove values — doing so
/// silently corrupts every cached row. Append new types at the end only.
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
