import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_entry.freezed.dart';
part 'location_entry.g.dart';

/// A location where a Pokémon can be encountered, with the game [versions]
/// in which it appears there (RF-34).
@freezed
abstract class LocationEntry with _$LocationEntry {
  /// Creates a [LocationEntry].
  const factory LocationEntry({
    required String area,
    @Default(<String>[]) List<String> versions,
  }) = _LocationEntry;

  /// Deserializes a [LocationEntry] from cache JSON.
  factory LocationEntry.fromJson(Map<String, dynamic> json) =>
      _$LocationEntryFromJson(json);
}
