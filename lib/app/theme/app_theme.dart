import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Application [ThemeData] built from the §10 design tokens.
abstract final class AppTheme {
  const AppTheme._();

  /// The light theme (the only theme in the MVP).
  ///
  /// Sets the §10.1 base colors, the SF Pro Display font family, and the
  /// shared bottom-sheet shape — 30px top corners per the Figma sheet frames
  /// (`268:241` / `268:313`). Widgets use the named [AppTypography] styles
  /// directly for §10.2 typography.
  static ThemeData get light => ThemeData(
    colorScheme: const ColorScheme.light(onSurface: AppColors.textBlack),
    scaffoldBackgroundColor: AppColors.backgroundWhite,
    fontFamily: AppTypography.fontFamily,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: AppColors.backgroundWhite,
      modalBackgroundColor: AppColors.backgroundWhite,
      modalBarrierColor: AppColors.backgroundModal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
  );
}
