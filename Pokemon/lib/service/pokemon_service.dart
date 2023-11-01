import 'package:pokemon/models/named_resource_model.dart';
import 'package:pokemon/models/pokemon_dream_world_model.dart';
import 'package:pokemon/models/pokemon_model.dart';
import 'package:pokemon/models/pokemon_other_sprites_model.dart';
import 'package:pokemon/models/pokemon_sprites_model.dart';
import 'package:pokemon/models/pokemon_stat_model.dart';
import 'package:pokemon/models/pokemon_type_model.dart';

const url = "https://pokeapi.co/api/v2/pokemon/";

Future<PokemonModel?> fetchPokemon({int? id}) async {
  return kPokemonMock;
}

final kPokemonMock = PokemonModel(
  id: 1,
  name: "bulbasaur",
  height: 7,
  weight: 69,
  stats: [
    PokemonStatModel(
      baseStat: 45,
      effort: 0,
      stat: NamedResourceModel(
        name: "hp",
        url: "https://pokeapi.co/api/v2/stat/1/",
      ),
    ),
    PokemonStatModel(
      baseStat: 49,
      effort: 0,
      stat: NamedResourceModel(
        name: "attack",
        url: "https://pokeapi.co/api/v2/stat/2/",
      ),
    ),
    PokemonStatModel(
      baseStat: 49,
      effort: 0,
      stat: NamedResourceModel(
        name: "defense",
        url: "https://pokeapi.co/api/v2/stat/3/",
      ),
    ),
    PokemonStatModel(
      baseStat: 65,
      effort: 1,
      stat: NamedResourceModel(
        name: "special-attack",
        url: "https://pokeapi.co/api/v2/stat/4/",
      ),
    ),
    PokemonStatModel(
      baseStat: 65,
      effort: 0,
      stat: NamedResourceModel(
        name: "special-defense",
        url: "https://pokeapi.co/api/v2/stat/5/",
      ),
    ),
    PokemonStatModel(
      baseStat: 45,
      effort: 0,
      stat: NamedResourceModel(
        name: "speed",
        url: "https://pokeapi.co/api/v2/stat/6/",
      ),
    ),
  ],
  types: [
    PokemonTypeModel(
      slot: 1,
      type: NamedResourceModel(
        name: "grass",
        url: "https://pokeapi.co/api/v2/type/12/",
      ),
    ),
    PokemonTypeModel(
      slot: 2,
      type: NamedResourceModel(
        name: "poison",
        url: "https://pokeapi.co/api/v2/type/4/",
      ),
    ),
  ],
  sprites: PokemonSpritesModel(
    other: PokemonOtherSpritesModel(
      dreamWorld: PokemonDreamWorldModel(
        frontDefault:
            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/dream-world/1.svg",
        frontFemale: null,
      ),
    ),
  ),
);
