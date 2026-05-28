import 'package:drift/drift.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/pokemon/official_artwork_url.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/generation_ranges.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';

/// Builds index upsert companions from a single `/pokemon?limit=∞` response.
/// Every row shares [nowMs] so the snapshot timestamp is column-level
/// (`MAX(indexed_at)` returns the snapshot clock without per-row variance).
List<PokemonIndexCompanion> indexFromResponse(
  PokemonListResponseDto dto, {
  required int nowMs,
}) {
  final companions = <PokemonIndexCompanion>[];
  for (final resource in dto.results) {
    final id = resource.idFromUrl;
    if (id == null) continue;
    companions.add(
      PokemonIndexCompanion.insert(
        id: Value(id),
        name: resource.name,
        nameNormalized: normalizeName(resource.name),
        generationId: generationForId(id),
        indexedAt: nowMs,
      ),
    );
  }
  return companions;
}

/// Lifts an index row into the [Pokemon] entity that the UI already knows
/// how to render. The skeleton-vs-hydrated distinction reads off
/// `types.isEmpty`: a presentation card can render shimmer chips for the
/// skeleton variant without needing a new entity shape.
Pokemon skeletonFromIndexRow(PokemonIndexRow row) => Pokemon(
  id: row.id,
  name: row.name,
  imageUrl: officialArtworkUrl(row.id),
  generationId: row.generationId,
);
