import 'package:dio/dio.dart';
import 'package:pokemon/models/pokemon_model.dart';

const url = "https://pokeapi.co/api/v2/pokemon/";

Future<PokemonModel?> fetchPokemon(int id) async {
  try {
    Dio dio = Dio();
    final response = await dio.get("$url$id");
    return PokemonModel.fromJson(response.data);
  } on DioException catch (error) {
    throw Exception(
        'Falha ao Carregar Dados: ${error.response?.statusCode} - ${error.response?.data}');
  }
}
