import 'package:logging/logging.dart';

import '../../../core/logging/loggers.dart';
import '../../entities/pokemon_detail.dart';
import '../../entities/pokemon_stat.dart';
import '../../entities/pokemon_summary.dart';
import '../../entities/pokemon_type.dart';
import '../../rules/pokemon_format.dart';
import 'poke_api_client.dart';

/// PokéAPI JSON → entities. Optional fields degrade (ERR-05); missing
/// required ones throw `FormatException`/`TypeError`, which the repository
/// turns into `ParsingFailure`.
abstract final class PokemonMappers {
  static final _log = Logger(LoggerNames.repository);
  static final _trailingId = RegExp(r'/(\d+)/?$');

  /// Abilities shown in the detail screen (RN-12).
  static const maxAbilities = 2;

  /// RN-01: the id is the last numeric segment of `url`; entries without
  /// an id or a name are dropped with a WARNING instead of failing the list.
  static List<PokemonSummary> index(JsonMap json) {
    final summaries = <PokemonSummary>[];
    for (final entry in (json['results'] as List<Object?>).cast<JsonMap>()) {
      final name = entry['name'] as String?;
      final url = entry['url'] as String?;
      final id = _idFromUrl(url);
      if (id == null || name == null) {
        _log.warning(
          'index entry dropped: no id or name {name=$name, url=$url}',
        );
        continue;
      }
      summaries.add(PokemonSummary(id: id, name: name));
    }
    return summaries;
  }

  /// ERR-05: `id`, `name` and a non-empty `types` are required.
  static PokemonDetail detail(JsonMap json) {
    final types = [
      for (final slot in _bySlot(json['types'] as List<Object?>))
        PokemonType.fromApi(_refName(slot['type'])),
    ];
    if (types.isEmpty) throw const FormatException('"types" is empty');

    return PokemonDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      types: types,
      weightHg: json['weight'] as int?,
      heightDm: json['height'] as int?,
      abilities: [
        for (final slot in _bySlot(json['abilities'] as List<Object?>? ?? []))
          _refName(slot['ability']),
      ].take(maxAbilities).toList(),
      stats: {
        for (final entry in _maps(json['stats'] as List<Object?>? ?? []))
          ?StatKind.fromApi(_refName(entry['stat'])): entry['base_stat'] as int,
      },
    );
  }

  /// RN-13: first English flavor text, cleaned; none → `null`.
  static String? description(JsonMap speciesJson) {
    final entries = speciesJson['flavor_text_entries'] as List<Object?>? ?? [];
    for (final entry in _maps(entries)) {
      if (_refName(entry['language']) == 'en') {
        return PokemonFormat.flavorText(entry['flavor_text'] as String);
      }
    }
    return null;
  }

  static int? _idFromUrl(String? url) {
    final match = url == null ? null : _trailingId.firstMatch(url);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static Iterable<JsonMap> _maps(List<Object?> list) => list.cast<JsonMap>();

  static List<JsonMap> _bySlot(List<Object?> list) =>
      _maps(list).toList()
        ..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));

  /// Name of a named API resource, e.g. `{"name": "grass", "url": …}`.
  static String _refName(Object? resource) =>
      (resource as JsonMap)['name'] as String;
}
