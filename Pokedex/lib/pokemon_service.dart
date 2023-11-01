import 'package:dio/dio.dart';
import 'package:pokedex/resource_list_model.dart';

const url = "https://pokeapi.co/api/v2/pokemon";

Future<ResourceListModel?> fetchPokemonList() async {
  try {
    Dio dio = Dio();
    final response = await dio.get(url);
    return ResourceListModel.fromJson(response.data);
  } on DioException catch (error) {
    print('Erro ao realizar get ${error.response?.statusCode}');
    throw Exception('Falha ao Carregar Dados');
  }
}
