import 'package:freezed_annotation/freezed_annotation.dart';

part 'stat_set.freezed.dart';
part 'stat_set.g.dart';

/// A single base stat with its level-100 [min]/[max] range (RN-12).
@freezed
abstract class StatValue with _$StatValue {
  /// Creates a [StatValue].
  const factory StatValue({
    required int base,
    required int min,
    required int max,
  }) = _StatValue;

  /// Deserializes a [StatValue] from cache JSON.
  factory StatValue.fromJson(Map<String, dynamic> json) =>
      _$StatValueFromJson(json);
}

/// The six base stats of a Pokémon (RF-35…37).
@freezed
abstract class StatSet with _$StatSet {
  /// Creates a [StatSet].
  const factory StatSet({
    required StatValue hp,
    required StatValue attack,
    required StatValue defense,
    required StatValue specialAttack,
    required StatValue specialDefense,
    required StatValue speed,
  }) = _StatSet;

  const StatSet._();

  /// Deserializes a [StatSet] from cache JSON.
  factory StatSet.fromJson(Map<String, dynamic> json) =>
      _$StatSetFromJson(json);

  /// The sum of the six base stat values (RF-37).
  int get total =>
      hp.base +
      attack.base +
      defense.base +
      specialAttack.base +
      specialDefense.base +
      speed.base;
}
