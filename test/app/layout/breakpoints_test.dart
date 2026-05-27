import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/layout/breakpoints.dart';

void main() {
  group('Breakpoint.fromWidth', () {
    test('599 logical px → compact', () {
      expect(Breakpoint.fromWidth(599), Breakpoint.compact);
    });

    test('600 logical px → medium (medium threshold is inclusive)', () {
      expect(Breakpoint.fromWidth(600), Breakpoint.medium);
    });

    test('1023 logical px → medium', () {
      expect(Breakpoint.fromWidth(1023), Breakpoint.medium);
    });

    test('1024 logical px → expanded (expanded threshold is inclusive)', () {
      expect(Breakpoint.fromWidth(1024), Breakpoint.expanded);
    });

    test('2000 logical px → expanded', () {
      expect(Breakpoint.fromWidth(2000), Breakpoint.expanded);
    });
  });

  group('Breakpoint.of', () {
    testWidgets('reads from the nearest MediaQuery', (tester) async {
      late Breakpoint observed;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Builder(
            builder: (context) {
              observed = Breakpoint.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(observed, Breakpoint.medium);
    });
  });
}
