// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class NamedResourceModel {
  final String? name;
  final String? url;

  NamedResourceModel({
    this.name,
    this.url,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'url': url,
    };
  }

  factory NamedResourceModel.fromMap(Map<String, dynamic> map) {
    return NamedResourceModel(
      name: map['name'] != null ? map['name'] as String : null,
      url: map['url'] != null ? map['url'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory NamedResourceModel.fromJson(String source) =>
      NamedResourceModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

/*
{
  "name": "poison",
  "url": "https://pokeapi.co/api/v2/type/4/"
}
*/