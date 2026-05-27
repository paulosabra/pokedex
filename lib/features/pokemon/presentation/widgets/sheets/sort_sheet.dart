import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

/// The Sort sheet (RF-20..RF-23).
///
/// Renders the four sort criteria as 60h-tall buttons matching the Figma
/// `Button / Primary` (selected, `#EA5D60`) and `Button / Secondary`
/// (unselected, `#F2F2F2`) tokens from frame `268:176`. Tapping a button
/// selects the criterion and pops the sheet with that value — there is no
/// explicit Apply button in the design (tap = apply). UC-04.
class SortSheet extends StatelessWidget {
  /// Creates a [SortSheet] preloaded with [initial].
  const SortSheet({required this.initial, super.key});

  /// The currently active sort criterion.
  final SortCriteria initial;

  static const _labels = <SortCriteria, String>{
    SortCriteria.numberAsc: 'Smallest number first',
    SortCriteria.numberDesc: 'Highest number first',
    SortCriteria.nameAsc: 'A-Z',
    SortCriteria.nameDesc: 'Z-A',
  };

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Sort',
      subtitle: 'Sort Pokémons alphabetically or by National Pokédex number!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries) ...[
            _SortButton(
              label: entry.value,
              selected: initial == entry.key,
              onTap: () => Navigator.of(context).pop<SortCriteria>(entry.key),
            ),
            if (entry.key != _labels.keys.last) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Material(
        color: selected ? AppColors.actionPrimary : AppColors.backgroundInput,
        borderRadius: BorderRadius.circular(10),
        elevation: selected ? 10 : 0,
        shadowColor: selected
            ? AppColors.actionPrimary.withValues(alpha: 0.3)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.description.copyWith(
                color: selected ? AppColors.textWhite : AppColors.textGray,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
