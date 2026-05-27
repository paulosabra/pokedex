import 'package:flutter/material.dart';
import 'package:pokedex/app/layout/breakpoints.dart';

/// Helpers for adapting the app to the current viewport (Tech Spec §9.1).
///
/// Two responsibilities:
///
/// 1. Map the current breakpoint onto layout knobs (grid column count, sheet
///    vs dialog modality) for callers that want a single source of truth.
/// 2. Provide [showSheetOrDialog] — the discovery flow's modality chooser.
///    Per resolved blocker 8, the chooser **reads the breakpoint at
///    invocation time** (not via reactive listener). If the user rotates or
///    resizes mid-modal, the open modal keeps its modality; the next
///    invocation picks the new one. This avoids awkward mid-render swaps.
abstract final class ResponsiveLayout {
  const ResponsiveLayout._();

  /// The list/grid column count for the current [breakpoint].
  ///
  /// Concrete cadence per the plan AC: 1 / 2 / 3 columns at compact / medium /
  /// expanded.
  static int gridColumns(Breakpoint breakpoint) {
    return switch (breakpoint) {
      Breakpoint.compact => 1,
      Breakpoint.medium => 2,
      Breakpoint.expanded => 3,
    };
  }

  /// Shows the [builder]'s widget as a modal bottom sheet on compact
  /// viewports and as a dialog on medium/expanded viewports — Material 3's
  /// standard adaptation.
  ///
  /// The breakpoint is sampled **once**, at invocation time, from the supplied
  /// [context]. This is intentional: the open modal's modality is locked in
  /// the moment the user taps the trigger. See resolved blocker 8 in the
  /// presentation-layer plan.
  static Future<T?> showSheetOrDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final breakpoint = Breakpoint.of(context);
    if (breakpoint == Breakpoint.compact) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: builder,
      );
    }
    return showDialog<T>(context: context, builder: builder);
  }
}
