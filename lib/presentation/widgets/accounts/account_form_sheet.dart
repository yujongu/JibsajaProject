import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/glass_button.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/account_type.dart';
import '../../extensions/account_type_ui.dart';
import '../../providers/account_providers.dart';
import '../../providers/auth_providers.dart';

Future<void> showAccountFormSheet(
  BuildContext context, {
  Account? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AccountFormSheet(existing: existing),
  );
}

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.existing});
  final Account? existing;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _initialBalanceCtrl;
  late AccountType _type;
  late String _currency;
  String? _linkedCashAccountId;
  bool _saving = false;

  static const _currencies = ['KRW', 'USD', 'EUR', 'JPY'];

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: a == null ? '' : a.balance.toStringAsFixed(a.balance % 1 == 0 ? 0 : 2),
    );
    _initialBalanceCtrl = TextEditingController(
      text: a == null ? '' : a.initialBalance.toStringAsFixed(a.initialBalance % 1 == 0 ? 0 : 2),
    );
    _type = a?.type ?? AccountType.checking;
    _currency = a?.currency ?? 'KRW';
    _linkedCashAccountId = a?.linkedCashAccountId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _initialBalanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      final now = DateTime.now();
      final isLiquid = _type.isLiquid;
      final balance = double.tryParse(_balanceCtrl.text.replaceAll(',', '')) ?? 0.0;
      final initialBalance = double.tryParse(_initialBalanceCtrl.text.replaceAll(',', '')) ?? 0.0;
      final linkedId = _type == AccountType.investment ? _linkedCashAccountId : null;

      if (widget.existing == null) {
        await repo.addAccount(
          user.uid,
          Account(
            id: const Uuid().v4(),
            userId: user.uid,
            name: _nameCtrl.text.trim(),
            type: _type,
            balance: isLiquid ? 0 : balance,
            initialBalance: isLiquid ? initialBalance : 0,
            currency: _currency,
            linkedCashAccountId: linkedId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await repo.updateAccount(
          user.uid,
          widget.existing!.copyWith(
            name: _nameCtrl.text.trim(),
            type: _type,
            balance: isLiquid ? 0 : balance,
            initialBalance: isLiquid ? initialBalance : 0,
            currency: _currency,
            linkedCashAccountId: linkedId,
            clearLinkedCashAccount: linkedId == null,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final navBarPadding = MediaQuery.paddingOf(context).bottom;
    final safeBottom = bottomInset > 0 ? bottomInset : navBarPadding;

    // Cash-eligible accounts: not investment, not this account, not already linked
    final allAccounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final linkedIds = ref.watch(linkedCashAccountIdsProvider);
    final cashCandidates = allAccounts.where((a) =>
        a.id != widget.existing?.id &&
        a.type != AccountType.investment &&
        (!linkedIds.contains(a.id) || a.id == _linkedCashAccountId)).toList();

    final screenHeight = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      child: Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 16, bottom: safeBottom + 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Text(
                  widget.existing == null ? 'Add Account' : 'Edit Account',
                  style: textTheme.headlineSmall,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ]),
              const SizedBox(height: 28),

              _FieldLabel(label: 'Account Name', isDark: isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w500),
                decoration: _inputDeco(isDark: isDark, hint: 'e.g. Robinhood'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              _FieldLabel(label: 'Type', isDark: isDark),
              const SizedBox(height: 10),
              _TypeSelector(
                  selected: _type,
                  isDark: isDark,
                  onChanged: (t) => setState(() {
                        _type = t;
                        if (t != AccountType.investment) {
                          _linkedCashAccountId = null;
                        }
                      })),
              const SizedBox(height: 20),

              if (_type.isLiquid) ...[
                _FieldLabel(label: 'Initial Balance', isDark: isDark),
                const SizedBox(height: 4),
                Text(
                  'Current balance is auto-calculated from your transactions',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _initialBalanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w500),
                  decoration: _inputDeco(isDark: isDark, hint: '0', prefixText: _symbol(_currency)),
                ),
              ] else ...[
                _FieldLabel(label: 'Balance', isDark: isDark),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w500),
                  decoration: _inputDeco(isDark: isDark, hint: '0', prefixText: _symbol(_currency)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.replaceAll(',', '')) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              _FieldLabel(label: 'Currency', isDark: isDark),
              const SizedBox(height: 10),
              Row(
                children: _currencies.map((c) {
                  final sel = _currency == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _currency = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.surfaceContainerLow),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(c,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondaryLight))),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Cash account link — only for investment accounts
              if (_type == AccountType.investment) ...[
                const SizedBox(height: 20),
                _FieldLabel(
                    label: 'Linked Cash Account (optional)', isDark: isDark),
                const SizedBox(height: 4),
                Text(
                  'Merge an uninvested-cash account into this tile',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.textTertiaryLight),
                ),
                const SizedBox(height: 8),
                _AccountPickerTile(
                  selectedId: _linkedCashAccountId,
                  candidates: cashCandidates,
                  isDark: isDark,
                  onSelected: (id) => setState(() => _linkedCashAccountId = id),
                ),
              ],

              const SizedBox(height: 32),
              PrimaryButton(
                label:
                    widget.existing == null ? 'Add Account' : 'Save Changes',
                onPressed: _save,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
      ), // ConstrainedBox
    );
  }

  InputDecoration _inputDeco(
      {required bool isDark, required String hint, String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor:
          isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.negative, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.negative, width: 1.5)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _symbol(String currency) {
    switch (currency) {
      case 'KRW': return '₩';
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'JPY': return '¥';
      default:    return currency;
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: isDark
              ? AppColors.textSecondary
              : AppColors.textSecondaryLight,
        ),
      );
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector(
      {required this.selected,
      required this.isDark,
      required this.onChanged});
  final AccountType selected;
  final bool isDark;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AccountType.values.map((type) {
            final isSel = type == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.surfaceContainerLow),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSel
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(type.icon,
                        size: 14,
                        color: isSel
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight)),
                    const SizedBox(width: 6),
                    Text(type.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLight))),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// ── Account Picker (opens a bottom sheet — avoids nav-bar clipping) ───────────

class _AccountPickerTile extends StatelessWidget {
  const _AccountPickerTile({
    required this.selectedId,
    required this.candidates,
    required this.isDark,
    required this.onSelected,
  });

  final String? selectedId;
  final List<Account> candidates;
  final bool isDark;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedName = candidates
        .where((a) => a.id == selectedId)
        .map((a) => a.name)
        .firstOrNull;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              selectedName ?? 'None',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: selectedName != null
                    ? (isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)
                    : (isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
              ),
            ),
          ),
          Icon(Icons.expand_more_rounded,
              size: 20,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDarkPicker = Theme.of(ctx).brightness == Brightness.dark;
        final bottomPadding = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          decoration: BoxDecoration(
            color: isDarkPicker ? AppColors.darkCard : AppColors.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding + 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDarkPicker
                        ? AppColors.darkBorder
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // None option
                      ListTile(
                        title: const Text('None'),
                        leading: Icon(Icons.remove_circle_outline_rounded,
                            color: isDarkPicker
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight),
                        trailing: selectedId == null
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.primary, size: 18)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(null);
                        },
                      ),
                      ...candidates.map((a) => ListTile(
                            title: Text(a.name),
                            subtitle: Text(a.type.label),
                            leading: Icon(a.type.icon,
                                color: AppColors.primary, size: 20),
                            trailing: selectedId == a.id
                                ? const Icon(Icons.check_rounded,
                                    color: AppColors.primary, size: 18)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              onSelected(a.id);
                            },
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
