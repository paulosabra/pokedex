import 'package:freezed_annotation/freezed_annotation.dart';

part 'ability.freezed.dart';
part 'ability.g.dart';

/// A Pokémon ability. [isHidden] marks the hidden ability (RF-31).
@freezed
abstract class Ability with _$Ability {
  /// Creates an [Ability].
  const factory Ability({required String name, required bool isHidden}) =
      _Ability;

  /// Deserializes an [Ability] from cache JSON.
  factory Ability.fromJson(Map<String, dynamic> json) =>
      _$AbilityFromJson(json);
}
