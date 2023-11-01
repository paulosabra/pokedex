import 'package:pokemon/models/named_resource_model.dart';

class PokemonStatModel {
  final int? baseStat;
  final int? effort;
  final NamedResourceModel? stat;

  PokemonStatModel({
    this.baseStat,
    this.effort,
    this.stat,
  });
}

/*
{
  "base_stat": 45,
  "effort": 0,
  "stat": {}
}
*/