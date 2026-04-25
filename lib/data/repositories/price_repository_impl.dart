import 'dart:convert';
import 'dart:io';

import '../../domain/repositories/i_price_repository.dart';

class PriceRepositoryImpl implements IPriceRepository {
  const PriceRepositoryImpl();

  static const _cryptoIds = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'BNB': 'binancecoin',
    'SOL': 'solana',
    'XRP': 'ripple',
    'ADA': 'cardano',
    'DOGE': 'dogecoin',
    'MATIC': 'matic-network',
    'POL': 'matic-network',
    'DOT': 'polkadot',
    'SHIB': 'shiba-inu',
    'AVAX': 'avalanche-2',
    'LINK': 'chainlink',
    'LTC': 'litecoin',
    'UNI': 'uniswap',
    'ATOM': 'cosmos',
    'XLM': 'stellar',
    'ALGO': 'algorand',
    'VET': 'vechain',
    'ICP': 'internet-computer',
    'FIL': 'filecoin',
    'TRX': 'tron',
    'ETC': 'ethereum-classic',
    'NEAR': 'near',
    'APT': 'aptos',
    'ARB': 'arbitrum',
    'OP': 'optimism',
    'SUI': 'sui',
    'SEI': 'sei-network',
    'INJ': 'injective-protocol',
    'PEPE': 'pepe',
    'WIF': 'dogwifcoin',
    'BONK': 'bonk',
    'TON': 'the-open-network',
    'FLOKI': 'floki',
    'SAND': 'the-sandbox',
    'MANA': 'decentraland',
    'AXS': 'axie-infinity',
    'CRO': 'crypto-com-chain',
    'FTM': 'fantom',
    'AAVE': 'aave',
    'CAKE': 'pancakeswap-token',
    'GRT': 'the-graph',
    'MKR': 'maker',
    'SNX': 'synthetix-network-token',
    'LDO': 'lido-dao',
    'STX': 'blockstack',
    'IMX': 'immutable-x',
    'RUNE': 'thorchain',
    'EGLD': 'elrond-erd-2',
  };

  static bool _isKoreanTicker(String ticker) =>
      RegExp(r'^\d{4,6}$').hasMatch(ticker);

  @override
  Future<double?> fetchStockPrice(String ticker, String currency) async {
    if (currency == 'KRW' || _isKoreanTicker(ticker)) {
      final price = await _yahooPrice('$ticker.KS');
      if (price != null) return price;
      return _yahooPrice('$ticker.KQ');
    }
    return _yahooPrice(ticker);
  }

  @override
  Future<double?> fetchCryptoPrice(String symbol, String currency) async {
    final coinId = _cryptoIds[symbol.toUpperCase()];
    if (coinId == null) return null;
    final vs = currency.toLowerCase() == 'krw' ? 'krw' : 'usd';
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price?ids=$coinId&vs_currencies=$vs');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json[coinId]?[vs] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<double?> _yahooPrice(String ticker) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$ticker?interval=1d&range=1d');
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      req.headers.set('Accept', 'application/json');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final results = json['chart']?['result'] as List?;
      if (results == null || results.isEmpty) return null;
      return (results.first['meta']?['regularMarketPrice'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }
}
