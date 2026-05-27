import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.textGray,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.description,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: AppColors.textWhite,
              ),
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
