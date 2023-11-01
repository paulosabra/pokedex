import 'package:pokemon/models/named_resource_model.dart';

class PokemonTypeModel {
  final int? slot;
  final NamedResourceModel? type;

  PokemonTypeModel({
    this.slot,
    this.type,
  });
}

/*
{
  "slot": 1,
  "type": {}
}
*/