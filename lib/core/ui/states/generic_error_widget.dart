import 'package:flutter/material.dart';
import 'package:pokedex/core/ui/states/state_view.dart';

/// Generic error fallback (TE-03/06/07/09).
///
/// Used for non-connectivity failures — 404, timeout, 5xx, parsing — where the
/// recovery path is "retry the request". Stays deliberately generic; specific
/// failure types get their own widget when the recovery flow differs (e.g.
/// the offline-error widget gives no retry hope when the device itself is
/// offline with no cache).
///
/// [onShown] fires exactly once, on first mount — the caller wires it to the
/// `error_shown` analytics event (plan §4.3), keeping this design-system widget
/// free of any observability dependency.
class GenericErrorWidget extends StatefulWidget {
  /// Creates a [GenericErrorWidget].
  const GenericErrorWidget({
    required this.onRetry,
    this.message = 'Something went wrong. Please try again.',
    this.retryLabel = 'Retry',
    this.onShown,
    super.key,
  });

  /// User-facing copy. Defaulted; callers may pass a more specific message
  /// (e.g. "We couldn't load this Pokémon").
  final String message;

  /// CTA label. Defaults to "Retry"; the detail screen overrides to "Back".
  final String retryLabel;

  /// Fires on the CTA tap.
  final VoidCallback onRetry;

  /// Fired once on first mount so the caller can emit `error_shown` (§4.3).
  final VoidCallback? onShown;

  @override
  State<GenericErrorWidget> createState() => _GenericErrorWidgetState();
}

class _GenericErrorWidgetState extends State<GenericErrorWidget> {
  @override
  void initState() {
    super.initState();
    widget.onShown?.call();
  }

  @override
  Widget build(BuildContext context) {
    return StateView(
      glyph: Icons.error_outline,
      title: 'Something went wrong',
      body: widget.message,
      actionLabel: widget.retryLabel,
      onAction: widget.onRetry,
    );
  }
}
