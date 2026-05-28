import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/holding_repository_impl.dart';
import '../../domain/entities/holding.dart';
import '../../domain/repositories/i_holding_repository.dart';
import '../../domain/use_cases/compute_holdings.dart';
import 'account_providers.dart';
import 'firebase_providers.dart';
import 'price_provider.dart';
import 'transaction_providers.dart';

final holdingRepositoryProvider = Provider<IHoldingRepository>((ref) {
  return HoldingRepositoryImpl(ref.watch(firestoreProvider));
});

final _computeHoldingsProvider = Provider<ComputeHoldings>((ref) {
  return const ComputeHoldings();
});

/// Per-account holdings derived from buy/sell transactions (average cost method).
final computedHoldingsProvider = Provider<List<Holding>>((ref) {
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
  return ref.watch(_computeHoldingsProvider)(
    transactions: txs,
    accounts: accounts,
  );
});

final holdingsForAccountProvider =
    Provider.family<List<Holding>, String>((ref, accountId) {
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  return holdings.where((h) => h.accountId == accountId).toList();
});

final holdingsWithLivePricesProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(computedHoldingsProvider);
  final prices = ref.watch(livePricesProvider).valueOrNull ?? const {};
  return holdings.map((h) {
    final live = prices['${h.ticker}:${h.currency}'];
    return live != null ? h.copyWith(currentPrice: live) : h;
  }).toList();
});

final aggregateHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  final byTicker = <String, List<Holding>>{};
  for (final h in holdings) {
    byTicker.putIfAbsent(h.ticker, () => []).add(h);
  }
  return byTicker.entries.map((e) {
    final list = e.value;
    final totalQty = list.fold(0.0, (s, h) => s + h.quantity);
    final totalCost = list.fold(0.0, (s, h) => s + h.totalCost);
    final totalValue = list.fold(0.0, (s, h) => s + h.totalValue);
    final avgCost = totalQty > 0 ? totalCost / totalQty : 0.0;
    final avgPrice = totalQty > 0 ? totalValue / totalQty : 0.0;
    final first = list.first;
    return Holding(
      id: 'agg:${e.key}',
      userId: first.userId,
      name: first.name,
      ticker: e.key,
      type: first.type,
      quantity: totalQty,
      avgCostPrice: avgCost,
      currentPrice: avgPrice,
      currency: first.currency,
      accountId: null,
      createdAt: first.createdAt,
      updatedAt: first.updatedAt,
    );
  }).toList()
    ..sort((a, b) => b.totalValue.compareTo(a.totalValue));
});

final totalPortfolioValueProvider = Provider<double>((ref) {
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  return holdings.fold(0.0, (total, h) => total + h.totalValue);
});

final totalPortfolioGainLossProvider = Provider<double>((ref) {
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  return holdings.fold(0.0, (total, h) => total + h.gainLoss);
});
