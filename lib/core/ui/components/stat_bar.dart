import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Horizontal labeled stat bar used in the detail Stats tab (RF-35..37).
///
/// Takes primitive parameters only so it stays free of any
/// `features/pokemon/domain/...` import. The caller is responsible for picking
/// the fill [color] (typically the Pokémon's primary type color).
class StatBar extends StatelessWidget {
  /// Creates a [StatBar].
  const StatBar({
    required this.label,
    required this.value,
    required this.color,
    this.max = 255,
    super.key,
  });

  /// Stat label (e.g. "HP", "Attack").
  final String label;

  /// Stat value, in `[0, max]`. Values outside the range clamp.
  final int value;

  /// Stat ceiling — base-stat max is 255 across PokéAPI; pass a different
  /// ceiling for level-100 displays.
  final int max;

  /// Fill color of the bar segment proportional to [value] / [max].
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / max).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: AppTypography.description.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            style: AppTypography.description,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, color: color.withValues(alpha: 0.2)),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 4, color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
