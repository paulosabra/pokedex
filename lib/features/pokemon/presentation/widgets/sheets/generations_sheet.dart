import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';

/// Outcome returned by [`GenerationsSheet`] via [`Navigator.pop`].
///
/// Wrapped in a record so the caller can distinguish a drag-to-dismiss
/// (showModalBottomSheet returns `null`) from an explicit tap-to-select
/// (returns a record with `value` set to the chosen id or `null`).
typedef GenerationsSheetResult = ({int? value});

/// The Generation sheet (RF-25..RF-28).
///
/// Renders the eight published generations as 160×129 tiles in a 2-column
/// grid, matching the Figma `Generation / *` symbols (`105:617`..`105:745`).
/// Each tile shows the three starter sprites at the top and the generation
/// label at the bottom. The selected tile uses `#EA5D60` with a tinted
/// drop shadow; unselected tiles use `#F2F2F2`. Tapping a tile pops the sheet
/// with the chosen generation id; tapping the active tile clears the filter
/// (UC-05).
class GenerationsSheet extends StatelessWidget {
  /// Creates a [GenerationsSheet] preloaded with [initial].
  const GenerationsSheet({this.initial, super.key});

  /// The currently active generation id, or `null` for no filter.
  final int? initial;

  /// Roman-numeral labels for the eight published generations, matching the
  /// Figma component names (`Generation / I`..`Generation / VIII`).
  static const _labels = <int, String>{
    1: 'Generation I',
    2: 'Generation II',
    3: 'Generation III',
    4: 'Generation IV',
    5: 'Generation V',
    6: 'Generation VI',
    7: 'Generation VII',
    8: 'Generation VIII',
  };

  /// National-Dex starter trios per generation. Each row mirrors what the
  /// Figma tiles show in the same order.
  static const _starters = <int, List<int>>{
    1: [1, 4, 7],
    2: [152, 155, 158],
    3: [252, 255, 258],
    4: [387, 390, 393],
    5: [495, 498, 501],
    6: [650, 653, 656],
    7: [722, 725, 728],
    8: [810, 813, 816],
  };

  void _select(BuildContext context, int id) {
    final wasActive = initial == id;
    Navigator.of(
      context,
    ).pop<GenerationsSheetResult>((value: wasActive ? null : id));
  }

  void _clear(BuildContext context) {
    Navigator.of(context).pop<GenerationsSheetResult>((value: null));
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = initial != null;
    return AppBottomSheet(
      title: 'Generations',
      subtitle: 'Use search for generations to explore your Pokémon!',
      titleTrailing: hasActive
          ? TextButton(
              onPressed: () => _clear(context),
              child: const Text('Clear'),
            )
          : null,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            // 160 / 129 in the Figma component (`105:617`).
            childAspectRatio: 160 / 129,
          ),
          itemCount: _labels.length,
          itemBuilder: (context, index) {
            final entry = _labels.entries.elementAt(index);
            final isSelected = initial == entry.key;
            return _GenerationCard(
              label: entry.value,
              starterIds: _starters[entry.key]!,
              selected: isSelected,
              onTap: () => _select(context, entry.key),
            );
          },
        ),
      ),
    );
  }
}

class _GenerationCard extends StatelessWidget {
  const _GenerationCard({
    required this.label,
    required this.starterIds,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<int> starterIds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.actionPrimary : AppColors.backgroundInput;
    final fg = selected ? AppColors.textWhite : AppColors.textGray;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 10 : 0,
      shadowColor: selected
          ? AppColors.actionPrimary.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Pokeball + dot pattern overlay — only meaningful on the grey
              // unselected variant; the red selected variant would otherwise
              // mask it with the same grey gradient.
              if (!selected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: SvgPicture.asset(
                      'assets/illustrations/generation_card_pattern.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              // Vertically stacked content: starter trio centered in the upper
              // band of the card, label centered at the bottom. The trio uses
              // a LayoutBuilder so each sprite scales with the card's width
              // (RF-26) instead of overflowing on narrow viewports.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final spriteSize =
                                (constraints.maxWidth / starterIds.length)
                                    .clamp(28.0, 50.0);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final id in starterIds)
                                  _StarterSprite(
                                    pokemonId: id,
                                    size: spriteSize,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.description.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarterSprite extends StatelessWidget {
  const _StarterSprite({required this.pokemonId, required this.size});

  final int pokemonId;
  final double size;

  static const _baseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: '$_baseUrl/$pokemonId.png',
        fit: BoxFit.contain,
        // No placeholder/error widget — empty space matches Figma's empty
        // tile state and avoids leaking a Material spinner into the grid.
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
