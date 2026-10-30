/// Display rules shared by entities and views (RN-02, RN-03, RN-11..13,
/// RN-15). Pure functions, `en` locale (D8).
abstract final class PokemonFormat {
  static const missing = '—';

  /// Theoretical maximum base stat; the stat bar is relative to it.
  static const maxStat = 255;

  static const _nameExceptions = {
    'nidoran-f': 'Nidoran♀',
    'nidoran-m': 'Nidoran♂',
    'mr-mime': 'Mr. Mime',
    'farfetchd': 'Farfetch’d',
  };

  static final _flavorBreaks = RegExp('[\n\f\u00AD]');
  static final _whitespace = RegExp(r'\s+');

  /// RN-02: `4` → `#004`.
  static String number(int id) => '#${_pad3(id)}';

  /// RN-03: capitalised API name, with the Gen 1 exceptions.
  static String displayName(String apiName) =>
      _nameExceptions[apiName] ?? _capitalize(apiName);

  /// RN-11: hectograms → `6.9 kg`.
  static String weightKg(int? hg) => _tenths(hg, 'kg');

  /// RN-11: decimetres → `0.7 m`.
  static String heightM(int? dm) => _tenths(dm, 'm');

  /// RN-12: `solar-power` → `Solar Power`.
  static String abilityName(String apiName) =>
      apiName.split('-').map(_capitalize).join(' ');

  /// RN-15: `45` → `045`.
  static String statValue(int value) => _pad3(value < 0 ? 0 : value);

  /// RN-15: bar width in [0, 1].
  static double statFraction(int value) =>
      (value / maxStat).clamp(0.0, 1.0).toDouble();

  /// RN-13: line breaks, form feeds and soft hyphens become spaces, then
  /// whitespace is collapsed.
  static String flavorText(String raw) =>
      raw.replaceAll(_flavorBreaks, ' ').replaceAll(_whitespace, ' ').trim();

  static String _pad3(int value) => value.toString().padLeft(3, '0');

  static String _capitalize(String word) =>
      word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

  static String _tenths(int? value, String unit) =>
      value == null ? missing : '${(value / 10).toStringAsFixed(1)} $unit';
}
