class NamedResourceModel {
  final String? name;
  final String? url;

  NamedResourceModel({
    this.name,
    this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }

  factory NamedResourceModel.fromJson(Map<String, dynamic> json) {
    return NamedResourceModel(
      name: json['name'] != null ? json['name'] as String : null,
      url: json['url'] != null ? json['url'] as String : null,
    );
  }
}
