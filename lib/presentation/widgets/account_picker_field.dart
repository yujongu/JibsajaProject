import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/sheets_providers.dart' show AccountOption;
import '../shared/theme/app_colors.dart';
import '../shared/widgets/form_sheet_widgets.dart';

/// Identity palette for account monograms. Cool tones only, anchored on the
/// brand blue — red/amber are reserved for semantic (negative/warning) use.
const List<Color> _identityColors = [
  Color(0xFF0055B2), // deep blue
  Color(0xFF0891B2), // cyan
  Color(0xFF0D9488), // teal
  Color(0xFF059669), // emerald
  Color(0xFF6366F1), // indigo
  Color(0xFF7C3AED), // violet
];

/// Stable per-account identity color, derived from the name so the same
/// account looks the same everywhere and across sessions.
Color accountIdentityColor(String name) {
  final hash = name.runes.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return _identityColors[hash % _identityColors.length];
}

/// Circular monogram disc: the account's first character on a tinted
/// background, in its identity color.
class AccountMonogram extends StatelessWidget {
  const AccountMonogram({super.key, required this.name, this.size = 34});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = accountIdentityColor(name);
    final initial = name.isEmpty
        ? '?'
        : String.fromCharCode(name.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Account selection field: looks like the other filled form inputs, but
/// opens a bottom picker sheet listing accounts most-recently-used first.
///
/// Participates in the surrounding [Form]: shows an inline "Required" error
/// on validate, cleared as soon as a choice is made.
class AccountPickerField extends StatelessWidget {
  const AccountPickerField({
    super.key,
    required this.value,
    required this.accounts,
    required this.isDark,
    required this.onChanged,
    this.sheetTitle = 'Select account',
  });

  /// An existing account name, or null (nothing chosen).
  final String? value;
  final List<AccountOption> accounts;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  /// Heading of the picker sheet, mirroring the field's label.
  final String sheetTitle;

  Future<void> _openPicker(
      BuildContext context, FormFieldState<String> state) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AccountPickerSheet(
        title: sheetTitle,
        accounts: accounts,
        selected: value,
        isDark: isDark,
      ),
    );
    if (picked == null) return;
    state.didChange(picked);
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => v == null ? 'Required' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openPicker(context, state),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.hasError
                      ? AppColors.negative
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: _valueContent()),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight,
                  ),
                ],
              ),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                state.errorText!,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.negative),
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueContent() {
    final textPrimary =
        isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;

    if (value == null) {
      return Text(
        'Select account',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color:
              isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
        ),
      );
    }
    return Row(children: [
      AccountMonogram(name: value!, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          value!,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
        ),
      ),
    ]);
  }
}

// ── Picker sheet ─────────────────────────────────────────────────────────────

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.title,
    required this.accounts,
    required this.selected,
    required this.isDark,
  });
  final String title;
  final List<AccountOption> accounts;
  final String? selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 12, bottom: bottomPad + 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetDragHandle(isDark: isDark),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  child: Text(
                    'No accounts in the sheet yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    itemBuilder: (ctx, i) => _accountRow(ctx, accounts[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountRow(BuildContext context, AccountOption account) {
    final isSelected = account.name == selected;
    return InkWell(
      onTap: () => Navigator.of(context).pop(account.name),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(children: [
          AccountMonogram(name: account.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lastUsedLabel(account.lastUsed),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded,
                size: 20, color: AppColors.primary),
        ]),
      ),
    );
  }

}

String _lastUsedLabel(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (days <= 0) return 'Used today';
  if (days == 1) return 'Used yesterday';
  final format = d.year == now.year ? 'MMM d' : 'MMM d, yyyy';
  return 'Last used ${DateFormat(format).format(d)}';
}
