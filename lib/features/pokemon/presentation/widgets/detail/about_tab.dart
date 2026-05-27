import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/core/utils/string_utils.dart';
import 'package:pokedex/features/pokemon/domain/entities/ability.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';

/// The detail-screen About tab — Figma `Profile #2 - About` (`321:416`).
///
/// Renders the species description plus the two section blocks the design
/// specifies — **Pokédex Data** and **Training** — covering RF-31..33.
/// Title color is the Pokémon's primary type color (RN-04). Missing fields
/// render as `—` (TE-10). The Breeding and Location sections from the
/// original plan are intentionally omitted: the Figma file's About tab does
/// not include them, and per project convention Figma is the source of
/// truth.
class AboutTab extends StatelessWidget {
  /// Creates an [AboutTab].
  const AboutTab({required this.detail, required this.accent, super.key});

  /// The Pokémon's full detail payload.
  final PokemonDetail detail;

  /// Section-title color — the primary type's badge color (RN-04). The host
  /// screen owns the lookup so all three tabs share one resolution.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.description, style: AppTypography.description),
          const SizedBox(height: 30),
          _Section(
            title: 'Pokédex Data',
            accent: accent,
            rows: [
              _Row(label: 'Species', value: _orDash(detail.genus)),
              _Row(label: 'Height', value: _formatHeight(detail.heightMeters)),
              _Row(label: 'Weight', value: _formatWeight(detail.weightKg)),
              _AbilitiesRow(abilities: detail.abilities),
              _WeaknessesRow(weaknesses: detail.weaknesses),
            ],
          ),
          const SizedBox(height: 30),
          _Section(
            title: 'Training',
            accent: accent,
            rows: [
              _Row(label: 'EV Yield', value: _orDash(detail.training.evYield)),
              _Row(
                label: 'Catch Rate',
                value: detail.training.catchRate.toString(),
              ),
              _Row(
                label: 'Base Friendship',
                value: detail.training.baseFriendship.toString(),
              ),
              _Row(
                label: 'Base Exp',
                value: detail.training.baseExp?.toString() ?? '—',
              ),
              _Row(
                label: 'Growth Rate',
                value: _orDash(detail.training.growthRate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _orDash(String value) => value.isEmpty ? '—' : value;

  String _formatHeight(double meters) {
    if (meters <= 0) return '—';
    final totalInches = meters * 39.3701;
    final feet = totalInches ~/ 12;
    final inches = (totalInches - feet * 12).round();
    return '${meters.toStringAsFixed(1)}m ($feet′$inches″)';
  }

  String _formatWeight(double kg) {
    if (kg <= 0) return '—';
    final lbs = (kg * 2.20462).toStringAsFixed(1);
    return '${kg.toStringAsFixed(1)}kg ($lbs lbs)';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.rows,
  });

  final String title;
  final Color accent;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.filterTitle.copyWith(color: accent),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 15),
          rows[i],
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.description,
          ),
        ),
      ],
    );
  }
}

class _AbilitiesRow extends StatelessWidget {
  const _AbilitiesRow({required this.abilities});

  final List<Ability> abilities;

  @override
  Widget build(BuildContext context) {
    if (abilities.isEmpty) {
      return const _Row(label: 'Abilities', value: '—');
    }
    final regular = [
      for (final a in abilities)
        if (!a.isHidden) a,
    ];
    final hidden = [
      for (final a in abilities)
        if (a.isHidden) a,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            'Abilities',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < regular.length; i++)
                Text(
                  '${i + 1}. ${StringUtils.capitalize(regular[i].name)}',
                  style: AppTypography.description,
                ),
              for (final ability in hidden)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${StringUtils.capitalize(ability.name)} (hidden ability)',
                    style: AppTypography.pokemonNumber.copyWith(
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeaknessesRow extends StatelessWidget {
  const _WeaknessesRow({required this.weaknesses});

  final List<PokemonTypeId> weaknesses;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            'Weaknesses',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: weaknesses.isEmpty
              ? const Text('—', style: AppTypography.description)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in weaknesses)
                      TypeBadge.iconOnly(type: type),
                  ],
                ),
        ),
      ],
    );
  }
}
