import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/models/entities/pokemon_stat.dart';

void main() {
  test('fromApi maps the six PokéAPI stat names', () {
    expect(StatKind.fromApi('hp'), StatKind.hp);
    expect(StatKind.fromApi('attack'), StatKind.attack);
    expect(StatKind.fromApi('defense'), StatKind.defense);
    expect(StatKind.fromApi('special-attack'), StatKind.specialAttack);
    expect(StatKind.fromApi('special-defense'), StatKind.specialDefense);
    expect(StatKind.fromApi('speed'), StatKind.speed);
  });

  test('fromApi returns null for unknown stats', () {
    expect(StatKind.fromApi('accuracy'), isNull);
    expect(StatKind.fromApi('specialAttack'), isNull);
  });

  test('labels follow the design, in display order', () {
    expect(StatKind.values.map((k) => k.label), [
      'HP',
      'ATK',
      'DEF',
      'SATK',
      'SDEF',
      'SPD',
    ]);
  });
}
