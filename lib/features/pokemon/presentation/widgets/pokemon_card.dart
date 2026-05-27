import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/core/ui/components/pokemon_card.dart' as core;
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';

/// Feature-side adapter for `core.PokemonCard`.
///
/// Takes a [Pokemon] domain entity, unpacks the primitive parameters the DS
/// component expects, and routes a tap to the detail screen. Keeps domain
/// imports out of `lib/core/ui/`.
class PokemonCard extends StatelessWidget {
  /// Creates a [PokemonCard].
  const PokemonCard({required this.pokemon, super.key});

  /// The Pokémon to render.
  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final types = pokemon.types;
    return core.PokemonCard(
      id: pokemon.id,
      name: pokemon.name,
      primaryType: types.first,
      secondaryType: types.length > 1 ? types[1] : null,
      imageUrl: pokemon.imageUrl,
      onTap: () => context.go('/pokemon/${pokemon.id}'),
    );
  }
}
