import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('LocationAreaEncounterDto', () {
    test('parses the top-level encounters array (Pikachu)', () {
      final array = fixtureJsonArray('encounters_pikachu.json');
      final encounters = array
          .map(
            (e) => LocationAreaEncounterDto.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      expect(encounters, isNotEmpty);

      final first = encounters.first;
      expect(first.locationArea.name, isNotEmpty);
      expect(first.versionDetails, isNotEmpty);
      expect(first.versionDetails.first.version.name, isNotEmpty);
      expect(first.versionDetails.first.encounterDetails, isNotEmpty);
    });

    test('an empty encounters array decodes to an empty list', () {
      final array = jsonDecode('[]') as List<dynamic>;
      final encounters = array
          .map(
            (e) => LocationAreaEncounterDto.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      expect(encounters, isEmpty);
    });
  });
}
