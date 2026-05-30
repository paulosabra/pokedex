import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';

part 'pokemon_page.freezed.dart';

/// One page of the paginated Pokémon list (RN-14). [hasMore] is true while the
/// API reports a next page. Not cached, so it carries no JSON serialization.
@freezed
abstract class PokemonPage with _$PokemonPage {
  /// Creates a [PokemonPage].
  const factory PokemonPage({
    required bool hasMore,
    @Default(<Pokemon>[]) List<Pokemon> items,
  }) = _PokemonPage;
}
