import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../../../domain/entities/bank_card.dart';
import '../../../domain/entities/card_network.dart';
import '../../../domain/entities/card_type.dart';
import '../../providers/card_providers.dart';
import '../../providers/auth_providers.dart';

Future<void> showCardFormSheet(
  BuildContext context, {
  BankCard? existing,
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
      builder: (ctx, scrollCtrl) => CardFormSheet(
        existing: existing,
        scrollController: scrollCtrl,
      ),
    ),
  );
}

class CardFormSheet extends ConsumerStatefulWidget {
  const CardFormSheet({super.key, this.existing, this.scrollController});
  final BankCard? existing;
  final ScrollController? scrollController;

  @override
  ConsumerState<CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends ConsumerState<CardFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _last4Ctrl;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _limitCtrl;
  late CardType _type;
  late CardNetwork _network;
  late String _currency;
  bool _saving = false;

  static const _currencies = ['KRW', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _last4Ctrl = TextEditingController(text: c?.last4Digits ?? '');
    _balanceCtrl = TextEditingController(text: c == null ? '' : c.balance.toString());
    _limitCtrl = TextEditingController(
        text: c?.creditLimit == null ? '' : c!.creditLimit!.toString());
    _type = c?.type ?? CardType.credit;
    _network = c?.network ?? CardNetwork.visa;
    _currency = c?.currency ?? 'KRW';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _last4Ctrl.dispose();
    _balanceCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(cardRepositoryProvider);
      final now = DateTime.now();
      final balance = double.tryParse(_balanceCtrl.text) ?? 0.0;
      final limit = _type == CardType.credit && _limitCtrl.text.isNotEmpty
          ? double.tryParse(_limitCtrl.text) : null;

      if (widget.existing == null) {
        await repo.addCard(user.uid, BankCard(
          id: const Uuid().v4(), userId: user.uid,
          name: _nameCtrl.text.trim(), last4Digits: _last4Ctrl.text.trim(),
          type: _type, network: _network, balance: balance,
          creditLimit: limit, currency: _currency, createdAt: now, updatedAt: now,
        ));
      } else {
        await repo.updateCard(user.uid, widget.existing!.copyWith(
          name: _nameCtrl.text.trim(), last4Digits: _last4Ctrl.text.trim(),
          type: _type, network: _network, balance: balance,
          creditLimit: limit, currency: _currency,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final navBarPadding = MediaQuery.paddingOf(context).bottom;
    final safeBottom = bottomInset > 0 ? bottomInset : navBarPadding;

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
              SheetTitleRow(title: widget.existing == null ? 'Add Card' : 'Edit Card', isDark: isDark),
              const SizedBox(height: 28),

              FieldLabel(label: 'Card Name', isDark: isDark),
              const SizedBox(height: 8),
              SheetTextField(ctrl: _nameCtrl, hint: 'e.g. Kakao Bank Visa', isDark: isDark,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),

              FieldLabel(label: 'Last 4 Digits', isDark: isDark),
              const SizedBox(height: 8),
              SheetTextField(
                ctrl: _last4Ctrl,
                hint: '1234',
                isDark: isDark,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length != 4) return 'Must be 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              FieldLabel(label: 'Card Type', isDark: isDark),
              const SizedBox(height: 10),
              SheetChipRow<CardType>(values: CardType.values, selected: _type,
                  labelOf: (t) => t.label, isDark: isDark,
                  onChanged: (t) => setState(() => _type = t)),
              const SizedBox(height: 16),

              FieldLabel(label: 'Network', isDark: isDark),
              const SizedBox(height: 10),
              SheetChipRow<CardNetwork>(values: CardNetwork.values, selected: _network,
                  labelOf: (n) => n.label, isDark: isDark,
                  onChanged: (n) => setState(() => _network = n)),
              const SizedBox(height: 16),

              FieldLabel(label: _type == CardType.credit ? 'Statement Balance' : 'Balance', isDark: isDark),
              const SizedBox(height: 8),
              SheetNumberField(ctrl: _balanceCtrl, hint: '0', isDark: isDark),

              if (_type == CardType.credit) ...[
                const SizedBox(height: 16),
                FieldLabel(label: 'Credit Limit (optional)', isDark: isDark),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w500),
                  decoration: sheetInputDeco(isDark: isDark, hint: '0'),
                ),
              ],
              const SizedBox(height: 16),

              FieldLabel(label: 'Currency', isDark: isDark),
              const SizedBox(height: 10),
              SheetPillRow(values: _currencies, selected: _currency, isDark: isDark,
                  onChanged: (c) => setState(() => _currency = c)),
              const SizedBox(height: 32),
              PrimaryButton(label: widget.existing == null ? 'Add Card' : 'Save Changes',
                  onPressed: _save, isLoading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
