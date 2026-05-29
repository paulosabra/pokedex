import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Thin banner shown at the top of the list when the most recent refresh
/// failed but cached items are still visible (TE-02).
///
/// Per resolved flow-refine 4, the banner is **per-screen** (list-only). The
/// detail screen carries its own stale-state hint in its header instead.
///
/// [onShown] fires exactly once, on first mount — the caller wires it to the
/// `error_shown` (TE-02) analytics event (plan §4.3), keeping this
/// design-system widget free of any observability dependency.
class StaleCacheBanner extends StatefulWidget {
  /// Creates a [StaleCacheBanner].
  const StaleCacheBanner({
    this.message = "You're offline — showing saved data.",
    this.onShown,
    super.key,
  });

  /// User-facing copy.
  final String message;

  /// Fired once on first mount so the caller can emit `error_shown` (§4.3).
  final VoidCallback? onShown;

  @override
  State<StaleCacheBanner> createState() => _StaleCacheBannerState();
}

class _StaleCacheBannerState extends State<StaleCacheBanner> {
  @override
  void initState() {
    super.initState();
    widget.onShown?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundInput,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off,
              size: 18,
              color: AppColors.textGray,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.message,
                style: AppTypography.description.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
