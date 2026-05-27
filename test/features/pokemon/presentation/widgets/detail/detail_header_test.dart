import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/detail_header.dart';

Future<void> _pump(
  WidgetTester tester, {
  String imageUrl = '',
  PokemonTypeId primary = PokemonTypeId.grass,
  PokemonTypeId? secondary = PokemonTypeId.poison,
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
            id: 1,
            name: 'bulbasaur',
            primaryType: primary,
            secondaryType: secondary,
            imageUrl: imageUrl,
            onBack: onBack ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DetailHeader', () {
    testWidgets('renders id, capitalized name, and both type badges', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('#001'), findsOneWidget);
      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.byType(TypeBadge), findsNWidgets(2));
    });

    testWidgets('omits the secondary badge for mono-type Pokémon', (
      tester,
    ) async {
      await _pump(tester, secondary: null);
      await tester.pumpAndSettle();

      expect(find.byType(TypeBadge), findsOneWidget);
    });

    testWidgets('renders the TE-11 placeholder when imageUrl is empty', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
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
