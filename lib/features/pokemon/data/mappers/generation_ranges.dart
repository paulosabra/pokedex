/// Generation id used for National-Dex ids outside the known ranges (e.g.
/// alternate forms ≥ 10000) — graceful degradation (TE-10), not a magic 0.
const kUnknownGenerationId = 0;

/// Maps a National Dex [id] to its generation 1–9 (RN-15), or
/// [kUnknownGenerationId] when the id falls outside the released ranges.
int generationForId(int id) {
  if (id < 1) return kUnknownGenerationId;
  if (id <= 151) return 1;
  if (id <= 251) return 2;
  if (id <= 386) return 3;
  if (id <= 493) return 4;
  if (id <= 649) return 5;
  if (id <= 721) return 6;
  if (id <= 809) return 7;
  if (id <= 905) return 8;
  if (id <= 1025) return 9;
  return kUnknownGenerationId;
}
