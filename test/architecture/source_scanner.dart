import 'dart:io';

import 'package:path/path.dart' as p;

const _packagePrefix = 'package:pokedex/';

/// A Dart file under `lib/` with comments removed and its imports resolved.
final class SourceFile {
  SourceFile({required this.path, required String source})
    : code = stripComments(source) {
    imports = extractImports(code)
        .map((uri) => resolveImport(path, uri))
        .toList();
  }

  /// Repository-relative POSIX path, e.g. `lib/views/pokedex/pokedex_page.dart`.
  final String path;

  /// Source without comments, so identifiers and imports cited in docs never
  /// count.
  final String code;

  /// `import`/`export` targets: `lib/...` for this package, the raw URI for
  /// `dart:` and third-party packages.
  late final List<String> imports;
}

/// Loads every `.dart` file at [path] (a file or a directory, recursively).
/// Returns an empty list when [path] does not exist.
List<SourceFile> scanDart(String path) {
  final List<File> files;
  if (FileSystemEntity.isFileSync(path)) {
    files = [File(path)];
  } else if (FileSystemEntity.isDirectorySync(path)) {
    files = Directory(path)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  } else {
    return const [];
  }
  return [
    for (final file in files..sort((a, b) => a.path.compareTo(b.path)))
      SourceFile(
        path: p.posix.joinAll(p.split(p.normalize(file.path))),
        source: file.readAsStringSync(),
      ),
  ];
}

bool pathExists(String path) =>
    FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+r?(['"])(.+?)\1''',
  multiLine: true,
);

List<String> extractImports(String code) => [
  for (final m in _directive.allMatches(code)) m.group(2)!,
];

/// Maps `package:pokedex/x.dart` and relative URIs to `lib/x.dart`.
String resolveImport(String fromPath, String uri) {
  if (uri.startsWith(_packagePrefix)) {
    return 'lib/${uri.substring(_packagePrefix.length)}';
  }
  if (uri.contains(':')) return uri;
  return p.posix.normalize(p.posix.join(p.posix.dirname(fromPath), uri));
}

/// Removes `//` and (nested) `/* */` comments, leaving string literals intact
/// and keeping line breaks so line numbers stay stable.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;

  bool startsAt(String token, int at) => source.startsWith(token, at);

  while (i < n) {
    if (startsAt('//', i)) {
      while (i < n && source[i] != '\n') {
        i++;
      }
    } else if (startsAt('/*', i)) {
      var depth = 0;
      while (i < n) {
        if (startsAt('/*', i)) {
          depth++;
          i += 2;
        } else if (startsAt('*/', i)) {
          depth--;
          i += 2;
          if (depth == 0) break;
        } else {
          if (source[i] == '\n') out.write('\n');
          i++;
        }
      }
    } else if (source[i] == "'" || source[i] == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final quote = source[i];
      final triple = startsAt(quote * 3, i);
      final delimiter = triple ? quote * 3 : quote;
      final start = i;
      i += delimiter.length;
      while (i < n && !startsAt(delimiter, i)) {
        if (!raw && source[i] == r'\') i++;
        if (!triple && i < n && source[i] == '\n') break;
        i++;
      }
      i += delimiter.length;
      out.write(source.substring(start, i.clamp(0, n)));
    } else {
      out.write(source[i]);
      i++;
    }
  }
  return out.toString();
}

/// One row of the dependency table (Tech Spec §2.2).
final class ImportRule {
  const ImportRule({
    required this.target,
    required this.forbidden,
    this.allowed = const [],
    this.exemptFiles = const [],
  });

  /// File or directory under `lib/` the rule applies to.
  final String target;

  /// Import prefixes the target must not use.
  final List<String> forbidden;

  /// Exact imports allowed even though they match a [forbidden] prefix.
  final List<String> allowed;

  /// Path prefixes inside [target] excluded from the rule.
  final List<String> exemptFiles;

  /// `file → import` for every violating import in [files].
  List<String> violations(Iterable<SourceFile> files) => [
    for (final file in files)
      if (!exemptFiles.any(file.path.startsWith))
        for (final import in file.imports)
          if (forbidden.any(import.startsWith) && !allowed.contains(import))
            '${file.path} → $import',
  ];
}
