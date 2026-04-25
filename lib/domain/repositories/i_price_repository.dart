abstract class IPriceRepository {
  Future<double?> fetchStockPrice(String ticker, String currency);
  Future<double?> fetchCryptoPrice(String symbol, String currency);
}
