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
/// (showModalBottomSheet returns `null`) from an explicit Apply (returns
/// a record with `value` set to the new filter or `null`).
typedef FiltersSheetResult = ({PokemonFilter? value});

/// Inclusive National-Dex id range covered by the Number Range section.
const int _kNumberRangeMin = 1;

/// Upper bound used by the Number Range slider. Covers Generations I–VIII
/// (the dataset the app ships with). When PokéAPI extends, bump this.
const int _kNumberRangeMax = 898;

/// Double-typed copies of the range bounds so they can appear in
/// `const RangeValues(...)` expressions (the int version requires
/// `toDouble()`, which is not a const-evaluable method).
const double _kNumberRangeMinD = 1;
const double _kNumberRangeMaxD = 898;

/// The Filters sheet (RF-12..RF-16, Figma `Filters - Scrolled`).
///
/// Renders five sections — Types, Weaknesses, Heights, Weights, Number Range
/// — using the circular `Icon / *` and `Height/Weight / *` Components from
/// Figma. The footer hosts a Reset / Apply pair: Reset clears the local draft
/// (without popping); Apply pops the sheet with the assembled
/// [PokemonFilter] (UC-03).
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
  late RangeValues _numberRange;

  @override
  void initState() {
    super.initState();
    _loadFrom(widget.initial);
  }

  void _loadFrom(PokemonFilter? source) {
    _types = {...?source?.types};
    _weaknesses = {...?source?.weaknesses};
    _height = source?.height;
    _weight = source?.weight;
    final range = source?.numberRange;
    _numberRange = range == null
        ? const RangeValues(_kNumberRangeMinD, _kNumberRangeMaxD)
        : RangeValues(range.min.toDouble(), range.max.toDouble());
  }

  bool get _isDefaultRange =>
      _numberRange.start.round() == _kNumberRangeMin &&
      _numberRange.end.round() == _kNumberRangeMax;

  bool get _isEmpty =>
      _types.isEmpty &&
      _weaknesses.isEmpty &&
      _height == null &&
      _weight == null &&
      _isDefaultRange;

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

  void _setNumberRange(RangeValues values) {
    setState(() => _numberRange = values);
  }

  void _reset() {
    setState(() => _loadFrom(null));
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
        numberRange: _isDefaultRange
            ? null
            : (
                min: _numberRange.start.round(),
                max: _numberRange.end.round(),
              ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Filters',
      subtitle:
          'Use advanced search to explore Pokémon by type, weakness, height '
          'and more!',
      primaryAction: _FilterFooter(onReset: _reset, onApply: _apply),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
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
              const SizedBox(height: 24),
              _FilterSection(
                title: 'Number Range',
                child: _NumberRangeSlider(
                  values: _numberRange,
                  onChanged: _setNumberRange,
                ),
              ),
            ],
          ),
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

/// Range slider section bound to the National-Dex id window. The slider's
/// active track and thumb adopt `actionPrimary` to match Figma's
/// `Filters - Scrolled` mock.
class _NumberRangeSlider extends StatelessWidget {
  const _NumberRangeSlider({required this.values, required this.onChanged});

  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = SliderTheme.of(context).copyWith(
      activeTrackColor: AppColors.actionPrimary,
      inactiveTrackColor: AppColors.backgroundInput,
      thumbColor: AppColors.backgroundWhite,
      overlayColor: AppColors.actionPrimary.withValues(alpha: 0.16),
      rangeThumbShape: const RoundRangeSliderThumbShape(
        enabledThumbRadius: 9,
      ),
      trackHeight: 3,
      rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(),
      valueIndicatorColor: AppColors.actionPrimary,
      showValueIndicator: ShowValueIndicator.onDrag,
    );

    return SliderTheme(
      data: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RangeSlider(
            values: values,
            min: _kNumberRangeMin.toDouble(),
            max: _kNumberRangeMax.toDouble(),
            divisions: _kNumberRangeMax - _kNumberRangeMin,
            labels: RangeLabels(
              values.start.round().toString(),
              values.end.round().toString(),
            ),
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                values.start.round().toString(),
                style: AppTypography.pokemonNumber.copyWith(
                  color: AppColors.textGray,
                ),
              ),
              Text(
                values.end.round().toString(),
                style: AppTypography.pokemonNumber.copyWith(
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Footer row: a flat grey **Reset** on the left, a red **Apply** on the
/// right (Figma `Filters - Scrolled` 268:1739). Reset reverts the local draft
/// — it does not pop the sheet so the user can tweak again before applying.
class _FilterFooter extends StatelessWidget {
  const _FilterFooter({required this.onReset, required this.onApply});

  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 60,
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.backgroundInput,
                foregroundColor: AppColors.textGray,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Reset'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: AppColors.textWhite,
                elevation: 10,
                shadowColor: AppColors.actionPrimary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Apply'),
            ),
          ),
        ),
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
