/// Time-to-live for per-Pokémon cached data (list summaries, details, evolution
/// chains). After this window the cache is served first and revalidated in the
/// background (RN-16).
const kPokemonCacheTtl = Duration(days: 7);

/// Time-to-live for the 18 static type-relation rows. These effectively never
/// change, so they use a long TTL and must NOT expire on the 7-day Pokémon
/// clock.
const kStaticDataTtl = Duration(days: 365);

/// Time-to-live for the lightweight National-Dex index (id + name +
/// nameNormalized + generationId) that powers Search / Sort / Filters /
/// Generations across the entire catalogue. PokéAPI adds at most one
/// generation per year, so a 30-day rebuild is "soon enough" without
/// re-paying ~200 KB of JSON on every cold start.
const kPokemonIndexTtl = Duration(days: 30);
