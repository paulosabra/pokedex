import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/router/route_error_screen.dart';
import 'package:pokedex/core/observability/observability_providers.dart';

import '../../helpers/recording_observability.dart';

void main() {
  group('RouteErrorScreen', () {
    testWidgets('renders the TE-03 message and a Go home CTA', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RouteErrorScreen()),
        ),
      );

      expect(find.text("This page doesn't exist."), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Go home'), findsOneWidget);
    });

    testWidgets('emits error_shown TE-03 once on mount', (tester) async {
      final analytics = RecordingAnalytics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(analytics),
          ],
          child: const MaterialApp(home: RouteErrorScreen()),
        ),
      );

      final shown = analytics.named('error_shown');
      expect(shown, hasLength(1));
      expect(shown.single.parameters, {
        'te_code': 'TE-03',
        'screen': 'route_error',
      });
    });

    testWidgets('Go home CTA navigates to /', (tester) async {
      final router = GoRouter(
        initialLocation: '/oops',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/oops',
            builder: (_, _) => const RouteErrorScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Go home'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });
}
