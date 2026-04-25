import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/price_repository_impl.dart';
import '../../domain/entities/holding.dart';
import '../../domain/entities/holding_type.dart';
import '../../domain/repositories/i_price_repository.dart';
import 'holding_providers.dart';

final priceRepositoryProvider = Provider<IPriceRepository>((ref) {
  return const PriceRepositoryImpl();
});

/// Fetches live market prices for all unique tickers in computed holdings.
/// Returns Map<'ticker:currency', price> in each holding's native currency.
final livePricesProvider = FutureProvider<Map<String, double>>((ref) async {
  final holdings = ref.watch(computedHoldingsProvider);
  if (holdings.isEmpty) return {};

  final unique = <String, Holding>{};
  for (final h in holdings) {
    unique.putIfAbsent('${h.ticker}:${h.currency}', () => h);
  }

  final repo = ref.watch(priceRepositoryProvider);
  final results = <String, double>{};
  await Future.wait(
    unique.entries.map((entry) async {
      final h = entry.value;
      final price = h.type == HoldingType.crypto
          ? await repo.fetchCryptoPrice(h.ticker, h.currency)
          : await repo.fetchStockPrice(h.ticker, h.currency);
      if (price != null && price > 0) results[entry.key] = price;
    }),
  );
  return results;
});
