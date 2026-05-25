import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';

/// Builds a summaries upsert companion from a [Pokemon] entity plus the derived
/// columns the SQL search/filter needs ([heightDecimetres], [weaknessMask]).
/// The entity itself is stored as JSON in `payloadJson`.
PokemonSummariesCompanion summaryToCompanion(
  Pokemon pokemon, {
  required int heightDecimetres,
  required int weaknessMask,
  required int nowMs,
}) => PokemonSummariesCompanion.insert(
  id: Value(pokemon.id),
  name: pokemon.name,
  nameNormalized: normalizeName(pokemon.name),
  primaryTypeId: pokemon.types.isEmpty ? 0 : pokemon.types.first.index,
  generationId: pokemon.generationId,
  height: heightDecimetres,
  payloadJson: jsonEncode(pokemon.toJson()),
  updatedAt: nowMs,
  secondaryTypeId: Value(
    pokemon.types.length > 1 ? pokemon.types[1].index : null,
  ),
  weaknessMask: Value(weaknessMask),
);

/// Decodes a [Pokemon] from a cached summary row's `payloadJson`.
Pokemon pokemonFromRow(PokemonSummaryRow row) =>
    Pokemon.fromJson(jsonDecode(row.payloadJson) as Map<String, dynamic>);

/// Builds a details upsert companion from a [PokemonDetail] entity.
PokemonDetailsCompanion detailToCompanion(
  PokemonDetail detail, {
  required int nowMs,
}) => PokemonDetailsCompanion.insert(
  id: Value(detail.summary.id),
  payloadJson: jsonEncode(detail.toJson()),
  updatedAt: nowMs,
);

/// Decodes a [PokemonDetail] from a cached detail row's `payloadJson`.
PokemonDetail detailFromRow(PokemonDetailRow row) =>
    PokemonDetail.fromJson(jsonDecode(row.payloadJson) as Map<String, dynamic>);

/// Builds an evolution-chain upsert companion keyed by [chainId].
EvolutionChainsCompanion evolutionToCompanion(
  int chainId,
  EvolutionChain chain, {
  required int nowMs,
}) => EvolutionChainsCompanion.insert(
  chainId: Value(chainId),
  payloadJson: jsonEncode(chain.toJson()),
  updatedAt: nowMs,
);

/// Decodes an [EvolutionChain] from a cached evolution row's `payloadJson`.
EvolutionChain evolutionFromRow(EvolutionChainRow row) =>
    EvolutionChain.fromJson(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );

/// Builds a type-relations upsert companion, keyed by [PokemonTypeId.index].
/// The damage relations are stored as JSON in `payloadJson`.
TypeRelationsCompanion typeRelationToCompanion(
  PokemonTypeId type,
  DamageRelationsDto relations, {
  required int nowMs,
}) => TypeRelationsCompanion.insert(
  typeId: Value(type.index),
  payloadJson: jsonEncode(relations.toJson()),
  updatedAt: nowMs,
);

/// Decodes a [DamageRelationsDto] from a cached type-relations row.
DamageRelationsDto damageRelationsFromRow(TypeRelationRow row) =>
    DamageRelationsDto.fromJson(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
