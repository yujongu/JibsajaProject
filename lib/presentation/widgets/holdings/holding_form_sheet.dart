import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../../../domain/entities/holding.dart';
import '../../../domain/entities/holding_type.dart';
import '../../providers/holding_providers.dart';
import '../../providers/auth_providers.dart';

Future<void> showHoldingFormSheet(BuildContext context, {Holding? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HoldingFormSheet(existing: existing),
  );
}

class HoldingFormSheet extends ConsumerStatefulWidget {
  const HoldingFormSheet({super.key, this.existing});
  final Holding? existing;

  @override
  ConsumerState<HoldingFormSheet> createState() => _HoldingFormSheetState();
}

class _HoldingFormSheetState extends ConsumerState<HoldingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tickerCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _avgCostCtrl;
  late final TextEditingController _currentPriceCtrl;
  late HoldingType _type;
  late String _currency;
  bool _saving = false;

  static const _currencies = ['USD', 'KRW', 'EUR', 'JPY'];

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _nameCtrl = TextEditingController(text: h?.name ?? '');
    _tickerCtrl = TextEditingController(text: h?.ticker ?? '');
    _quantityCtrl = TextEditingController(text: h == null ? '' : h.quantity.toString());
    _avgCostCtrl = TextEditingController(text: h == null ? '' : h.avgCostPrice.toString());
    _currentPriceCtrl = TextEditingController(text: h == null ? '' : h.currentPrice.toString());
    _type = h?.type ?? HoldingType.stock;
    _currency = h?.currency ?? 'USD';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tickerCtrl.dispose();
    _quantityCtrl.dispose();
    _avgCostCtrl.dispose();
    _currentPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(holdingRepositoryProvider);
      final now = DateTime.now();
      final qty = double.parse(_quantityCtrl.text);
      final avg = double.parse(_avgCostCtrl.text);
      final cur = double.parse(_currentPriceCtrl.text);
      if (widget.existing == null) {
        await repo.addHolding(user.uid, Holding(
          id: const Uuid().v4(), userId: user.uid,
          name: _nameCtrl.text.trim(),
          ticker: _tickerCtrl.text.trim().toUpperCase(),
          type: _type, quantity: qty, avgCostPrice: avg, currentPrice: cur,
          currency: _currency, createdAt: now, updatedAt: now,
        ));
      } else {
        await repo.updateHolding(user.uid, widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          ticker: _tickerCtrl.text.trim().toUpperCase(),
          type: _type, quantity: qty, avgCostPrice: avg, currentPrice: cur,
          currency: _currency,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetDragHandle(isDark: isDark),
              const SizedBox(height: 20),
              SheetTitleRow(title: widget.existing == null ? 'Add Holding' : 'Edit Holding', isDark: isDark),
              const SizedBox(height: 28),

              FieldLabel(label: 'Name', isDark: isDark),
              const SizedBox(height: 8),
              SheetTextField(ctrl: _nameCtrl, hint: 'e.g. Apple Inc', isDark: isDark,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),

              FieldLabel(label: 'Ticker / Symbol', isDark: isDark),
              const SizedBox(height: 8),
              SheetTextField(ctrl: _tickerCtrl, hint: 'e.g. AAPL', isDark: isDark,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 16),

              FieldLabel(label: 'Type', isDark: isDark),
              const SizedBox(height: 10),
              SheetChipRow<HoldingType>(values: HoldingType.values, selected: _type,
                  labelOf: (t) => t.label, isDark: isDark,
                  onChanged: (t) => setState(() => _type = t)),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FieldLabel(label: 'Quantity', isDark: isDark),
                  const SizedBox(height: 8),
                  SheetNumberField(ctrl: _quantityCtrl, hint: '0', isDark: isDark),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FieldLabel(label: 'Avg Cost', isDark: isDark),
                  const SizedBox(height: 8),
                  SheetNumberField(ctrl: _avgCostCtrl, hint: '0.00', isDark: isDark),
                ])),
              ]),
              const SizedBox(height: 16),

              FieldLabel(label: 'Current Price', isDark: isDark),
              const SizedBox(height: 8),
              SheetNumberField(ctrl: _currentPriceCtrl, hint: '0.00', isDark: isDark),
              const SizedBox(height: 16),

              FieldLabel(label: 'Currency', isDark: isDark),
              const SizedBox(height: 10),
              SheetPillRow(values: _currencies, selected: _currency, isDark: isDark,
                  onChanged: (c) => setState(() => _currency = c)),
              const SizedBox(height: 32),
              PrimaryButton(label: widget.existing == null ? 'Add Holding' : 'Save Changes',
                  onPressed: _save, isLoading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
