import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/detail_header.dart';

Future<void> _pump(
  WidgetTester tester, {
  String name = 'bulbasaur',
  PokemonTypeId primary = PokemonTypeId.grass,
  VoidCallback? onBack,
}) async {
  await tester.binding.setSurfaceSize(const Size(414, 360));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: PokemonTypeTheme.styleOf(primary).backgroundColor,
        body: SafeArea(
          bottom: false,
          child: DetailHeader(
            name: name,
            onBack: onBack ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DetailHeader', () {
    testWidgets('renders the upper-cased name watermark', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('BULBASAUR'), findsOneWidget);
    });

    testWidgets('back button fires onBack callback', (tester) async {
      var pressed = 0;
      await _pump(tester, onBack: () => pressed++);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(pressed, 1);
    });

    testWidgets('golden — DetailHeader on grass background', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DetailHeader),
        matchesGoldenFile('goldens/detail_header.png'),
      );
    });
  });
}
