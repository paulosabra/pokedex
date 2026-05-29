import 'dart:convert';

import 'package:dio/dio.dart';

/// A deterministic, in-process stand-in for the PokéAPI used by the E2E flows.
///
/// It synthesises valid PokéAPI JSON for an imaginary catalogue of [total]
/// Pokémon so the whole repository → use-case → view-model graph runs for real
/// without ever touching the network. The repository's `getPokemonList`
/// fan-out (one list page → 18 `/type/{id}` charts → 24 `/pokemon/{id}`
/// details) is served by routing on the request path rather than a positional
/// queue, which keeps the harness agnostic to call ordering.
///
/// A handful of ids carry a recognisable [_names] entry (e.g. id 1 →
/// `bulbasaur`) so tests can search by name and assert on a stable result.
class FakePokeApi {
  /// Creates a [FakePokeApi] simulating a catalogue of [total] Pokémon.
  FakePokeApi({this.total = 48});

  /// The size of the simulated National-Dex index. Two pages of 24 by default.
  final int total;

  /// Ids that map to a recognisable name; every other id is `pokemon-<id>`.
  static const Map<int, String> _names = {1: 'bulbasaur', 25: 'pikachu'};

  /// The name reported for [id].
  String nameOf(int id) => _names[id] ?? 'pokemon-$id';

  /// Builds a [Dio] wired to this fake so it can replace `dioProvider` in a
  /// `ProviderScope` override. Interceptors are intentionally omitted — the
  /// fake never produces the transient 429/5xx responses they handle, and
  /// their retry/backoff timers would only add nondeterminism to the E2E.
  Dio buildDio() =>
      Dio(BaseOptions(baseUrl: 'https://pokeapi.co/api/v2/'))
        ..httpClientAdapter = _FakePokeApiAdapter(this);

  /// Routes a request to its synthetic JSON body, or a 404 when unrecognised.
  ResponseBody respond(RequestOptions options) {
    final segments = options.uri.pathSegments;

    if (segments.contains('pokemon-species')) {
      return _json(_species(int.parse(segments.last)));
    }
    if (segments.contains('type')) {
      return _json(_type(int.parse(segments.last)));
    }

    final pokemonIndex = segments.indexOf('pokemon');
    if (pokemonIndex != -1 && segments.length > pokemonIndex + 1) {
      if (segments.last == 'encounters') return _json('[]');
      return _json(_pokemon(int.parse(segments[pokemonIndex + 1])));
    }
    if (pokemonIndex != -1) {
      final query = options.uri.queryParameters;
      final offset = int.tryParse(query['offset'] ?? '');
      // `offset` is absent only for the single-shot full-index fetch
      // (`getPokemonIndex(limit)`); a paged list fetch always sends it.
      return _json(
        offset == null
            ? _listResponse(start: 1, end: total)
            : _page(offset: offset, limit: int.parse(query['limit']!)),
      );
    }

    return ResponseBody.fromString('', 404);
  }

  String _page({required int offset, required int limit}) {
    final start = offset + 1;
    final end = (offset + limit).clamp(0, total);
    final hasMore = end < total;
    return _listResponse(
      start: start,
      end: end,
      next: hasMore
          ? 'https://pokeapi.co/api/v2/pokemon?offset=$end&limit=$limit'
          : null,
    );
  }

  String _listResponse({required int start, required int end, String? next}) {
    final results = [
      for (var id = start; id <= end; id++)
        {
          'name': nameOf(id),
          'url': 'https://pokeapi.co/api/v2/pokemon/$id/',
        },
    ];
    return jsonEncode({'count': total, 'next': next, 'results': results});
  }

  String _pokemon(int id) => jsonEncode({
    'id': id,
    'name': nameOf(id),
    'height': 7,
    'weight': 69,
    'base_experience': 64,
    'sprites': {
      'other': {
        'official-artwork': {'front_default': 'https://img/$id.png'},
      },
    },
    'types': [
      {
        'slot': 1,
        'type': {'name': 'grass', 'url': 'https://pokeapi.co/api/v2/type/12/'},
      },
    ],
    'stats': [
      for (final stat in const [
        'hp',
        'attack',
        'defense',
        'special-attack',
        'special-defense',
        'speed',
      ])
        {
          'base_stat': 45,
          'effort': 0,
          'stat': {'name': stat, 'url': ''},
        },
    ],
    'abilities': [
      {
        'ability': {'name': 'overgrow', 'url': ''},
        'is_hidden': false,
        'slot': 1,
      },
    ],
  });

  String _species(int id) => jsonEncode({
    'id': id,
    'name': nameOf(id),
    'gender_rate': 1,
    'capture_rate': 45,
    'base_happiness': 50,
    'hatch_counter': 20,
    'growth_rate': {
      'name': 'medium-slow',
      'url': 'https://pokeapi.co/api/v2/growth-rate/4/',
    },
    'generation': {
      'name': 'generation-i',
      'url': 'https://pokeapi.co/api/v2/generation/1/',
    },
    'evolution_chain': {
      'url': 'https://pokeapi.co/api/v2/evolution-chain/$id/',
    },
    'egg_groups': [
      {'name': 'monster', 'url': ''},
    ],
    'flavor_text_entries': [
      {
        'flavor_text': 'A Pokémon used for end-to-end testing.',
        'language': {'name': 'en', 'url': ''},
        'version': {'name': 'red', 'url': ''},
      },
    ],
    'genera': [
      {
        'genus': 'Test Pokémon',
        'language': {'name': 'en', 'url': ''},
      },
    ],
  });

  String _type(int id) => jsonEncode({
    'id': id,
    'name': 'type-$id',
    'damage_relations': <String, dynamic>{},
  });

  ResponseBody _json(String body) => ResponseBody.fromString(
    body,
    200,
    headers: const {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakePokeApiAdapter implements HttpClientAdapter {
  _FakePokeApiAdapter(this._api);

  final FakePokeApi _api;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => _api.respond(options);

  @override
  void close({bool force = false}) {}
}
