import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_type.dart';
import '../extensions/transaction_category_ui.dart';
import '../providers/sheets_providers.dart';
import '../shared/theme/app_colors.dart';
import '../shared/widgets/form_sheet_widgets.dart';
import '../shared/widgets/glass_button.dart';

/// Opens the add-transaction bottom sheet. Returns true if a row was added.
Future<bool?> showAddTransactionSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.78],
      builder: (ctx, scrollCtrl) =>
          AddTransactionSheet(scrollController: scrollCtrl),
    ),
  );
}

const _newAccountSentinel = '__new_account__';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.scrollController});
  final ScrollController? scrollController;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tickerCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _newAccountCtrl = TextEditingController();
  final _newSecondAccountCtrl = TextEditingController();

  TransactionType _type = TransactionType.purchase;
  TransactionCategory _category = TransactionCategory.food;
  DateTime _date = DateTime.now();
  String? _accountChoice; // an existing name, or _newAccountSentinel
  String? _secondAccountChoice; // trades only: the brokerage account
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _tickerCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _newAccountCtrl.dispose();
    _newSecondAccountCtrl.dispose();
    super.dispose();
  }

  double get _tradeTotal {
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    return qty * price;
  }

  String? _resolveAccount(String? choice, TextEditingController newCtrl) {
    if (choice == _newAccountSentinel) {
      final v = newCtrl.text.trim();
      return v.isEmpty ? null : v;
    }
    return choice;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final account = _resolveAccount(_accountChoice, _newAccountCtrl);
    if (account == null) {
      _snack('Please choose or enter an account');
      return;
    }
    String? secondAccount;
    if (_type.isTrade) {
      secondAccount =
          _resolveAccount(_secondAccountChoice, _newSecondAccountCtrl);
      if (secondAccount == null) {
        _snack('Please choose or enter a brokerage account');
        return;
      }
    }

    final tx = _type == TransactionType.purchase
        ? SheetTransaction(
            date: _date,
            account: account,
            type: _type,
            category: _category,
            description: _descCtrl.text.trim(),
            amount: double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
          )
        : SheetTransaction(
            date: _date,
            account: account,
            type: _type,
            description: _descCtrl.text.trim(),
            secondAccount: secondAccount,
            ticker: _tickerCtrl.text.trim().toUpperCase(),
            quantity: double.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0,
            price: double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
          );

    setState(() => _saving = true);
    final result = await ref.read(sheetsRepositoryProvider).appendTransaction(tx);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Success():
        ref.invalidate(transactionsProvider);
        // The root ScaffoldMessenger outlives this bottom sheet, so the toast
        // stays visible after the pop.
        _snack(_type.isTrade
            ? 'Sheet updated — ${_type.label} added (2 rows)'
            : 'Sheet updated — ${_type.label} added');
        Navigator.of(context).pop(true);
      case Failure(:final error):
        _snack('Could not add row: $error');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final navBarPadding = MediaQuery.paddingOf(context).bottom;
    final safeBottom = bottomInset > 0 ? bottomInset : navBarPadding;
    final accounts = ref.watch(accountNamesProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: safeBottom + 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetDragHandle(isDark: isDark),
              const SizedBox(height: 20),
              SheetTitleRow(title: 'Add Transaction', isDark: isDark),
              const SizedBox(height: 24),

              _TypeToggle(
                selected: _type,
                isDark: isDark,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 20),

              if (_type == TransactionType.purchase)
                ..._purchaseFields(isDark)
              else
                ..._tradeFields(isDark),

              const SizedBox(height: 16),
              FieldLabel(
                label: _type.isTrade ? 'Brokerage cash account' : 'Account',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _accountSelector(
                isDark,
                accounts,
                choice: _accountChoice,
                newCtrl: _newAccountCtrl,
                onChanged: (v) => setState(() => _accountChoice = v),
              ),

              if (_type.isTrade) ...[
                const SizedBox(height: 16),
                FieldLabel(label: 'Brokerage account', isDark: isDark),
                const SizedBox(height: 8),
                _accountSelector(
                  isDark,
                  accounts,
                  choice: _secondAccountChoice,
                  newCtrl: _newSecondAccountCtrl,
                  onChanged: (v) => setState(() => _secondAccountChoice = v),
                ),
                const SizedBox(height: 8),
                Text(
                  _type == TransactionType.buy
                      ? 'Writes 2 rows: Transfer (−total) from the cash '
                          'account, Buy (+total) in the brokerage account.'
                      : 'Writes 2 rows: Transfer (+total) into the cash '
                          'account, Sell (−total) in the brokerage account.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],

              const SizedBox(height: 16),
              FieldLabel(label: 'Date', isDark: isDark),
              const SizedBox(height: 8),
              _datePicker(isDark),

              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Add Transaction',
                onPressed: _save,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Purchase fields ──────────────────────────────────────────────────────

  List<Widget> _purchaseFields(bool isDark) => [
        FieldLabel(label: 'Amount', isDark: isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: _inputStyle(isDark),
          decoration: sheetInputDeco(isDark: isDark, hint: '0'),
          validator: _positiveNumber,
        ),
        const SizedBox(height: 16),
        FieldLabel(label: 'Category', isDark: isDark),
        const SizedBox(height: 10),
        _CategoryGrid(
          selected: _category,
          isDark: isDark,
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        FieldLabel(label: 'Description', isDark: isDark),
        const SizedBox(height: 8),
        SheetTextField(
          ctrl: _descCtrl,
          hint: 'e.g. Lunch with team',
          isDark: isDark,
          textCapitalization: TextCapitalization.sentences,
        ),
      ];

  // ── Trade fields (Buy / Sell) ────────────────────────────────────────────

  List<Widget> _tradeFields(bool isDark) => [
        FieldLabel(label: 'Ticker', isDark: isDark),
        const SizedBox(height: 8),
        SheetTextField(
          ctrl: _tickerCtrl,
          hint: 'e.g. AAPL',
          isDark: isDark,
          textCapitalization: TextCapitalization.characters,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FieldLabel(label: 'Quantity', isDark: isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: _inputStyle(isDark),
                decoration: sheetInputDeco(isDark: isDark, hint: '0'),
                onChanged: (_) => setState(() {}),
                validator: _positiveNumber,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FieldLabel(label: 'Price / Unit', isDark: isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: _inputStyle(isDark),
                decoration: sheetInputDeco(isDark: isDark, hint: '0'),
                onChanged: (_) => setState(() {}),
                validator: _positiveNumber,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Text('Total',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight)),
            const Spacer(),
            Text(
              NumberFormat('#,##0.##', 'en_US').format(_tradeTotal),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        FieldLabel(label: 'Note (optional)', isDark: isDark),
        const SizedBox(height: 8),
        SheetTextField(
          ctrl: _descCtrl,
          hint: 'e.g. Apple Inc.',
          isDark: isDark,
          textCapitalization: TextCapitalization.sentences,
        ),
      ];

  // ── Account selector ─────────────────────────────────────────────────────

  Widget _accountSelector(
    bool isDark,
    List<String> accounts, {
    required String? choice,
    required TextEditingController newCtrl,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: choice,
          isExpanded: true,
          items: [
            ...accounts.map(
                (a) => DropdownMenuItem(value: a, child: Text(a))),
            const DropdownMenuItem(
                value: _newAccountSentinel, child: Text('+ New account…')),
          ],
          onChanged: onChanged,
          decoration: sheetInputDeco(
              isDark: isDark,
              hint: accounts.isEmpty ? 'Add a new account' : 'Select account'),
          dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
          style: _inputStyle(isDark),
          validator: (v) => v == null ? 'Required' : null,
        ),
        if (choice == _newAccountSentinel) ...[
          const SizedBox(height: 10),
          SheetTextField(
            ctrl: newCtrl,
            hint: 'New account name',
            isDark: isDark,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a name' : null,
          ),
        ],
      ],
    );
  }

  Widget _datePicker(bool isDark) => GestureDetector(
        onTap: _pickDate,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded,
                size: 16,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight),
            const SizedBox(width: 10),
            Text(DateFormat('MMM d, yyyy').format(_date),
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight)),
          ]),
        ),
      );

  TextStyle _inputStyle(bool isDark) => TextStyle(
        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
        fontWeight: FontWeight.w500,
      );

  String? _positiveNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v.replaceAll(',', ''));
    if (n == null || n <= 0) return 'Invalid';
    return null;
  }
}

// ── Type toggle ──────────────────────────────────────────────────────────────

Color _typeColor(TransactionType t) {
  switch (t) {
    case TransactionType.purchase: return AppColors.negative;
    case TransactionType.buy:      return AppColors.primary;
    case TransactionType.sell:     return const Color(0xFFF59E0B);
    case TransactionType.transfer: return AppColors.secondaryFallback;
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });
  final TransactionType selected;
  final bool isDark;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: TransactionType.userSelectable.map((t) {
          final isSelected = t == selected;
          final color = _typeColor(t);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.surfaceContainerLow),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t.label,
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
            ),
          );
        }).toList(),
      );
}

// ── Category grid ────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });
  final TransactionCategory selected;
  final bool isDark;
  final ValueChanged<TransactionCategory> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: purchaseCategories.map((cat) {
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.15)
                    : (isDark
                        ? AppColors.darkBorder
                        : AppColors.surfaceContainerLow),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? cat.color : Colors.transparent,
                    width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(cat.icon,
                    size: 14,
                    color: isSelected
                        ? cat.color
                        : (isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight)),
                const SizedBox(width: 6),
                Text(cat.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? cat.color
                            : (isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight))),
              ]),
            ),
          );
        }).toList(),
      );
}
