import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/models/rules/pokemon_format.dart';

void main() {
  group('number (RN-02)', () {
    test('pads to three digits', () {
      expect(PokemonFormat.number(4), '#004');
      expect(PokemonFormat.number(25), '#025');
      expect(PokemonFormat.number(151), '#151');
    });
  });

  group('displayName (RN-03)', () {
    const cases = {
      'bulbasaur': 'Bulbasaur',
      'nidoran-f': 'Nidoran♀',
      'nidoran-m': 'Nidoran♂',
      'mr-mime': 'Mr. Mime',
      'farfetchd': 'Farfetch’d',
      '': '',
    };
    for (final MapEntry(key: api, value: display) in cases.entries) {
      test('"$api" → "$display"', () {
        expect(PokemonFormat.displayName(api), display);
      });
    }
  });

  group('weight and height (RN-11)', () {
    test('converts to one decimal in en locale', () {
      expect(PokemonFormat.weightKg(69), '6.9 kg');
      expect(PokemonFormat.heightM(7), '0.7 m');
      expect(PokemonFormat.weightKg(1000), '100.0 kg');
      expect(PokemonFormat.heightM(0), '0.0 m');
    });

    test('missing values render as an em dash', () {
      expect(PokemonFormat.weightKg(null), '—');
      expect(PokemonFormat.heightM(null), '—');
    });
  });

  group('abilityName (RN-12)', () {
    test('capitalises each hyphen-separated word', () {
      expect(PokemonFormat.abilityName('solar-power'), 'Solar Power');
      expect(PokemonFormat.abilityName('overgrow'), 'Overgrow');
    });
  });

  group('stats (RN-15)', () {
    test('statValue pads to three digits', () {
      expect(PokemonFormat.statValue(45), '045');
      expect(PokemonFormat.statValue(0), '000');
      expect(PokemonFormat.statValue(255), '255');
      expect(PokemonFormat.statValue(-1), '000');
    });

    test('statFraction is relative to 255 and clamped to [0, 1]', () {
      expect(PokemonFormat.statFraction(0), 0.0);
      expect(PokemonFormat.statFraction(255), 1.0);
      expect(PokemonFormat.statFraction(300), 1.0);
      expect(PokemonFormat.statFraction(-1), 0.0);
      expect(PokemonFormat.statFraction(51), closeTo(0.2, 1e-9));
    });
  });

  group('flavorText (RN-13)', () {
    test(
      'replaces line breaks, form feeds and soft hyphens, collapses spaces',
      () {
        const raw =
            'A strange seed was\nplanted on its\fback at birth.\u00ADThe '
            'plant  sprouts and\n\ngrows.';

        expect(
          PokemonFormat.flavorText(raw),
          'A strange seed was planted on its back at birth. The plant sprouts '
          'and grows.',
        );
      },
    );

    test('trims surrounding whitespace', () {
      expect(PokemonFormat.flavorText('\n Hello \f'), 'Hello');
    });
  });
}
