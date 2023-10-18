import 'package:pokedex/pokemon_model.dart';
import 'package:pokedex/resource_list_model.dart';

const url = "https://pokeapi.co/api/v2/pokemon";

Future<ResourceListModel?> fetchPokemonList() async {
  return kPokemonListMock;
}

final kPokemonListMock = ResourceListModel(
  count: 1292,
  next: "https://pokeapi.co/api/v2/pokemon/?offset=20&limit=20",
  previous: null,
  results: [
    PokemonModel(
      name: "bulbasaur",
      url: "https://pokeapi.co/api/v2/pokemon/1/",
    ),
    PokemonModel(
      name: "ivysaur",
      url: "https://pokeapi.co/api/v2/pokemon/2/",
    ),
    PokemonModel(
      name: "venusaur",
      url: "https://pokeapi.co/api/v2/pokemon/3/",
    ),
    PokemonModel(
      name: "charmander",
      url: "https://pokeapi.co/api/v2/pokemon/4/",
    ),
    PokemonModel(
      name: "charmeleon",
      url: "https://pokeapi.co/api/v2/pokemon/5/",
    ),
    PokemonModel(
      name: "charizard",
      url: "https://pokeapi.co/api/v2/pokemon/6/",
    ),
    PokemonModel(
      name: "squirtle",
      url: "https://pokeapi.co/api/v2/pokemon/7/",
    ),
    PokemonModel(
      name: "wartortle",
      url: "https://pokeapi.co/api/v2/pokemon/8/",
    ),
    PokemonModel(
      name: "blastoise",
      url: "https://pokeapi.co/api/v2/pokemon/9/",
    ),
    PokemonModel(
      name: "caterpie",
      url: "https://pokeapi.co/api/v2/pokemon/10/",
    ),
    PokemonModel(
      name: "metapod",
      url: "https://pokeapi.co/api/v2/pokemon/11/",
    ),
    PokemonModel(
      name: "butterfree",
      url: "https://pokeapi.co/api/v2/pokemon/12/",
    ),
    PokemonModel(
      name: "weedle",
      url: "https://pokeapi.co/api/v2/pokemon/13/",
    ),
    PokemonModel(
      name: "kakuna",
      url: "https://pokeapi.co/api/v2/pokemon/14/",
    ),
    PokemonModel(
      name: "beedrill",
      url: "https://pokeapi.co/api/v2/pokemon/15/",
    ),
    PokemonModel(
      name: "pidgey",
      url: "https://pokeapi.co/api/v2/pokemon/16/",
    ),
    PokemonModel(
      name: "pidgeotto",
      url: "https://pokeapi.co/api/v2/pokemon/17/",
    ),
    PokemonModel(
      name: "pidgeot",
      url: "https://pokeapi.co/api/v2/pokemon/18/",
    ),
    PokemonModel(
      name: "rattata",
      url: "https://pokeapi.co/api/v2/pokemon/19/",
    ),
    PokemonModel(
      name: "raticate",
      url: "https://pokeapi.co/api/v2/pokemon/20/",
    ),
  ],
);
