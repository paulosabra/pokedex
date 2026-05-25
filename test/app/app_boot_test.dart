import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/app.dart';
import 'package:pokedex/app/theme/app_colors.dart';

void main() {
  testWidgets('PokedexApp boots and composes a themed MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(const PokedexApp());

    expect(find.byType(MaterialApp), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.theme!.scaffoldBackgroundColor, AppColors.backgroundWhite);
  });
}
