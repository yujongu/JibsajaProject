import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/exchange_rate_repository_impl.dart';
import '../../domain/repositories/i_exchange_rate_repository.dart';

final exchangeRateRepositoryProvider = Provider<IExchangeRateRepository>((ref) {
  return const ExchangeRateRepositoryImpl();
});

final exchangeRateProvider = FutureProvider<double>((ref) {
  return ref.watch(exchangeRateRepositoryProvider).fetchUsdToKrw();
});

/// Convenience: returns the rate synchronously with 1400 fallback.
double usdToKrw(AsyncValue<double> rateAsync) =>
    rateAsync.valueOrNull ?? 1400.0;
