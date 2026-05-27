import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// A filled search input styled per the Figma `Text Field / Default` component
/// (`329:1473`): 60h, 10r, `#F2F2F2` background, 20×20 search icon at left:25,
/// 16pt Regular #747476 hint at left:55.
///
/// Stateless — the caller owns the [controller] / [onChanged] callbacks so the
/// field plays naturally with a ViewModel's debounced search intent (RF-10).
class SearchField extends StatelessWidget {
  /// Creates a [SearchField].
  const SearchField({
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'What Pokémon are you looking for?',
    this.autofocus = false,
    super.key,
  });

  /// Optional controller; if `null`, the field is fully uncontrolled and reads
  /// its initial value as empty.
  final TextEditingController? controller;

  /// Called on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field (e.g., presses return).
  final ValueChanged<String>? onSubmitted;

  /// Hint text shown when the field is empty. Defaults to the Figma copy.
  final String hintText;

  /// Whether the field should request focus on first build.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        style: AppTypography.description.copyWith(color: AppColors.textBlack),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.description,
          filled: true,
          fillColor: AppColors.backgroundInput,
          isDense: true,
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(start: 25, end: 10),
            child: Icon(Icons.search, color: AppColors.textGray, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}
