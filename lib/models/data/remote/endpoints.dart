/// PokéAPI v2 resources used by the app (PRD §13.4), relative to [baseUrl].
abstract final class Endpoints {
  static final baseUrl = Uri.parse('https://pokeapi.co/api/v2/');

  /// Gen 1 only (RN-01).
  static const gen1Count = 151;

  static const index = 'pokemon?limit=$gen1Count&offset=0';

  static String pokemon(int id) => 'pokemon/$id';

  static String species(int id) => 'pokemon-species/$id';
}
