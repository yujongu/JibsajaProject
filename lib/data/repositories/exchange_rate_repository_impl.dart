import 'dart:convert';
import 'dart:io';

import '../../domain/repositories/i_exchange_rate_repository.dart';

class ExchangeRateRepositoryImpl implements IExchangeRateRepository {
  const ExchangeRateRepositoryImpl();

  static const _fallback = 1400.0;

  @override
  Future<double> fetchUsdToKrw() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(
        Uri.parse('https://open.er-api.com/v6/latest/USD'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['result'] != 'success') return _fallback;
      final rates = json['rates'] as Map<String, dynamic>;
      return (rates['KRW'] as num).toDouble();
    } catch (_) {
      return _fallback;
    }
  }
}
