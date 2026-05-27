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
/// Renders the available generations as 160×129 tiles in a 2-column grid,
/// matching the Figma `Generation` frame (`268:248`): the selected tile uses
/// `#EA5D60` with a tinted shadow, others use `#F2F2F2`. Tapping a tile pops
/// the sheet with the chosen generation id; tapping the active tile clears
/// the filter. UC-05.
///
/// MVP scope is Gen 1 only — extend the label map once the spec opens up to
/// more generations.
class GenerationsSheet extends StatefulWidget {
  /// Creates a [GenerationsSheet] preloaded with [initial].
  const GenerationsSheet({this.initial, super.key});

  /// The currently active generation id, or `null` for no filter.
  final int? initial;

  @override
  State<GenerationsSheet> createState() => _GenerationsSheetState();
}

class _GenerationsSheetState extends State<GenerationsSheet> {
  static const _labels = <int, String>{
    1: 'Generation I',
  };

  void _select(int id) {
    final wasActive = widget.initial == id;
    Navigator.of(
      context,
    ).pop<GenerationsSheetResult>((value: wasActive ? null : id));
  }

  void _clear() {
    Navigator.of(context).pop<GenerationsSheetResult>((value: null));
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = widget.initial != null;
    return AppBottomSheet(
      title: 'Generations',
      subtitle: 'Use search for generations to explore your Pokémon!',
      titleTrailing: hasActive
          ? TextButton(onPressed: _clear, child: const Text('Clear'))
          : null,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
          final isSelected = widget.initial == entry.key;
          return _GenerationCard(
            label: entry.value,
            selected: isSelected,
            onTap: () => _select(entry.key),
          );
        },
      ),
    );
  }
}

class _GenerationCard extends StatelessWidget {
  const _GenerationCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SvgPicture.asset(
                  'assets/illustrations/generation_card_pattern.svg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.description.copyWith(color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
