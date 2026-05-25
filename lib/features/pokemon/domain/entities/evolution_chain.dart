import 'package:freezed_annotation/freezed_annotation.dart';

part 'evolution_chain.freezed.dart';
part 'evolution_chain.g.dart';

/// One stage in an evolution line. [condition] is a human-readable trigger
/// (e.g. "Level 16", "Use Water Stone") or null for the base stage (RN-13).
@freezed
abstract class EvolutionStage with _$EvolutionStage {
  /// Creates an [EvolutionStage].
  const factory EvolutionStage({
    required int id,
    required String name,
    required String imageUrl,
    String? condition,
  }) = _EvolutionStage;

  /// Deserializes an [EvolutionStage] from cache JSON.
  factory EvolutionStage.fromJson(Map<String, dynamic> json) =>
      _$EvolutionStageFromJson(json);
}

/// A node in the evolution tree. [evolvesTo] makes the structure recursive so
/// branching lines (e.g. Eevee) are represented faithfully (RN-13).
@freezed
abstract class EvolutionNode with _$EvolutionNode {
  /// Creates an [EvolutionNode].
  const factory EvolutionNode({
    required EvolutionStage stage,
    @Default(<EvolutionNode>[]) List<EvolutionNode> evolvesTo,
  }) = _EvolutionNode;

  /// Deserializes an [EvolutionNode] from cache JSON.
  factory EvolutionNode.fromJson(Map<String, dynamic> json) =>
      _$EvolutionNodeFromJson(json);
}

/// A Pokémon's full evolution tree, rooted at the base stage (RN-13).
@freezed
abstract class EvolutionChain with _$EvolutionChain {
  /// Creates an [EvolutionChain].
  const factory EvolutionChain({required EvolutionNode root}) = _EvolutionChain;

  /// Deserializes an [EvolutionChain] from cache JSON.
  factory EvolutionChain.fromJson(Map<String, dynamic> json) =>
      _$EvolutionChainFromJson(json);
}
