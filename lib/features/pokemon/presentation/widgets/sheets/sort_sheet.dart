import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

/// The Sort sheet (RF-20..RF-23).
///
/// Stateless to the caller: pass [initial], and the sheet pops the chosen
/// [SortCriteria] via [Navigator.pop] (or `null` if dismissed). UC-04.
class SortSheet extends StatefulWidget {
  /// Creates a [SortSheet] preloaded with [initial].
  const SortSheet({required this.initial, super.key});

  /// The currently active sort criterion.
  final SortCriteria initial;

  @override
  State<SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<SortSheet> {
  late SortCriteria _selected;

  static const _labels = <SortCriteria, String>{
    SortCriteria.numberAsc: 'Number (ascending)',
    SortCriteria.numberDesc: 'Number (descending)',
    SortCriteria.nameAsc: 'Name (A → Z)',
    SortCriteria.nameDesc: 'Name (Z → A)',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Sort',
      primaryAction: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop<SortCriteria>(_selected),
          child: const Text('Apply'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries)
            _SortOption(
              label: entry.value,
              selected: _selected == entry.key,
              onTap: () => setState(() => _selected = entry.key),
            ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.textBlack : AppColors.textGray,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.description.copyWith(
                  color: AppColors.textBlack,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
