/// Static defaults the discovery sheets render when the live index is not
/// available — first launch offline, persistent fetch failure, or while
/// the first `loadIfNeeded()` is in flight. Reading from a single named
/// source avoids the previous drift between `generations_sheet.dart`'s
/// `_starters` map and `filters_sheet.dart`'s `_kNumberRangeMax = 898`,
/// where each surface "knew" the catalogue bounds independently.
abstract final class IndexFallbacks {
  /// Roman-numeral labels for Generations I–IX, matching the Figma Component
  /// names (`Generation / I` .. `Generation / IX`).
  static const Map<int, String> generationLabels = {
    1: 'Generation I',
    2: 'Generation II',
    3: 'Generation III',
    4: 'Generation IV',
    5: 'Generation V',
    6: 'Generation VI',
    7: 'Generation VII',
    8: 'Generation VIII',
    9: 'Generation IX',
  };

  /// National-Dex starter trios per published generation. Used as the
  /// per-tile sample when the live index isn't available (offline first
  /// launch). Order matches the Figma sheet's left-to-right tile order.
  static const Map<int, List<int>> starterTrios = {
    1: [1, 4, 7],
    2: [152, 155, 158],
    3: [252, 255, 258],
    4: [387, 390, 393],
    5: [495, 498, 501],
    6: [650, 653, 656],
    7: [722, 725, 728],
    8: [810, 813, 816],
    9: [906, 909, 912],
  };

  /// Inclusive `[min, max]` National-Dex id range used by the Filters
  /// NumberRange slider when the live index isn't available. 898 was the
  /// catalogue ceiling at the time the slider shipped (Gen I–VIII); we
  /// keep it as the offline floor rather than bumping it to today's 1025
  /// so we never claim coverage we can't deliver offline.
  static const ({int min, int max}) numberRangeBounds = (min: 1, max: 898);

  /// Generation ids in display order — used as the tile list when the index
  /// hasn't loaded.
  static List<int> get generationIds => generationLabels.keys.toList();
}
