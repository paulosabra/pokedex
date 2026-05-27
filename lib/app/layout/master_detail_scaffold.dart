import 'package:flutter/material.dart';
import 'package:pokedex/app/layout/breakpoints.dart';
import 'package:pokedex/app/theme/app_colors.dart';

/// Renders [child] full-width on compact / medium viewports, or alongside a
/// master panel (built by [masterBuilder]) on expanded viewports (RF-46).
///
/// The plan's default approach is "wrap, don't rewrite the router" — so the
/// pattern lives inside the screen-specific build (e.g. the detail screen
/// wraps its body so that on expanded viewports the master panel becomes the
/// list screen, and on compact the detail body renders alone since the user
/// navigated into a detail route on a small viewport).
///
/// Stateless: the route stays the source of truth for "which Pokémon is
/// selected"; this scaffold just composes panels.
class MasterDetailScaffold extends StatelessWidget {
  /// Creates a [MasterDetailScaffold].
  const MasterDetailScaffold({
    required this.child,
    required this.masterBuilder,
    super.key,
  });

  /// The screen-specific content (e.g. the detail body). Always rendered;
  /// becomes the right panel on expanded viewports.
  final Widget child;

  /// Builds the master panel (e.g. the Pokémon list). Only invoked on
  /// expanded viewports.
  final WidgetBuilder masterBuilder;

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.of(context);
    if (breakpoint != Breakpoint.expanded) return child;
    // 40/60 master/detail split — Material 3's standard list-detail
    // proportion. Hardcoded because there's only one call site; if a second
    // surface needs a different split, the constants graduate to params then.
    return Row(
      children: [
        Expanded(flex: 2, child: Builder(builder: masterBuilder)),
        const VerticalDivider(width: 1, color: AppColors.backgroundInput),
        Expanded(flex: 3, child: child),
      ],
    );
  }
}
