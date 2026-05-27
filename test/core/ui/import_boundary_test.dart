import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard against upward dependencies from the design system into
/// feature code. Convention rots; this test fails the build the moment a
/// `lib/core/ui/**` file grows a `package:pokedex/features/**` import.
void main() {
  test('lib/core/ui/** does not import from features/', () {
    final root = Directory('lib/core/ui');
    expect(
      root.existsSync(),
      isTrue,
      reason: 'expected lib/core/ui to exist for the design system',
    );

    final offenders = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('import') &&
            line.contains('package:pokedex/features/')) {
          offenders.add('${entity.path}:${i + 1} → $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Design-system files must not import feature code. Offending lines:\n'
          '${offenders.join('\n')}',
    );
  });
}
