/// The criteria by which the Pokémon list can be ordered (RF-20…RF-23).
enum SortCriteria {
  /// By National Dex number, ascending (#001 first).
  numberAsc,

  /// By National Dex number, descending.
  numberDesc,

  /// By name, A → Z.
  nameAsc,

  /// By name, Z → A.
  nameDesc,
}
