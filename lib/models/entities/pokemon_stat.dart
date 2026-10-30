/// The six base stats shown in the detail screen, in display order.
enum StatKind {
  hp('hp', 'HP'),
  attack('attack', 'ATK'),
  defense('defense', 'DEF'),
  specialAttack('special-attack', 'SATK'),
  specialDefense('special-defense', 'SDEF'),
  speed('speed', 'SPD');

  const StatKind(this.apiName, this.label);

  /// Name used by PokéAPI, e.g. `special-attack`.
  final String apiName;

  /// Short label shown next to the stat bar.
  final String label;

  static final _byApiName = {for (final kind in values) kind.apiName: kind};

  /// Maps a PokéAPI stat name; stats outside the six are ignored (`null`).
  static StatKind? fromApi(String name) => _byApiName[name];
}
