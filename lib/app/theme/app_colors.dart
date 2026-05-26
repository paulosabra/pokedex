import 'package:flutter/material.dart';

/// Base color tokens (Tech Spec §10.1).
abstract final class AppColors {
  const AppColors._();

  /// Primary text and numbers.
  static const Color textBlack = Color(0xFF17171B);

  /// Secondary text: descriptions and labels.
  static const Color textGray = Color(0xFF747476);

  /// Text rendered on top of a type color.
  static const Color textWhite = Color(0xFFFFFFFF);

  /// Pokémon number caption — [textBlack] at 60% opacity (Figma Style Guide
  /// `$text-number`, frame `326:64`).
  static const Color textNumber = Color(0x9917171B);

  /// Search-field / input background.
  static const Color backgroundInput = Color(0xFFF2F2F2);

  /// Screen and sheet background.
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  /// Modal scrim over sheets — black at 25% opacity (Figma Style Guide
  /// `$background-modal`, frame `326:64`).
  static const Color backgroundModal = Color(0x40000000);
}
