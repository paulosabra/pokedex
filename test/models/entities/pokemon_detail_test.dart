import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/models/entities/pokemon_detail.dart';
import 'package:pokedex/models/entities/pokemon_stat.dart';
import 'package:pokedex/models/entities/pokemon_summary.dart';
import 'package:pokedex/models/entities/pokemon_type.dart';

PokemonDetail _bulbasaur({String? description = 'A strange seed.'}) =>
    PokemonDetail(
      id: 1,
      name: 'bulbasaur',
      types: [PokemonType.grass, PokemonType.poison],
      weightHg: 69,
      heightDm: 7,
      abilities: ['overgrow', 'chlorophyll'],
      stats: {StatKind.hp: 45, StatKind.attack: 49},
      description: description,
    );

void main() {
  group('immutability', () {
    test('collections are unmodifiable', () {
      final detail = _bulbasaur();

      expect(() => detail.types.add(PokemonType.fire), throwsUnsupportedError);
      expect(detail.abilities.clear, throwsUnsupportedError);
      expect(() => detail.stats[StatKind.speed] = 1, throwsUnsupportedError);
    });

    test('rejects empty types', () {
      expect(
        () => PokemonDetail(
          id: 1,
          name: 'bulbasaur',
          types: const [],
          weightHg: null,
          heightDm: null,
          abilities: const [],
          stats: const {},
        ),
        throwsArgumentError,
      );
    });

    test('later changes to the source collections do not leak in', () {
      final types = [PokemonType.grass];
      final abilities = ['overgrow'];
      final stats = {StatKind.hp: 45};
      final detail = PokemonDetail(
        id: 1,
        name: 'bulbasaur',
        types: types,
        weightHg: null,
        heightDm: null,
        abilities: abilities,
        stats: stats,
      );

      types.add(PokemonType.fire);
      abilities.add('chlorophyll');
      stats[StatKind.speed] = 45;

      expect(detail.types, [PokemonType.grass]);
      expect(detail.abilities, ['overgrow']);
      expect(detail.stats, {StatKind.hp: 45});
    });
  });

  test('primaryType is the slot-1 type', () {
    expect(_bulbasaur().primaryType, PokemonType.grass);
  });

  test('summary preserves id and name', () {
    expect(
      _bulbasaur().summary,
      const PokemonSummary(id: 1, name: 'bulbasaur'),
    );
  });

  test('statOf defaults missing stats to 0 (ERR-05)', () {
    final detail = _bulbasaur();

    expect(detail.statOf(StatKind.hp), 45);
    expect(detail.statOf(StatKind.speed), 0);
  });

  group('withDescription', () {
    test('returns a copy with the new description', () {
      final partial = _bulbasaur(description: null);

      final full = partial.withDescription('Seed Pokémon.');

      expect(full, isNot(same(partial)));
      expect(full.description, 'Seed Pokémon.');
      expect(partial.description, isNull);
      expect(full, _bulbasaur(description: 'Seed Pokémon.'));
    });

    test('can clear the description (Partial, TS-08)', () {
      expect(_bulbasaur().withDescription(null).description, isNull);
    });
  });

  group('value equality', () {
    test('equal fields are equal with the same hashCode', () {
      expect(_bulbasaur(), _bulbasaur());
      expect(_bulbasaur().hashCode, _bulbasaur().hashCode);
    });

    test('any differing field breaks equality', () {
      final base = _bulbasaur();
      PokemonDetail variant({
        List<PokemonType>? types,
        int? weightHg = 69,
        List<String>? abilities,
        Map<StatKind, int>? stats,
      }) => PokemonDetail(
        id: 1,
        name: 'bulbasaur',
        types: types ?? base.types,
        weightHg: weightHg,
        heightDm: 7,
        abilities: abilities ?? base.abilities,
        stats: stats ?? base.stats,
        description: base.description,
      );

      expect(base, variant());
      expect(base, isNot(variant(types: [PokemonType.grass])));
      expect(
        base,
        isNot(variant(types: [PokemonType.poison, PokemonType.grass])),
      );
      expect(base, isNot(variant(weightHg: null)));
      expect(base, isNot(variant(abilities: ['overgrow'])));
      expect(
        base,
        isNot(variant(stats: {StatKind.hp: 45, StatKind.attack: 50})),
      );
      expect(
        base,
        isNot(variant(stats: {StatKind.hp: 45, StatKind.speed: 49})),
      );
      expect(base, isNot(_bulbasaur(description: null)));
      expect(base.toString(), 'PokemonDetail(1, bulbasaur)');
    });
  });
}
