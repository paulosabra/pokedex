import 'package:flutter_test/flutter_test.dart';

import 'source_scanner.dart';

/// AppFailure subtypes are technical detail: views only use `userMessage`.
const _technicalFailures = [
  'NetworkFailure',
  'TimeoutFailure',
  'NotFoundFailure',
  'RateLimitFailure',
  'ServerFailure',
  'ParsingFailure',
  'UnexpectedFailure',
];

const _rules = <String, ImportRule>{
  'views/ only reach models through controllers, entities and rules':
      ImportRule(
        target: 'lib/views',
        forbidden: ['lib/models/data/', 'package:http/', 'package:sqflite/'],
      ),
  'controllers/ stay free of widgets and data sources': ImportRule(
    target: 'lib/controllers',
    forbidden: [
      'package:flutter/',
      'package:http/',
      'package:sqflite/',
      'lib/models/data/remote/',
      'lib/models/data/local/',
      'lib/views/',
    ],
    allowed: ['package:flutter/foundation.dart'],
  ),
  'cached_pokemon_repository.dart is pure Dart': ImportRule(
    target: 'lib/models/data/cached_pokemon_repository.dart',
    forbidden: [
      'package:flutter/',
      'package:sqflite/',
      'lib/controllers/',
      'lib/views/',
    ],
  ),
  'data/remote/ never touches storage or UI': ImportRule(
    target: 'lib/models/data/remote',
    forbidden: [
      'package:flutter/',
      'package:sqflite/',
      'lib/models/data/local/',
      'lib/controllers/',
      'lib/views/',
    ],
  ),
  'data/local/ never touches the network or UI': ImportRule(
    target: 'lib/models/data/local',
    forbidden: [
      'package:http/',
      'lib/models/data/remote/',
      'lib/controllers/',
      'lib/views/',
    ],
  ),
  'core/ never depends on upper layers': ImportRule(
    target: 'lib/core',
    forbidden: ['lib/controllers/', 'lib/views/', 'lib/models/data/'],
  ),
  'core/ outside theme/ is pure Dart': ImportRule(
    target: 'lib/core',
    forbidden: ['package:flutter/'],
    exemptFiles: ['lib/core/theme/'],
  ),
  'only the SQLite store and schema import sqflite': ImportRule(
    target: 'lib',
    forbidden: ['package:sqflite/'],
    exemptFiles: [
      'lib/models/data/local/sqflite_pokemon_local_store.dart',
      'lib/models/data/local/local_schema.dart',
    ],
  ),
};

/// Declares a test over [target] that is skipped until the layer exists and,
/// once it does, never passes on an empty scan.
void _layerTest(
  String description,
  String target,
  void Function(List<SourceFile> files) body,
) {
  final exists = pathExists(target);
  test(description, () {
    final files = scanDart(target);
    expect(files, isNotEmpty, reason: '$target exists but has no .dart');
    body(files);
  }, skip: exists ? false : '$target not created yet');
}

void main() {
  group('Import rules (Tech Spec §2.2)', () {
    for (final MapEntry(key: description, value: rule) in _rules.entries) {
      _layerTest(description, rule.target, (files) {
        expect(rule.violations(files), isEmpty);
      });
    }

    _layerTest('views/ never name technical AppFailure subtypes', 'lib/views', (
      files,
    ) {
      final pattern = RegExp('\\b(${_technicalFailures.join('|')})\\b');
      final offenders = [
        for (final file in files)
          for (final m in pattern.allMatches(file.code))
            '${file.path} → ${m.group(0)}',
      ];
      expect(offenders, isEmpty);
    });
  });
}
