// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:pokedex/pokemon_model.dart';

class ResourceListModel {
  final int? count;
  final String? next;
  final String? previous;
  final List<PokemonModel>? results;

  ResourceListModel({
    this.count,
    this.next,
    this.previous,
    this.results,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'count': count,
      'next': next,
      'previous': previous,
      'results': results != null
          ? List<PokemonModel>.from(results!.map((item) => item.toJson()))
          : [],
    };
  }

  factory ResourceListModel.fromJson(Map<String, dynamic> json) {
    return ResourceListModel(
      count: json['count'] != null ? json['count'] as int : null,
      next: json['next'] != null ? json['next'] as String : null,
      previous: json['previous'] != null ? json['previous'] as String : null,
      results: json['results'] != null
          ? List<PokemonModel>.from(
              json['results']!.map((item) => PokemonModel.fromJson(item)),
            )
          : [],
    );
  }
}
