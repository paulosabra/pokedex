import 'package:flutter/material.dart';
import 'package:pokedex/core/ui/states/state_view.dart';

/// Full-screen offline error block (TE-01).
///
/// Renders when the user is offline AND no cache is available — there is no
/// data to fall back on, so the screen surfaces this widget instead of any
/// list/detail body. The CTA fires [onRetry], which the caller wires to the
/// view-model's refresh intent.
class OfflineErrorWidget extends StatelessWidget {
  /// Creates an [OfflineErrorWidget].
  const OfflineErrorWidget({
    required this.onRetry,
    this.message =
        "You're offline and no Pokémon are cached. "
        'Check your connection and try again.',
    this.retryLabel = 'Retry',
    super.key,
  });

  /// User-facing copy. Defaulted to the canonical TE-01 message; callers may
  /// pass a screen-specific variant (e.g. detail uses "this Pokémon is not
  /// cached" wording in the screen's local error path).
  final String message;

  /// CTA label. Defaults to "Retry" for the list path; the detail screen
  /// overrides to "Back" because there's nothing to retry when the device
  /// itself is offline with no cached entry for the route.
  final String retryLabel;

  /// Fires when the user taps the CTA. Usually wired to the VM refresh, but
  /// the detail screen wires it to `context.pop()` instead.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StateView(
      glyph: Icons.cloud_off,
      title: "You're offline",
      body: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}
