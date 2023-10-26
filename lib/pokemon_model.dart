class PokemonModel {
  final String? name;
  final String? url;

  PokemonModel({
    this.name,
    this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }

  factory PokemonModel.fromJson(Map<String, dynamic> json) {
    return PokemonModel(
      name: json['name'] != null ? json['name'] as String : null,
      url: json['url'] != null ? json['url'] as String : null,
    );
  }
}
