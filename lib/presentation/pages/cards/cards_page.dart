import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/firestore_error_card.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../../domain/entities/bank_card.dart';
import '../../../domain/entities/card_type.dart';
import '../../providers/card_providers.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/cards/card_form_sheet.dart';

class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  final _creditCardKey = GlobalKey();

  double _creditCardBottom() {
    final box = _creditCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    return box.localToGlobal(Offset.zero).dy + box.size.height;
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final cardsAsync = ref.watch(cardsStreamProvider);
    final totalCredit = ref.watch(totalCreditAvailableProvider);

    return FeatureScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: 0,
          left: 20,
          right: 20,
          bottom: 120,
        ),
        children: [
          Row(
            children: [
              Text('Cards', style: textTheme.headlineLarge),
              const Spacer(),
              GlassIconButton(
                icon: Icons.add_rounded,
                onPressed: () => showCardFormSheet(
                  context,
                  anchorBottom: _creditCardBottom(),
                ),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Credit and debit cards',
            style: textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 24),

          // Total Credit Available card — key used to anchor the Add Card sheet
          GlassCard(
            key: _creditCardKey,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card Balance',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₩${NumberFormat('#,###').format(totalCredit.toInt())}',
                        style: textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: Color(0xFFA78BFA),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text('My Cards', style: textTheme.headlineSmall),
          const SizedBox(height: 12),

          cardsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => FirestoreErrorCard(error: e, isDark: isDark),
            data: (cards) {
              if (cards.isEmpty) return _EmptyCardsState(isDark: isDark);
              return Column(
                children: cards.map((c) => _CardTile(card: c, isDark: isDark)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card, required this.isDark});
  final BankCard card;
  final bool isDark;

  static const _cardColor = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'en_US');
    final sym = card.currency == 'KRW'
        ? '₩'
        : card.currency == 'USD'
            ? '\$'
            : '€';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(card.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.negative.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: AppColors.negative, size: 22),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _delete(context, ref),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showCardFormSheet(context, existing: card),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _cardColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.credit_card_rounded,
                      size: 20, color: _cardColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '•••• ${card.last4Digits}  ·  ${card.type.label}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sym${formatter.format(card.balance.toInt())}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: card.type == CardType.credit
                            ? AppColors.negative
                            : (isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
                      ),
                    ),
                    if (card.creditLimit != null)
                      Text(
                        'of $sym${formatter.format(card.creditLimit!.toInt())}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Card'),
          content: Text('Remove "${card.name}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await ref.read(cardRepositoryProvider).deleteCard(user.uid, card.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }
}

class _EmptyCardsState extends StatelessWidget {
  const _EmptyCardsState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.credit_card_outlined,
              size: 40,
              color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
          const SizedBox(height: 12),
          Text('No cards yet', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap + to add a credit or debit card',
            style: textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: 'Add Card',
            icon: Icons.add_rounded,
            onPressed: () => showCardFormSheet(context),
          ),
        ],
      ),
    );
  }
}
