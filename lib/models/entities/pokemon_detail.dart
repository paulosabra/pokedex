import 'pokemon_stat.dart';
import 'pokemon_summary.dart';
import 'pokemon_type.dart';

/// Everything the detail screen renders. Collections are unmodifiable.
///
/// A `null` [description] is the Partial state (E-09, TS-08), not an error.
final class PokemonDetail {
  PokemonDetail({
    required this.id,
    required this.name,
    required List<PokemonType> types,
    required this.weightHg,
    required this.heightDm,
    required List<String> abilities,
    required Map<StatKind, int> stats,
    this.description,
  }) : types = List.unmodifiable(_requireNonEmpty(types)),
       abilities = List.unmodifiable(abilities),
       stats = Map.unmodifiable(stats);

  final int id;
  final String name;

  /// 1..2 types in slot order (RF-18).
  final List<PokemonType> types;

  /// Hectograms; `null` renders as `—`.
  final int? weightHg;

  /// Decimetres; `null` renders as `—`.
  final int? heightDm;

  /// Raw ability names, at most 2, in slot order (RN-12).
  final List<String> abilities;

  final Map<StatKind, int> stats;

  /// English flavor text, already cleaned by `PokemonFormat.flavorText`.
  final String? description;

  /// Slot-1 type; drives the screen colour (RN-10).
  PokemonType get primaryType => types.first;

  PokemonSummary get summary => PokemonSummary(id: id, name: name);

  /// Missing stats display as 0 (ERR-05).
  int statOf(StatKind kind) => stats[kind] ?? 0;

  PokemonDetail withDescription(String? description) => PokemonDetail(
    id: id,
    name: name,
    types: types,
    weightHg: weightHg,
    heightDm: heightDm,
    abilities: abilities,
    stats: stats,
    description: description,
  );

  @override
  bool operator ==(Object other) =>
      other is PokemonDetail &&
      other.id == id &&
      other.name == name &&
      _listEquals(other.types, types) &&
      other.weightHg == weightHg &&
      other.heightDm == heightDm &&
      _listEquals(other.abilities, abilities) &&
      _mapEquals(other.stats, stats) &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(types),
    weightHg,
    heightDm,
    Object.hashAll(abilities),
    Object.hashAllUnordered(
      stats.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    description,
  );

  @override
  String toString() => 'PokemonDetail($id, $name)';
}

/// Enforced in release too, so a bad payload fails at construction (where the
/// mapper turns it into `ParsingFailure`) instead of later in `primaryType`.
List<PokemonType> _requireNonEmpty(List<PokemonType> types) => types.isEmpty
    ? throw ArgumentError.value(types, 'types', 'must not be empty')
    : types;

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
