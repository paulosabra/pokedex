import 'package:freezed_annotation/freezed_annotation.dart';

part 'breeding.freezed.dart';
part 'breeding.g.dart';

/// Gender distribution for a species (RN-11). When [isGenderless] is true, the
/// percentages are null; otherwise both are populated and sum to 100.
@freezed
abstract class Gender with _$Gender {
  /// Creates a [Gender].
  const factory Gender({
    required bool isGenderless,
    double? femalePercent,
    double? malePercent,
  }) = _Gender;

  /// Deserializes a [Gender] from cache JSON.
  factory Gender.fromJson(Map<String, dynamic> json) => _$GenderFromJson(json);
}

/// Breeding data shown in the detail view (RF-32).
@freezed
abstract class Breeding with _$Breeding {
  /// Creates a [Breeding].
  const factory Breeding({
    required Gender gender,
    required int eggCycles,
    @Default(<String>[]) List<String> eggGroups,
  }) = _Breeding;

  /// Deserializes a [Breeding] from cache JSON.
  factory Breeding.fromJson(Map<String, dynamic> json) =>
      _$BreedingFromJson(json);
}
