import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Drag handle shown at the top of every bottom sheet.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key, required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorder : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

/// Title row with a close button for bottom sheets.
class SheetTitleRow extends StatelessWidget {
  const SheetTitleRow({super.key, required this.title, required this.isDark});
  final String title;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight),
            ),
          ),
        ],
      );
}

/// Small label above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, required this.isDark});
  final String label;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        ),
      );
}

/// Standard input decoration used across all form sheets.
InputDecoration sheetInputDeco({
  required bool isDark,
  required String hint,
  String? prefixText,
}) =>
    InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.negative, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.negative, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

/// Text form field with standard sheet styling.
class SheetTextField extends StatelessWidget {
  const SheetTextField({
    super.key,
    required this.ctrl,
    required this.hint,
    required this.isDark,
    this.validator,
    this.textCapitalization = TextCapitalization.words,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.decoration,
  });
  final TextEditingController ctrl;
  final String hint;
  final bool isDark;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w500),
        decoration: decoration ??
            sheetInputDeco(isDark: isDark, hint: hint)
                .copyWith(counterText: maxLength != null ? '' : null),
        validator: validator,
      );
}

/// Numeric form field with validation.
class SheetNumberField extends StatelessWidget {
  const SheetNumberField({
    super.key,
    required this.ctrl,
    required this.hint,
    required this.isDark,
    this.allowNegative = false,
  });
  final TextEditingController ctrl;
  final String hint;
  final bool isDark;
  final bool allowNegative;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w500),
        decoration: sheetInputDeco(isDark: isDark, hint: hint),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Invalid number';
          return null;
        },
      );
}

/// Horizontally scrollable chip selector for enum-typed values.
class SheetChipRow<T> extends StatelessWidget {
  const SheetChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.isDark,
    required this.onChanged,
  });
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final bool isDark;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: values.map((v) {
            final isSelected = v == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.surfaceContainerLow),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    labelOf(v),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

/// Row of pill buttons for selecting a string value (e.g. currency).
class SheetPillRow extends StatelessWidget {
  const SheetPillRow({
    super.key,
    required this.values,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });
  final List<String> values;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: values.map((c) {
          final isSelected = c == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkBorder
                          : AppColors.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
}
