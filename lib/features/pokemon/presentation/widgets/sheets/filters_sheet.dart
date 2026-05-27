import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/height_weight_theme.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';

/// Outcome returned by [`FiltersSheet`] via [`Navigator.pop`].
///
/// Wrapped in a record so the caller can distinguish a drag-to-dismiss
/// (showModalBottomSheet returns `null`) from an explicit Apply/Clear (returns
/// a record with `value` set to the new filter or `null`).
typedef FiltersSheetResult = ({PokemonFilter? value});

/// The Filters sheet (RF-12..RF-16).
///
/// Renders four sections — Types, Weaknesses, Heights, Weights — using the
/// circular `Icon / *` and `Height/Weight / *` Components from Figma (e.g.
/// `63:5694` unselected and `63:5974` selected). Selecting a button toggles
/// it; Apply pops the sheet with the assembled [PokemonFilter] (UC-03).
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
  WeightCategory? _weight;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _types = {...?initial?.types};
    _weaknesses = {...?initial?.weaknesses};
    _height = initial?.height;
    _weight = initial?.weight;
  }

  bool get _isEmpty =>
      _types.isEmpty &&
      _weaknesses.isEmpty &&
      _height == null &&
      _weight == null;

  void _toggleIn(Set<PokemonTypeId> bucket, PokemonTypeId type) {
    setState(() {
      if (!bucket.add(type)) bucket.remove(type);
    });
  }

  void _setHeight(HeightCategory? height) {
    setState(() => _height = height);
  }

  void _setWeight(WeightCategory? weight) {
    setState(() => _weight = weight);
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
        weight: _weight,
        generationId: widget.initial?.generationId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _types.length +
        _weaknesses.length +
        (_height == null ? 0 : 1) +
        (_weight == null ? 0 : 1);
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
              child: _TypeIconGrid(
                bucket: 'type',
                selected: _types,
                onToggle: (t) => _toggleIn(_types, t),
              ),
            ),
            const SizedBox(height: 24),
            _FilterSection(
              title: 'Weaknesses',
              child: _TypeIconGrid(
                bucket: 'weakness',
                selected: _weaknesses,
                onToggle: (t) => _toggleIn(_weaknesses, t),
              ),
            ),
            const SizedBox(height: 24),
            _FilterSection(
              title: 'Heights',
              child: _HeightPicker(value: _height, onChanged: _setHeight),
            ),
            const SizedBox(height: 24),
            _FilterSection(
              title: 'Weights',
              child: _WeightPicker(value: _weight, onChanged: _setWeight),
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

class _TypeIconGrid extends StatelessWidget {
  const _TypeIconGrid({
    required this.bucket,
    required this.selected,
    required this.onToggle,
  });

  /// `'type'` or `'weakness'` — used to scope per-button keys so tests can
  /// disambiguate the two visually-identical sections.
  final String bucket;
  final Set<PokemonTypeId> selected;
  final ValueChanged<PokemonTypeId> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in PokemonTypeId.values)
          _FilterIconButton(
            key: Key('$bucket-${type.name}'),
            asset: 'assets/icons/types/${type.name}.svg',
            color: PokemonTypeTheme.styleOf(type).color,
            selected: selected.contains(type),
            semanticLabel: '${_titleCase(type.name)} $bucket',
            onTap: () => onToggle(type),
          ),
      ],
    );
  }
}

class _HeightPicker extends StatelessWidget {
  const _HeightPicker({required this.value, required this.onChanged});

  final HeightCategory? value;
  final ValueChanged<HeightCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    const categories = HeightCategory.values;
    return Row(
      children: [
        for (final category in categories) ...[
          _FilterIconButton(
            key: Key('height-${category.name}'),
            asset: 'assets/icons/heights/${category.name}.svg',
            color: HeightWeightTheme.colorForHeight(category),
            selected: value == category,
            semanticLabel: _titleCase(category.name),
            onTap: () => onChanged(value == category ? null : category),
          ),
          if (category != categories.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _WeightPicker extends StatelessWidget {
  const _WeightPicker({required this.value, required this.onChanged});

  final WeightCategory? value;
  final ValueChanged<WeightCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    const categories = WeightCategory.values;
    return Row(
      children: [
        for (final category in categories) ...[
          _FilterIconButton(
            key: Key('weight-${category.name}'),
            asset: 'assets/icons/weights/${category.name}.svg',
            color: HeightWeightTheme.colorForWeight(category),
            selected: value == category,
            semanticLabel: _titleCase(category.name),
            onTap: () => onChanged(value == category ? null : category),
          ),
          if (category != categories.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

String _titleCase(String name) =>
    '${name[0].toUpperCase()}${name.substring(1)}';

/// A 50×50 pill-shaped filter toggle — the shared visual for Types,
/// Weaknesses, Heights, and Weights.
///
/// Selected: filled circle in [color], white icon, drop shadow `color@30%`.
/// Unselected: transparent, icon in [color].
class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.asset,
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final String asset;
  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppColors.textWhite : color;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color : Colors.transparent,
        shape: const CircleBorder(),
        elevation: selected ? 10 : 0,
        shadowColor: selected
            ? color.withValues(alpha: 0.3)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12.5),
            child: SvgPicture.asset(
              asset,
              width: 25,
              height: 25,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
