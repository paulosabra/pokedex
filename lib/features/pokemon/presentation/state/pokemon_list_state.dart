import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

part 'pokemon_list_state.freezed.dart';

/// The single Freezed state owned by the Home ViewModel. Tech Spec §5.2 keeps
/// the entire Home state in one immutable record so search, filter, sort, and
/// pagination intersect in a single source of truth (RN-08).
///
/// [refreshError] surfaces a failed pull-to-refresh (TE-02) while [items]
/// still holds the previous cache snapshot.
@freezed
abstract class PokemonListState with _$PokemonListState {
  /// Creates a [PokemonListState].
  const factory PokemonListState({
    @Default(<Pokemon>[]) List<Pokemon> items,
    @Default(0) int offset,
    @Default(true) bool hasMore,
    @Default(false) bool isLoadingMore,
    @Default(false) bool isRefreshing,
    @Default('') String query,
    PokemonFilter? filter,
    @Default(SortCriteria.numberAsc) SortCriteria sort,
    int? generationId,
    Failure? refreshError,
  }) = _PokemonListState;

  /// Private const so [isDiscovery] can be defined as a derived getter on the
  /// generated class.
  const PokemonListState._();

  /// `true` when any user-driven discovery axis is active (RN-08). Browse mode
  /// is "all defaults"; anything else is discovery and runs through
  /// `findPokemon` instead of the watch stream.
  bool get isDiscovery =>
      query.isNotEmpty ||
      filter != null ||
      sort != SortCriteria.numberAsc ||
      generationId != null;
}
