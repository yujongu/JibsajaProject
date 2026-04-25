import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../../../domain/entities/asset_type.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/auth_providers.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/account_type.dart';
import '../../providers/account_providers.dart';

Future<void> showTransactionFormSheet(
  BuildContext context, {
  Transaction? existing,
  TransactionType? initialType,
  double anchorBottom = 0,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final initialSize = anchorBottom > 0
      ? ((screenHeight - anchorBottom) / screenHeight).clamp(0.4, 0.93)
      : 0.75;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: 0,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: [initialSize],
      builder: (ctx, scrollCtrl) => TransactionFormSheet(
        existing: existing,
        initialType: initialType,
        scrollController: scrollCtrl,
      ),
    ),
  );
}

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.existing,
    this.initialType,
    this.scrollController,
  });
  final Transaction? existing;
  final TransactionType? initialType;
  final ScrollController? scrollController;

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _tickerCtrl;
  late final TextEditingController _assetNameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late TransactionType _txType;
  late TransactionCategory _category;
  late DateTime _date;
  late String _currency;
  late AssetType _assetType;
  String? _accountId;    // from-account (or single account for income/expense/buy/sell)
  String? _toAccountId;  // to-account (only for transfer)
  bool _saving = false;

  static const _currencies = ['KRW', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _txType = widget.initialType ?? t?.type ?? TransactionType.expense;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _amountCtrl = TextEditingController(
        text: t == null || t.type.isTrade
            ? ''
            : t.amount.toStringAsFixed(t.amount % 1 == 0 ? 0 : 2));
    _noteCtrl = TextEditingController(text: t?.note ?? '');
    _tickerCtrl = TextEditingController(text: t?.ticker ?? '');
    _assetNameCtrl = TextEditingController(text: t?.assetName ?? '');
    _qtyCtrl = TextEditingController(
        text: t?.quantity == null ? '' : t!.quantity!.toStringAsFixed(
            t.quantity! % 1 == 0 ? 0 : 4));
    _priceCtrl = TextEditingController(
        text: t?.pricePerUnit == null ? '' : t!.pricePerUnit!.toStringAsFixed(
            t.pricePerUnit! % 1 == 0 ? 0 : 2));
    _category = t?.category ?? TransactionCategory.food;
    _date = t?.date ?? DateTime.now();
    _currency = t?.currency ?? 'KRW';
    _assetType = t?.assetType ?? AssetType.stock;
    _accountId = t?.accountId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _tickerCtrl.dispose();
    _assetNameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  double get _computedTotal {
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    return qty * price;
  }

  String _currencyForAccount(String? id) {
    final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
    try {
      return accounts.firstWhere((a) => a.id == id).currency;
    } catch (_) {
      return 'KRW';
    }
  }

  Account? _linkedCashAccount(String? investAccountId) {
    final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
    try {
      final invest = accounts.firstWhere((a) => a.id == investAccountId);
      if (invest.linkedCashAccountId == null) return null;
      return accounts.firstWhere((a) => a.id == invest.linkedCashAccountId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_txType.isTrade && _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account for this trade')),
      );
      return;
    }
    if (_txType == TransactionType.transfer) {
      if (_accountId == null || _toAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select both From and To accounts')),
        );
        return;
      }
      if (_accountId == _toAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('From and To accounts must be different')),
        );
        return;
      }
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
      final now = DateTime.now();
      final isNew = widget.existing == null;

      // ── Transfer ─────────────────────────────────────────────────────────────
      if (_txType == TransactionType.transfer) {
        final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
        Account fromAcc, toAcc;
        try {
          fromAcc = accounts.firstWhere((a) => a.id == _accountId);
          toAcc   = accounts.firstWhere((a) => a.id == _toAccountId);
        } catch (_) {
          throw Exception('Account not found');
        }

        final debitId  = const Uuid().v4();
        final creditId = const Uuid().v4();

        await repo.batchAddTransactions(user.uid, [
          Transaction(
            id: debitId,
            userId: user.uid,
            accountId: _accountId,
            title: 'Transfer to ${toAcc.name}',
            amount: amount,
            type: TransactionType.transfer,
            isDebit: true,
            category: TransactionCategory.other,
            date: _date,
            currency: fromAcc.currency,
            createdAt: now,
            updatedAt: now,
          ),
          Transaction(
            id: creditId,
            userId: user.uid,
            accountId: _toAccountId,
            title: 'Transfer from ${fromAcc.name}',
            amount: amount,
            type: TransactionType.transfer,
            isDebit: false,
            category: TransactionCategory.other,
            date: _date,
            currency: toAcc.currency,
            createdAt: now,
            updatedAt: now,
          ),
        ]);

        ref.read(sheetsSyncRepositoryProvider).appendTransferRows(
          date: _date,
          fromAccountName: fromAcc.name,
          toAccountName: toAcc.name,
          amount: amount,
          debitTxId: debitId,
          creditTxId: creditId,
        ).ignore();

      // ── Buy / Sell ────────────────────────────────────────────────────────────
      } else if (_txType.isTrade) {
        final ticker     = _tickerCtrl.text.trim().toUpperCase();
        final assetName  = _assetNameCtrl.text.trim();
        final quantity   = double.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0;
        final unitPrice  = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
        final amount     = quantity * unitPrice;
        final title      = '${_txType == TransactionType.buy ? 'Buy' : 'Sell'} $ticker';
        final currency   = _currencyForAccount(_accountId);

        final txId = isNew ? const Uuid().v4() : widget.existing!.id;
        final mainTx = Transaction(
          id: txId,
          userId: user.uid,
          accountId: _accountId,
          title: title,
          amount: amount,
          type: _txType,
          category: TransactionCategory.investment,
          date: _date,
          currency: currency,
          ticker: ticker,
          assetName: assetName,
          assetType: _assetType,
          quantity: quantity,
          pricePerUnit: unitPrice,
          createdAt: now,
          updatedAt: now,
        );

        final cashAccount = _linkedCashAccount(_accountId);
        final isBuy = _txType == TransactionType.buy;

        if (cashAccount != null && isNew) {
          final transferId = const Uuid().v4();
          final transferTx = Transaction(
            id: transferId,
            userId: user.uid,
            accountId: cashAccount.id,
            title: isBuy
                ? 'Transfer Out (Buy $ticker)'
                : 'Transfer In (Sell $ticker)',
            amount: amount,
            type: TransactionType.transfer,
            isDebit: isBuy,
            category: TransactionCategory.other,
            date: _date,
            currency: cashAccount.currency,
            createdAt: now,
            updatedAt: now,
          );

          await repo.batchAddTransactions(user.uid, [mainTx, transferTx]);

          // Write both rows to Excel (fire and forget)
          ref.read(sheetsSyncRepositoryProvider).appendTradeRows(
            date: _date,
            investAccountName: accounts.firstWhere((a) => a.id == _accountId).name,
            cashAccountName: cashAccount.name,
            type: _txType,
            ticker: ticker,
            assetName: assetName,
            quantity: quantity,
            price: unitPrice,
            amount: amount,
            tradeTxId: txId,
            transferTxId: transferId,
          ).ignore();
        } else if (isNew) {
          await repo.addTransaction(user.uid, mainTx);
        } else {
          await repo.updateTransaction(user.uid, widget.existing!.copyWith(
            accountId: _accountId,
            title: title,
            amount: amount,
            type: _txType,
            category: TransactionCategory.investment,
            date: _date,
            currency: currency,
            ticker: ticker,
            assetName: assetName,
            assetType: _assetType,
            quantity: quantity,
            pricePerUnit: unitPrice,
          ));
        }

      // ── Income / Expense ──────────────────────────────────────────────────────
      } else {
        final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
        final title  = _titleCtrl.text.trim();
        final note   = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

        if (isNew) {
          await repo.addTransaction(user.uid, Transaction(
            id: const Uuid().v4(),
            userId: user.uid,
            accountId: _accountId,
            title: title,
            amount: amount,
            type: _txType,
            category: _category,
            date: _date,
            note: note,
            currency: _currency,
            createdAt: now,
            updatedAt: now,
          ));
        } else {
          await repo.updateTransaction(user.uid, widget.existing!.copyWith(
            accountId: _accountId,
            title: title,
            amount: amount,
            type: _txType,
            category: _category,
            date: _date,
            note: note,
            currency: _currency,
          ));
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final isTrade = _txType.isTrade;
    final isTransfer = _txType == TransactionType.transfer;

    if (!isTrade && !isTransfer) {
      final categories = categoriesForType(_txType);
      if (!categories.contains(_category)) _category = categories.first;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 16, bottom: safeBottom + 32),
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
              SheetTitleRow(
                title: widget.existing == null
                    ? 'Add Transaction'
                    : 'Edit Transaction',
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              _TypeToggle(
                selected: _txType,
                isDark: isDark,
                onChanged: (t) => setState(() {
                  _txType = t;
                  _toAccountId = null;
                }),
              ),
              const SizedBox(height: 20),

              if (isTrade)       ..._buildTradeFields(isDark, accounts)
              else if (isTransfer) ..._buildTransferFields(isDark, accounts)
              else               ..._buildRegularFields(isDark, accounts),

              if (!isTrade && !isTransfer) ...[
                const SizedBox(height: 16),
                FieldLabel(label: 'Note (optional)', isDark: isDark),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  style: TextStyle(
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight),
                  decoration: sheetInputDeco(isDark: isDark, hint: 'Add a note...'),
                ),
              ],

              const SizedBox(height: 32),
              PrimaryButton(
                label: widget.existing == null ? 'Add Transaction' : 'Save Changes',
                onPressed: _save,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Trade fields (Buy / Sell) ─────────────────────────────────────────────────

  List<Widget> _buildTradeFields(bool isDark, List<Account> accounts) {
    final total = _computedTotal;
    final cashAccount = _linkedCashAccount(_accountId);
    final isBuy = _txType == TransactionType.buy;

    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FieldLabel(label: 'Ticker', isDark: isDark),
            const SizedBox(height: 8),
            SheetTextField(
              ctrl: _tickerCtrl,
              hint: 'e.g. AAPL',
              isDark: isDark,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FieldLabel(label: 'Asset Type', isDark: isDark),
            const SizedBox(height: 8),
            DropdownButtonFormField<AssetType>(
              value: _assetType,
              items: AssetType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _assetType = v); },
              decoration: sheetInputDeco(isDark: isDark, hint: ''),
              dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
              style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 16),

      FieldLabel(label: 'Asset Name', isDark: isDark),
      const SizedBox(height: 8),
      SheetTextField(
        ctrl: _assetNameCtrl,
        hint: 'e.g. Apple Inc.',
        isDark: isDark,
        textCapitalization: TextCapitalization.words,
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
              style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w500),
              decoration: sheetInputDeco(isDark: isDark, hint: '0'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Invalid';
                return null;
              },
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
              style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w500),
              decoration: sheetInputDeco(isDark: isDark, hint: '0'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Invalid';
                return null;
              },
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
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
          const Spacer(),
          Text(
            NumberFormat('#,##0.##', 'en_US').format(total),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      FieldLabel(label: 'Date', isDark: isDark),
      const SizedBox(height: 8),
      _datePicker(isDark),
      const SizedBox(height: 16),

      FieldLabel(label: 'Investment Account', isDark: isDark),
      const SizedBox(height: 8),
      if (accounts.isEmpty)
        Text('Add an account first',
            style: TextStyle(
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                fontSize: 13))
      else
        DropdownButtonFormField<String?>(
          value: _accountId,
          items: accounts
              .where((a) => a.type == AccountType.investment)
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (v) => setState(() => _accountId = v),
          decoration: sheetInputDeco(isDark: isDark, hint: 'Select account'),
          dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
          style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
          validator: (v) => v == null ? 'Required' : null,
        ),

      // Show linked cash account info
      if (cashAccount != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isBuy ? AppColors.negative : AppColors.positive)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(
              isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 14,
              color: isBuy ? AppColors.negative : AppColors.positive,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBuy
                    ? '${cashAccount.name} will be debited ${NumberFormat("#,##0.##").format(_computedTotal)}'
                    : '${cashAccount.name} will receive ${NumberFormat("#,##0.##").format(_computedTotal)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isBuy ? AppColors.negative : AppColors.positive,
                ),
              ),
            ),
          ]),
        ),
      ],
    ];
  }

  // ── Transfer fields ───────────────────────────────────────────────────────────

  List<Widget> _buildTransferFields(bool isDark, List<Account> accounts) {
    return [
      FieldLabel(label: 'Amount', isDark: isDark),
      const SizedBox(height: 8),
      TextFormField(
        controller: _amountCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w500),
        decoration: sheetInputDeco(isDark: isDark, hint: '0'),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          final n = double.tryParse(v.replaceAll(',', ''));
          if (n == null || n <= 0) return 'Invalid amount';
          return null;
        },
      ),
      const SizedBox(height: 16),

      FieldLabel(label: 'From Account', isDark: isDark),
      const SizedBox(height: 8),
      DropdownButtonFormField<String?>(
        value: _accountId,
        items: [
          const DropdownMenuItem(value: null, child: Text('Select account')),
          ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
        ],
        onChanged: (v) => setState(() => _accountId = v),
        decoration: sheetInputDeco(isDark: isDark, hint: 'Money leaves here'),
        dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),

      FieldLabel(label: 'To Account', isDark: isDark),
      const SizedBox(height: 8),
      DropdownButtonFormField<String?>(
        value: _toAccountId,
        items: [
          const DropdownMenuItem(value: null, child: Text('Select account')),
          ...accounts
              .where((a) => a.id != _accountId)
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
        ],
        onChanged: (v) => setState(() => _toAccountId = v),
        decoration: sheetInputDeco(isDark: isDark, hint: 'Money arrives here'),
        dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),

      FieldLabel(label: 'Date', isDark: isDark),
      const SizedBox(height: 8),
      _datePicker(isDark),
    ];
  }

  // ── Regular fields (Income / Expense) ────────────────────────────────────────

  List<Widget> _buildRegularFields(bool isDark, List<Account> accounts) {
    final categories = categoriesForType(_txType);
    return [
      FieldLabel(label: 'Title', isDark: isDark),
      const SizedBox(height: 8),
      SheetTextField(
        ctrl: _titleCtrl,
        hint: 'e.g. Lunch with team',
        isDark: isDark,
        textCapitalization: TextCapitalization.sentences,
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),

      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FieldLabel(label: 'Amount', isDark: isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w500),
              decoration: sheetInputDeco(isDark: isDark, hint: '0'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Invalid';
                return null;
              },
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FieldLabel(label: 'Currency', isDark: isDark),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _currency,
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _currency = v);
              },
              decoration: sheetInputDeco(isDark: isDark, hint: ''),
              dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
              style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 16),

      FieldLabel(label: 'Category', isDark: isDark),
      const SizedBox(height: 10),
      _CategoryGrid(
        categories: categories,
        selected: _category,
        isDark: isDark,
        onChanged: (c) => setState(() => _category = c),
      ),
      const SizedBox(height: 16),

      FieldLabel(label: 'Date', isDark: isDark),
      const SizedBox(height: 8),
      _datePicker(isDark),

      if (accounts.isNotEmpty) ...[
        const SizedBox(height: 16),
        FieldLabel(label: 'Account (optional)', isDark: isDark),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _accountId,
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...accounts.map(
                (a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
          ],
          onChanged: (v) => setState(() => _accountId = v),
          decoration: sheetInputDeco(isDark: isDark, hint: 'Select account'),
          dropdownColor: isDark ? AppColors.darkCard : AppColors.surfaceCard,
          style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
        ),
      ],
    ];
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
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
            const SizedBox(width: 10),
            Text(DateFormat('MMM d, yyyy').format(_date),
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
          ]),
        ),
      );
}

// ── Type Toggle ───────────────────────────────────────────────────────────────

Color _typeColor(TransactionType t) {
  switch (t) {
    case TransactionType.income:   return AppColors.positive;
    case TransactionType.expense:  return AppColors.negative;
    case TransactionType.buy:      return AppColors.primary;
    case TransactionType.sell:     return const Color(0xFFF59E0B);
    case TransactionType.transfer: return const Color(0xFF8B5CF6);
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle(
      {required this.selected, required this.isDark, required this.onChanged});
  final TransactionType selected;
  final bool isDark;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: TransactionType.values.map((t) {
          final isSelected = t == selected;
          final color = _typeColor(t);
          return GestureDetector(
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : (isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ── Category Grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid(
      {required this.categories,
      required this.selected,
      required this.isDark,
      required this.onChanged});
  final List<TransactionCategory> categories;
  final TransactionCategory selected;
  final bool isDark;
  final ValueChanged<TransactionCategory> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.15)
                    : (isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow),
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
                        : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
                const SizedBox(width: 6),
                Text(cat.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? cat.color
                            : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight))),
              ]),
            ),
          );
        }).toList(),
      );
}
