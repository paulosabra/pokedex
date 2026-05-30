import 'package:flutter/material.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

/// The visual style for a Pokémon type: its badge color and card background
/// color.
///
/// A record for now; T-18 promotes it to a class that also carries the type
/// icon (so call sites keep using `.color` / `.backgroundColor`).
typedef PokemonTypeStyle = ({Color color, Color backgroundColor});

/// Resolves per-type colors (RN-04 / Tech Spec §10.3), centralizing type
/// theming so every badge and card derives its color from one place.
abstract final class PokemonTypeTheme {
  const PokemonTypeTheme._();

  /// Badge / icon color per type (§10.3 — all 18 specified).
  static const Map<PokemonTypeId, Color> _colors = {
    PokemonTypeId.grass: Color(0xFF62B957),
    PokemonTypeId.poison: Color(0xFFA552CC),
    PokemonTypeId.fire: Color(0xFFFD7D24),
    PokemonTypeId.water: Color(0xFF4A90DA),
    PokemonTypeId.electric: Color(0xFFEED535),
    PokemonTypeId.bug: Color(0xFF8CB230),
    PokemonTypeId.normal: Color(0xFF9DA0AA),
    PokemonTypeId.flying: Color(0xFF748FC9),
    PokemonTypeId.ground: Color(0xFFDD7748),
    PokemonTypeId.fairy: Color(0xFFED6EC7),
    PokemonTypeId.fighting: Color(0xFFD04164),
    PokemonTypeId.psychic: Color(0xFFEA5D60),
    PokemonTypeId.rock: Color(0xFFBAAB82),
    PokemonTypeId.ghost: Color(0xFF556AAE),
    PokemonTypeId.ice: Color(0xFF61CEC0),
    PokemonTypeId.dragon: Color(0xFF0F6AC0),
    PokemonTypeId.dark: Color(0xFF58575F),
    PokemonTypeId.steel: Color(0xFF417D9A),
  };

  /// Card-background tint per type — Figma `Background Type / *` variables on
  /// the Style Guide. All 18 are explicit (no derivation).
  static const Map<PokemonTypeId, Color> _backgrounds = {
    PokemonTypeId.bug: Color(0xFF8BD674),
    PokemonTypeId.dark: Color(0xFF6F6E78),
    PokemonTypeId.dragon: Color(0xFF7383B9),
    PokemonTypeId.electric: Color(0xFFF2CB55),
    PokemonTypeId.fairy: Color(0xFFEBA8C3),
    PokemonTypeId.fighting: Color(0xFFEB4971),
    PokemonTypeId.fire: Color(0xFFFFA756),
    PokemonTypeId.flying: Color(0xFF83A2E3),
    PokemonTypeId.ghost: Color(0xFF8571BE),
    PokemonTypeId.grass: Color(0xFF8BBE8A),
    PokemonTypeId.ground: Color(0xFFF78551),
    PokemonTypeId.ice: Color(0xFF91D8DF),
    PokemonTypeId.normal: Color(0xFFB5B9C4),
    PokemonTypeId.poison: Color(0xFF9F6E97),
    PokemonTypeId.psychic: Color(0xFFFF6568),
    PokemonTypeId.rock: Color(0xFFD4C294),
    PokemonTypeId.steel: Color(0xFF4C91B2),
    PokemonTypeId.water: Color(0xFF58ABF6),
  };

  /// The [PokemonTypeStyle] for [type].
  static PokemonTypeStyle styleOf(PokemonTypeId type) =>
      (color: _colors[type]!, backgroundColor: _backgrounds[type]!);
}
