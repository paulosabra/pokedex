import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pokemon_detail_view_model.g.dart';

/// MVVM ViewModel for the Pokémon detail screen (Tech Spec §5.2).
///
/// Family-keyed by National Dex [id] so navigating between Pokémon does not
/// leak state across instances (vm(1) and vm(4) hold independent caches).
///
/// `PokemonDetail` doubles as the screen state — there is no Freezed wrapper.
/// The plan flagged a `{detail, refreshError}` shape as conditional; PR3 has
/// no pull-to-refresh AC on the detail screen, so the second field would
/// have no consumer and the wrapper is dropped (YAGNI). Future pull-to-refresh
/// can preserve the previous value via
/// `AsyncLoading<PokemonDetail>().copyWithPrevious(state)` and surface errors
/// via `AsyncError.copyWithPrevious(state)` — the same pattern the list VM
/// uses — without re-introducing a wrapper class.
@riverpod
class PokemonDetailViewModel extends _$PokemonDetailViewModel {
  @override
  Future<PokemonDetail> build(int id) async {
    final result = await ref.read(getPokemonDetailProvider).call(id);
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
