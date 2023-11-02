class PokemonDreamWorldModel {
  final String? frontDefault;
  final String? frontFemale;

  PokemonDreamWorldModel({
    this.frontDefault,
    this.frontFemale,
  });

  Map<String, dynamic> toJson() {
    return {
      'front_default': frontDefault,
      'front_female': frontFemale,
    };
  }

  factory PokemonDreamWorldModel.fromJson(Map<String, dynamic> json) {
    return PokemonDreamWorldModel(
      frontDefault: json['front_default'] != null
          ? json['front_default'] as String
          : null,
      frontFemale:
          json['front_female'] != null ? json['front_female'] as String : null,
    );
  }
}
