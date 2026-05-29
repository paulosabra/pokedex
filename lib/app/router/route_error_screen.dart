import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/core/ui/states/generic_error_widget.dart';

/// Full-screen **TE-03** page for an unreachable route (C-1).
///
/// Reached two ways once the SPA rewrite (T-31) serves `index.html` for every
/// path: a `/pokemon/:id` segment that is not a valid int (the router's
/// `int.tryParse` returns null), or any path that matches no route (GoRouter's
/// `errorBuilder`). Both are "not found", so both land here.
///
/// Emits `error_shown` once on mount (PRD §12 / §4.3), consistent with the
/// other full-screen error states, and offers a single "Go home" affordance
/// since there may be nothing on the back stack to pop to (deep link).
class RouteErrorScreen extends ConsumerWidget {
  /// Creates a [RouteErrorScreen].
  const RouteErrorScreen({super.key});

  /// `screen` property attached to this route's `error_shown` event.
  static const String _screenName = 'route_error';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No explicit backgroundColor — AppTheme.light already sets
    // scaffoldBackgroundColor to the app's white surface.
    return Scaffold(
      body: GenericErrorWidget(
        message: "This page doesn't exist.",
        retryLabel: 'Go home',
        onRetry: () => context.go('/'),
        onShown: () => ref
            .read(analyticsServiceProvider)
            .logEvent(
              const ErrorShown(teCode: 'TE-03', screen: _screenName),
            ),
      ),
    );
  }
}
