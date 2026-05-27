import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';

/// Outcome returned by [`GenerationsSheet`] via [`Navigator.pop`].
///
/// Wrapped in a record so the caller can distinguish a drag-to-dismiss
/// (showModalBottomSheet returns `null`) from an explicit Apply/Clear (returns
/// a record with `value` set to the chosen id or `null`).
typedef GenerationsSheetResult = ({int? value});

/// The Generation sheet (RF-25..RF-28).
///
/// Stateless to the caller: pass the current generation id (or `null` for
/// "all"), and the sheet pops a [GenerationsSheetResult] via [Navigator.pop]
/// (or no value at all if the user dragged to dismiss). UC-05.
///
/// MVP scope is Gen 1 only — extend the labels map below once the spec opens
/// up to more generations. Tapping the active generation again clears it
/// (toggles back to "all").
class GenerationsSheet extends StatefulWidget {
  /// Creates a [GenerationsSheet] preloaded with [initial].
  const GenerationsSheet({this.initial, super.key});

  /// The currently active generation id, or `null` for no filter.
  final int? initial;

  @override
  State<GenerationsSheet> createState() => _GenerationsSheetState();
}

class _GenerationsSheetState extends State<GenerationsSheet> {
  int? _selected;

  static const _labels = <int, String>{
    1: 'Generation I — Kanto',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Generation',
      titleTrailing: _selected == null
          ? null
          : TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop<GenerationsSheetResult>((value: null)),
              child: const Text('Clear'),
            ),
      primaryAction: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<GenerationsSheetResult>((value: _selected)),
          child: const Text('Apply'),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: _labels.length,
        itemBuilder: (context, index) {
          final entry = _labels.entries.elementAt(index);
          final isSelected = _selected == entry.key;
          return _GenerationCard(
            label: entry.value,
            selected: isSelected,
            onTap: () => setState(
              () => _selected = isSelected ? null : entry.key,
            ),
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
    return Material(
      color: selected
          ? AppColors.backgroundPressedInput
          : AppColors.backgroundInput,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppColors.textBlack, width: 2)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.description.copyWith(
              color: AppColors.textBlack,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
