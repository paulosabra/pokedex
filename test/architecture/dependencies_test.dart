import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Top-level package names per pubspec section, read line by line so the
/// test needs no `yaml` package (RNF-07).
Map<String, Set<String>> parsePubspecSections(String pubspec) {
  final sections = <String, Set<String>>{};
  final topLevel = RegExp(r'^([A-Za-z_]\w*):');
  final entry = RegExp(r'^( +)([A-Za-z_]\w*):');
  String? current;
  int? entryIndent;
  for (final line in pubspec.split('\n')) {
    final withoutComment = line.split('#').first.trimRight();
    if (withoutComment.isEmpty) continue;
    final section = topLevel.firstMatch(withoutComment);
    if (section != null) {
      current = section.group(1);
      sections[current!] = {};
      entryIndent = null;
      continue;
    }
    final package = entry.firstMatch(withoutComment);
    if (current == null || package == null) continue;
    final indent = package.group(1)!.length;
    entryIndent ??= indent;
    if (indent == entryIndent) sections[current]!.add(package.group(2)!);
  }
  return sections;
}

void main() {
  group('parsePubspecSections', () {
    test('reads direct entries only, ignoring nesting and comments', () {
      const pubspec = '''
name: demo
dependencies:
  flutter:
    sdk: flutter # nested key is not a package
  http: ^1.0.0
#  commented_out: ^1.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
''';

      final sections = parsePubspecSections(pubspec);

      expect(sections['dependencies'], {'flutter', 'http'});
      expect(sections['dev_dependencies'], {'flutter_test'});
    });
  });

  test('parsePubspecSections follows any consistent indentation', () {
    const pubspec = '''
dependencies:
    flutter:
        sdk: flutter
    http: ^1.0.0
dev_dependencies:
    mockito: ^5.0.0
''';

    final sections = parsePubspecSections(pubspec);

    expect(sections['dependencies'], {'flutter', 'http'});
    expect(sections['dev_dependencies'], {'mockito'});
  });

  group('pubspec.yaml (RNF-07, Tech Spec §11)', () {
    final sections = parsePubspecSections(
      File('pubspec.yaml').readAsStringSync(),
    );

    test('runtime dependencies are exactly the approved set', () {
      expect(sections['dependencies'], {
        'flutter',
        'provider',
        'http',
        'logging',
        'sqflite',
        'path',
      });
    });

    test('dev dependencies stay within the approved set', () {
      expect(
        sections['dev_dependencies'],
        everyElement(
          isIn(const {'flutter_test', 'flutter_lints', 'sqflite_common_ffi'}),
        ),
      );
    });

    test('no dependency overrides sneak packages in', () {
      expect(sections.containsKey('dependency_overrides'), isFalse);
    });
  });
}
