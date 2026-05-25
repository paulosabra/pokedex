import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('TypeDto.fromJson', () {
    test('parses a type and its directional damage relations', () {
      final type = TypeDto.fromJson(fixtureJson('type_grass.json'));

      expect(type.id, 12);
      expect(type.name, 'grass');

      final relations = type.damageRelations;
      // Grass takes double damage from fire (the canonical weakness).
      expect(
        relations.doubleDamageFrom.map((r) => r.name),
        contains('fire'),
      );
      // Grass deals double damage to water.
      expect(
        relations.doubleDamageTo.map((r) => r.name),
        contains('water'),
      );
      // half_damage_* drive the 0.5x multiplier in PR3 weakness math; lock the
      // snake_case mapping for both directions.
      expect(
        relations.halfDamageFrom.map((r) => r.name),
        contains('water'),
      );
      expect(
        relations.halfDamageTo.map((r) => r.name),
        contains('fire'),
      );
    });

    test(
      'parses an immunity relation (Ground takes no damage from Electric)',
      () {
        final type = TypeDto.fromJson(fixtureJson('type_ground.json'));

        expect(type.name, 'ground');
        expect(
          type.damageRelations.noDamageFrom.map((r) => r.name),
          contains('electric'),
        );
      },
    );
  });
}
