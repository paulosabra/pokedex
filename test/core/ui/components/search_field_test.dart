import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/components/search_field.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  group('SearchField', () {
    testWidgets('renders the hint when the field is empty', (tester) async {
      await _pump(tester, const SearchField(hintText: 'Search Pokémon'));

      expect(find.text('Search Pokémon'), findsOneWidget);
    });

    testWidgets('fires onChanged with each keystroke', (tester) async {
      final received = <String>[];
      await _pump(tester, SearchField(onChanged: received.add));

      await tester.enterText(find.byType(TextField), 'pika');

      expect(received, contains('pika'));
    });

    testWidgets('binds to the provided controller', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(tester, SearchField(controller: controller));
      await tester.enterText(find.byType(TextField), 'mew');

      expect(controller.text, 'mew');
    });

    testWidgets('fires onSubmitted when the user submits', (tester) async {
      String? submitted;
      await _pump(
        tester,
        SearchField(onSubmitted: (value) => submitted = value),
      );

      await tester.enterText(find.byType(TextField), 'snorlax');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(submitted, 'snorlax');
    });

    testWidgets('default golden — empty', (tester) async {
      await _pump(tester, const SearchField());
      await expectLater(
        find.byType(SearchField),
        matchesGoldenFile('goldens/search_field_default.png'),
      );
    });

    testWidgets('filled golden', (tester) async {
      final controller = TextEditingController(text: 'Pikachu');
      addTearDown(controller.dispose);
      await _pump(tester, SearchField(controller: controller));
      await expectLater(
        find.byType(SearchField),
        matchesGoldenFile('goldens/search_field_filled.png'),
      );
    });
  });
}
