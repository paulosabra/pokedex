import 'package:flutter/material.dart';
import 'package:pokedex/core/ui/states/state_view.dart';

/// Generic error fallback (TE-03/06/07/09).
///
/// Used for non-connectivity failures — 404, timeout, 5xx, parsing — where the
/// recovery path is "retry the request". Stays deliberately generic; specific
/// failure types get their own widget when the recovery flow differs (e.g.
/// the offline-error widget gives no retry hope when the device itself is
/// offline with no cache).
class GenericErrorWidget extends StatelessWidget {
  /// Creates a [GenericErrorWidget].
  const GenericErrorWidget({
    required this.onRetry,
    this.message = 'Something went wrong. Please try again.',
    this.retryLabel = 'Retry',
    super.key,
  });

  /// User-facing copy. Defaulted; callers may pass a more specific message
  /// (e.g. "We couldn't load this Pokémon").
  final String message;

  /// CTA label. Defaults to "Retry"; the detail screen overrides to "Back".
  final String retryLabel;

  /// Fires on the CTA tap.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StateView(
      glyph: Icons.error_outline,
      title: 'Something went wrong',
      body: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}
