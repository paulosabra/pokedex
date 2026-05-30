import 'package:freezed_annotation/freezed_annotation.dart';

part 'named_api_resource_dto.freezed.dart';
part 'named_api_resource_dto.g.dart';

/// A PokéAPI named API resource: `{ "name": ..., "url": ... }`.
///
/// [name] defaults to `''` so this DTO also covers the API's url-only
/// resource shape, where a resource is `{ "url": ... }` with no name
/// (e.g. a species' `evolution_chain`). Such callers read [idFromUrl].
@freezed
abstract class NamedApiResourceDto with _$NamedApiResourceDto {
  /// Creates a [NamedApiResourceDto].
  const factory NamedApiResourceDto({
    required String url,
    @Default('') String name,
  }) = _NamedApiResourceDto;

  const NamedApiResourceDto._();

  /// Deserializes a [NamedApiResourceDto] from PokéAPI JSON.
  factory NamedApiResourceDto.fromJson(Map<String, dynamic> json) =>
      _$NamedApiResourceDtoFromJson(json);

  /// The trailing numeric id parsed from [url] (e.g. `/evolution-chain/67/` → 67),
  /// or `null` when the URL has no trailing integer segment.
  int? get idFromUrl {
    final segments = url.split('/').where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }
}
