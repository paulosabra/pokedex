import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/models/entities/pokemon_summary.dart';

void main() {
  const charmander = PokemonSummary(id: 4, name: 'charmander');

  test('number is zero-padded (RN-02)', () {
    expect(charmander.number, '#004');
  });

  test('displayName applies RN-03', () {
    expect(charmander.displayName, 'Charmander');
    expect(
      const PokemonSummary(id: 122, name: 'mr-mime').displayName,
      'Mr. Mime',
    );
  });

  test('artworkUrl is the official artwork for the id (PRD §13.4)', () {
    expect(
      charmander.artworkUrl.toString(),
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
      'pokemon/other/official-artwork/4.png',
    );
  });

  test('has value equality', () {
    expect(charmander, const PokemonSummary(id: 4, name: 'charmander'));
    expect(
      charmander.hashCode,
      const PokemonSummary(id: 4, name: 'charmander').hashCode,
    );
    expect(charmander, isNot(const PokemonSummary(id: 5, name: 'charmander')));
    expect(charmander.toString(), 'PokemonSummary(4, charmander)');
  });
}
