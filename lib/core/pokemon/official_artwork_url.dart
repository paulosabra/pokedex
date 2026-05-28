/// Returns the deterministic PokéAPI official-artwork URL for the given
/// National-Dex [id]. Identical to the convention already used by the
/// generations sheet's starter sprites — extracted so the skeleton search
/// result, the generation tile, and any future caller share one source.
///
/// Some alternate-form ids (≥ 10000) have no official artwork; consumers
/// should fall back to a placeholder on a 404 from the network image cache.
String officialArtworkUrl(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
    'pokemon/other/official-artwork/$id.png';
