import 'package:freezed_annotation/freezed_annotation.dart';

part 'training.freezed.dart';
part 'training.g.dart';

/// Training-related stats shown in the detail view (RF-38).
@freezed
abstract class Training with _$Training {
  /// Creates a [Training].
  const factory Training({
    required String evYield,
    required int catchRate,
    required int baseFriendship,
    required String growthRate,
    int? baseExp,
  }) = _Training;

  /// Deserializes a [Training] from cache JSON.
  factory Training.fromJson(Map<String, dynamic> json) =>
      _$TrainingFromJson(json);
}
