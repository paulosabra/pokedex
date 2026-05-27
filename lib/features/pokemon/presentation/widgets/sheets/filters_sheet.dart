import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';

/// Outcome returned by [`FiltersSheet`] via [`Navigator.pop`].
///
/// Wrapped in a record so the caller can distinguish a drag-to-dismiss
/// (showModalBottomSheet returns `null`) from an explicit Apply/Clear (returns
/// a record with `value` set to the new filter or `null`).
typedef FiltersSheetResult = ({PokemonFilter? value});

/// The Filters sheet (RF-12..RF-16).
///
/// Stateless to the outside: the caller passes [initial], and the sheet pops
/// a [FiltersSheetResult] via [Navigator.pop] (or no value at all if the user
/// dragged the sheet down to dismiss it). UC-03.
class FiltersSheet extends StatefulWidget {
  /// Creates a [FiltersSheet] preloaded with [initial].
  const FiltersSheet({this.initial, super.key});

  /// The currently active filter, or `null` if none.
  final PokemonFilter? initial;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late Set<PokemonTypeId> _types;
  late Set<PokemonTypeId> _weaknesses;
  HeightCategory? _height;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _types = {...?initial?.types};
    _weaknesses = {...?initial?.weaknesses};
    _height = initial?.height;
  }

  bool get _isEmpty => _types.isEmpty && _weaknesses.isEmpty && _height == null;

  void _toggleIn(Set<PokemonTypeId> bucket, PokemonTypeId type) {
    setState(() {
      if (!bucket.add(type)) bucket.remove(type);
    });
  }

  void _setHeight(HeightCategory? height) {
    setState(() => _height = height);
  }

  void _clear() {
    Navigator.of(context).pop<FiltersSheetResult>((value: null));
  }

  void _apply() {
    if (_isEmpty) {
      Navigator.of(context).pop<FiltersSheetResult>((value: null));
      return;
    }
    Navigator.of(context).pop<FiltersSheetResult>((
      value: PokemonFilter(
        types: Set.unmodifiable(_types),
        weaknesses: Set.unmodifiable(_weaknesses),
        height: _height,
        generationId: widget.initial?.generationId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _types.length + _weaknesses.length + (_height == null ? 0 : 1);
    return AppBottomSheet(
      title: 'Filters${activeCount == 0 ? '' : ' ($activeCount)'}',
      titleTrailing: TextButton(
        onPressed: _isEmpty ? null : _clear,
        child: const Text('Clear'),
      ),
      primaryAction: SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: _apply, child: const Text('Apply')),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterSection(
              title: 'Types',
              child: _TypeChipGrid(
                selected: _types,
                onToggle: (t) => _toggleIn(_types, t),
              ),
            ),
            const SizedBox(height: 24),
            _FilterSection(
              title: 'Weaknesses',
              child: _TypeChipGrid(
                selected: _weaknesses,
                onToggle: (t) => _toggleIn(_weaknesses, t),
              ),
            ),
            const SizedBox(height: 24),
            _FilterSection(
              title: 'Heights',
              child: _HeightPicker(value: _height, onChanged: _setHeight),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.filterTitle),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _TypeChipGrid extends StatelessWidget {
  const _TypeChipGrid({required this.selected, required this.onToggle});

  final Set<PokemonTypeId> selected;
  final ValueChanged<PokemonTypeId> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in PokemonTypeId.values)
          _TypeChip(
            type: type,
            selected: selected.contains(type),
            onTap: () => onToggle(type),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PokemonTypeId type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = PokemonTypeTheme.styleOf(type);
    final outlineColor = selected ? style.color : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: outlineColor, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: TypeBadge(type: type),
      ),
    );
  }
}

class _HeightPicker extends StatelessWidget {
  const _HeightPicker({required this.value, required this.onChanged});

  final HeightCategory? value;
  final ValueChanged<HeightCategory?> onChanged;

  static const _labels = <HeightCategory, String>{
    HeightCategory.short: 'Short',
    HeightCategory.medium: 'Medium',
    HeightCategory.tall: 'Tall',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in _labels.entries) ...[
          Expanded(
            child: _HeightOption(
              label: entry.value,
              selected: value == entry.key,
              onTap: () => onChanged(value == entry.key ? null : entry.key),
            ),
          ),
          if (entry.key != _labels.keys.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _HeightOption extends StatelessWidget {
  const _HeightOption({
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.backgroundPressedInput
              : AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: AppColors.textBlack, width: 2)
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.description.copyWith(
            color: AppColors.textBlack,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
