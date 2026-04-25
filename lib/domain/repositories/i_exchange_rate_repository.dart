abstract class IExchangeRateRepository {
  /// Returns the live USD → KRW exchange rate, falling back to 1400 on failure.
  Future<double> fetchUsdToKrw();
}
