/// Shared string helpers.
abstract final class StringUtils {
  const StringUtils._();

  /// Returns [value] with its first code unit upper-cased. PokéAPI ships
  /// names lower-cased (e.g. `bulbasaur`); the UI displays them title-cased.
  static String capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
