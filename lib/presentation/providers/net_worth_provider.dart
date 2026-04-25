import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/use_cases/calculate_net_worth.dart';
import 'account_providers.dart';
import 'card_providers.dart';
import 'exchange_rate_provider.dart';
import 'holding_providers.dart';

double _toKrw(double amount, String currency, double rate) =>
    currency == 'USD' ? amount * rate : amount;

final _calculateNetWorthProvider = Provider<CalculateNetWorth>((ref) {
  return const CalculateNetWorth();
});

/// Total net worth in KRW.
final totalNetWorthProvider = Provider<double>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  final cards = ref.watch(cardsStreamProvider).valueOrNull ?? const [];
  final rate = usdToKrw(ref.watch(exchangeRateProvider));
  return ref.watch(_calculateNetWorthProvider)(
    accounts: accounts,
    holdings: holdings,
    cards: cards,
    usdToKrwRate: rate,
  );
});

final totalPortfolioInKrwProvider = Provider<double>((ref) {
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  final rate = usdToKrw(ref.watch(exchangeRateProvider));
  return holdings.fold(
      0.0, (sum, h) => sum + _toKrw(h.totalValue, h.currency, rate));
});

final totalPortfolioGainLossInKrwProvider = Provider<double>((ref) {
  final holdings = ref.watch(holdingsWithLivePricesProvider);
  final rate = usdToKrw(ref.watch(exchangeRateProvider));
  return holdings.fold(
      0.0, (sum, h) => sum + _toKrw(h.gainLoss, h.currency, rate));
});
