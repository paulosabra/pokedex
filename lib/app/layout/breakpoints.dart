import 'package:flutter/widgets.dart';

/// Responsive breakpoint categories (Tech Spec §9.1).
///
/// Mirror of Material 3's "Window size class" buckets:
///
/// - **compact**:   width < 600  — phones in portrait
/// - **medium**:    600 ≤ width < 1024 — phones in landscape, small tablets
/// - **expanded**:  width ≥ 1024 — large tablets, desktop, web
enum Breakpoint {
  /// Phones in portrait.
  compact,

  /// Phones in landscape and small tablets.
  medium,

  /// Large tablets, desktop, and web.
  expanded;

  /// Maps a logical width in pixels onto a [Breakpoint].
  ///
  /// Exposed as a static helper so unit tests can pin the threshold contract
  /// without spinning up a widget tree.
  static Breakpoint fromWidth(double width) {
    if (width < Breakpoints.medium) return Breakpoint.compact;
    if (width < Breakpoints.expanded) return Breakpoint.medium;
    return Breakpoint.expanded;
  }

  /// Reads the breakpoint from the nearest [MediaQuery].
  static Breakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}

/// Numeric thresholds that define the boundaries between breakpoints.
///
/// `compact -> medium` flips at [medium]; `medium -> expanded` flips at
/// [expanded]. Kept in a single file so a future tweak to the contract (e.g.
/// shifting "large phone landscape" up to a higher threshold) touches one
/// place.
abstract final class Breakpoints {
  /// First width that is no longer considered "compact" (≥ 600 logical px).
  static const double medium = 600;

  /// First width that is considered "expanded" (≥ 1024 logical px).
  static const double expanded = 1024;
}
