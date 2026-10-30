import 'package:flutter_test/flutter_test.dart';

import 'source_scanner.dart';

SourceFile _file(String source, {String path = 'lib/views/a/page.dart'}) =>
    SourceFile(path: path, source: source);

void main() {
  group('stripComments', () {
    test('removes line, doc and nested block comments', () {
      const source = '''
// line
/// doc
int a = 1; // trailing
/* block /* nested */ still comment */ int b = 2;
''';

      final code = stripComments(source);

      expect(code, isNot(contains('line')));
      expect(code, isNot(contains('doc')));
      expect(code, isNot(contains('nested')));
      expect(code, isNot(contains('still')));
      expect(code, contains('int a = 1;'));
      expect(code, contains('int b = 2;'));
    });

    test('keeps line breaks of removed block comments', () {
      expect('\n'.allMatches(stripComments('/*\n\n*/x')).length, 2);
    });

    test('keeps comment markers inside string literals', () {
      const source = r'''
final url = 'https://pokeapi.co/api/v2'; // gone
final raw = r'C:\dir\' + "/* not a comment */";
final multi = """
// still a string
""";
''';

      final code = stripComments(source);

      expect(code, contains("'https://pokeapi.co/api/v2'"));
      expect(code, contains('"/* not a comment */"'));
      expect(code, contains('// still a string'));
      expect(code, isNot(contains('gone')));
    });
  });

  group('SourceFile.imports', () {
    test('detects real imports and exports', () {
      final file = _file('''
import 'package:flutter/material.dart';
import "package:http/http.dart" as http;
export 'widgets/card.dart';
''');

      expect(file.imports, [
        'package:flutter/material.dart',
        'package:http/http.dart',
        'lib/views/a/widgets/card.dart',
      ]);
    });

    test('ignores imports cited in comments', () {
      final file = _file('''
// import 'package:sqflite/sqflite.dart';
/// Do not `import 'package:http/http.dart'` here.
/*
import 'package:pokedex/models/data/cached_pokemon_repository.dart';
*/
import 'package:flutter/widgets.dart';
''');

      expect(file.imports, ['package:flutter/widgets.dart']);
    });

    test('includes every URI of a conditional import', () {
      final file = _file('''
import 'stub.dart'
    if (dart.library.io) 'package:sqflite/sqflite.dart'
    if (dart.library.js_interop) 'web.dart';
''');

      expect(file.imports, [
        'lib/views/a/stub.dart',
        'package:sqflite/sqflite.dart',
        'lib/views/a/web.dart',
      ]);
    });

    test('keeps scanning past metadata and semicolons inside URIs', () {
      final file = _file('''
@Deprecated('use (b)')
library;

@Deprecated('old')
import 'odd;name.dart';
import 'package:sqflite/sqflite.dart';
''');

      expect(file.imports, [
        'lib/views/a/odd;name.dart',
        'package:sqflite/sqflite.dart',
      ]);
    });

    test('ignores import-like lines in string literals after the header', () {
      final file = _file('''
library;

import 'package:flutter/widgets.dart' show Text;

const sample = """
import 'package:sqflite/sqflite.dart';
""";
''');

      expect(file.imports, ['package:flutter/widgets.dart']);
    });

    test('resolves package:pokedex and relative URIs to lib/ paths', () {
      final file = _file('''
import 'package:pokedex/core/errors/result.dart';
import '../../models/entities/sort_order.dart';
import 'dart:async';
''');

      expect(file.imports, [
        'lib/core/errors/result.dart',
        'lib/models/entities/sort_order.dart',
        'dart:async',
      ]);
    });
  });

  group('ImportRule.violations', () {
    final files = [
      _file(
        "import 'package:pokedex/models/data/pokemon_repository.dart';",
        path: 'lib/controllers/a.dart',
      ),
      _file(
        "import 'package:flutter/foundation.dart';",
        path: 'lib/controllers/b.dart',
      ),
      _file(
        "import 'package:flutter/material.dart';",
        path: 'lib/controllers/c.dart',
      ),
    ];

    test('flags forbidden prefixes, honouring allowed and exempt files', () {
      const rule = ImportRule(
        target: 'lib/controllers',
        forbidden: ['package:flutter/', 'lib/models/data/remote/'],
        allowed: ['package:flutter/foundation.dart'],
      );

      expect(rule.violations(files), [
        'lib/controllers/c.dart → package:flutter/material.dart',
      ]);
    });

    test('skips files under exemptFiles', () {
      const rule = ImportRule(
        target: 'lib/controllers',
        forbidden: ['package:flutter/'],
        exemptFiles: ['lib/controllers/c.dart'],
      );

      expect(rule.violations(files), [
        'lib/controllers/b.dart → package:flutter/foundation.dart',
      ]);
    });
  });

  test('scanDart returns nothing for a missing path', () {
    expect(scanDart('lib/does_not_exist'), isEmpty);
    expect(pathExists('lib/does_not_exist'), isFalse);
  });

  test('scanDart loads a single file and a directory recursively', () {
    expect(scanDart('lib/main.dart').single.path, 'lib/main.dart');
    expect(
      scanDart('lib/core').map((f) => f.path),
      containsAll([
        'lib/core/errors/result.dart',
        'lib/core/logging/loggers.dart',
      ]),
    );
  });
}
