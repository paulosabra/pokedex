import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';

/// Text styles on SF Pro Display (Tech Spec §10.2).
abstract final class AppTypography {
  const AppTypography._();

  /// The bundled font family used across the app.
  static const String fontFamily = 'SF Pro Display';

  /// "Pokédex" application title.
  static const TextStyle applicationTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textBlack,
  );

  /// Pokémon name on the detail screen.
  static const TextStyle pokemonName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textBlack,
  );

  /// Auxiliary / description text.
  static const TextStyle description = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
  );

  /// Bottom-sheet header title — "Sort" / "Generations" / "Filters"
  /// (Figma frames `268:242` / `268:314` — 26pt Bold).
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textBlack,
  );

  /// In-sheet section titles ("Types", "Weaknesses", "Heights"). 16pt Bold.
  static const TextStyle filterTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textBlack,
  );

  /// Pokémon number (#NNN).
  static const TextStyle pokemonNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textBlack,
  );

  /// Type badge label.
  static const TextStyle pokemonType = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textWhite,
  );
}
