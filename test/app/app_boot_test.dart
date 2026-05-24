import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/app.dart';

void main() {
  testWidgets('PokedexApp boots and composes a MaterialApp', (tester) async {
    await tester.pumpWidget(const PokedexApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
