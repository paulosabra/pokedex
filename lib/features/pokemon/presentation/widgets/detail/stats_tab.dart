import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/core/utils/string_utils.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/entities/stat_set.dart';

/// The detail-screen Stats tab — Figma `Profile #1 - Stats` (`268:378`).
///
/// Renders the six base stats with a [StatValue.base]/[StatValue.min]/
/// [StatValue.max] row each (RF-35..37), a Total row, the level-100 caption
/// (RN-12), and the Type Defenses block listing every attacking type with
/// its multiplier against this Pokémon (RF-39).
class StatsTab extends StatelessWidget {
  /// Creates a [StatsTab].
  const StatsTab({required this.detail, required this.accent, super.key});

  /// The Pokémon's full detail payload.
  final PokemonDetail detail;

  /// Section-title and bar-fill color — the primary type's badge color
  /// (RN-04). The host screen owns the lookup so all three tabs share one
  /// resolution.
  final Color accent;

  static const _statMax = 255;

  @override
  Widget build(BuildContext context) {
    final stats = detail.baseStats;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Base Stats',
            style: AppTypography.filterTitle.copyWith(color: accent),
          ),
          const SizedBox(height: 20),
          _StatRow(label: 'HP', stat: stats.hp, accent: accent),
          const SizedBox(height: 15),
          _StatRow(label: 'Attack', stat: stats.attack, accent: accent),
          const SizedBox(height: 15),
          _StatRow(label: 'Defense', stat: stats.defense, accent: accent),
          const SizedBox(height: 15),
          _StatRow(label: 'Sp. Atk', stat: stats.specialAttack, accent: accent),
          const SizedBox(height: 15),
          _StatRow(
            label: 'Sp. Def',
            stat: stats.specialDefense,
            accent: accent,
          ),
          const SizedBox(height: 15),
          _StatRow(label: 'Speed', stat: stats.speed, accent: accent),
          const SizedBox(height: 15),
          _TotalRow(total: stats.total),
          const SizedBox(height: 20),
          Text(
            'The ranges shown on the right are for a level 100 Pokémon. '
            'Maximum values are based on a beneficial nature, 252 EVs, 31 IVs; '
            'minimum values are based on a hindering nature, 0 EVs, 0 IVs.',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Type Defenses',
            style: AppTypography.filterTitle.copyWith(color: accent),
          ),
          const SizedBox(height: 20),
          Text(
            'The effectiveness of each type on '
            '${StringUtils.capitalize(detail.summary.name)}.',
            style: AppTypography.description,
          ),
          const SizedBox(height: 20),
          _TypeDefenses(defenses: detail.typeDefenses),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.stat,
    required this.accent,
  });

  final String label;
  final StatValue stat;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fraction = (stat.base / StatsTab._statMax).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            stat.base.toString(),
            style: AppTypography.description,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, color: AppColors.backgroundInput),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 4, color: accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text(
            stat.min.toString(),
            style: AppTypography.description,
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            stat.max.toString(),
            style: AppTypography.description,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            'Total',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            total.toString(),
            style: AppTypography.description.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textBlack,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text(
            'Min',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            'Max',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _TypeDefenses extends StatelessWidget {
  const _TypeDefenses({required this.defenses});

  final Map<PokemonTypeId, double> defenses;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 13,
      runSpacing: 15,
      children: [
        for (final type in PokemonTypeId.values)
          _DefenseCell(
            type: type,
            multiplier: defenses[type] ?? 1.0,
          ),
      ],
    );
  }
}

class _DefenseCell extends StatelessWidget {
  const _DefenseCell({required this.type, required this.multiplier});

  final PokemonTypeId type;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeBadge.iconOnly(type: type),
        const SizedBox(height: 10),
        Text(
          _formatMultiplier(multiplier),
          style: AppTypography.description.copyWith(
            color: multiplier == 1.0 ? AppColors.textGray : AppColors.textBlack,
          ),
        ),
      ],
    );
  }

  String _formatMultiplier(double m) {
    if (m == 0) return '0';
    if (m == 0.25) return '¼';
    if (m == 0.5) return '½';
    if (m == 1) return '1';
    if (m == 2) return '2';
    if (m == 4) return '4';
    return m.toStringAsFixed(2);
  }
}
