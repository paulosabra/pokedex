import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// A filled search input styled per the Figma `Text Field` component
/// (Tech Spec §10.1 `backgroundInput`).
///
/// Stateless — the caller owns the [controller] / [onChanged] callbacks so the
/// field plays naturally with a ViewModel's debounced search intent (RF-10).
class SearchField extends StatelessWidget {
  /// Creates a [SearchField].
  const SearchField({
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search',
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

  /// Hint text shown when the field is empty.
  final String hintText;

  /// Whether the field should request focus on first build.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
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
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(start: 25, end: 10),
          child: Icon(Icons.search, color: AppColors.textGray, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 60),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
    );
  }
}
