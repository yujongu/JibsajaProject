import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/i_sheets_sync_repository.dart';

class SheetsSyncRepositoryImpl implements ISheetsSyncRepository {
  const SheetsSyncRepositoryImpl();

  @override
  Future<void> appendTradeRows({
    required DateTime date,
    required String investAccountName,
    required String cashAccountName,
    required TransactionType type,
    required String ticker,
    required String assetName,
    required double quantity,
    required double price,
    required double amount,
    required String tradeTxId,
    required String transferTxId,
  }) async {
    if (AppConfig.sheetsWebAppUrl.isEmpty) return;

    final isBuy = type == TransactionType.buy;
    final dateStr = date.toIso8601String();

    final tradeRow = [
      dateStr,
      investAccountName,
      isBuy ? 'Buy' : 'Sell',
      'investment',
      assetName,
      ticker,
      quantity,
      price,
      amount,
      tradeTxId,
    ];
    final transferRow = [
      dateStr,
      cashAccountName,
      'Transfer',
      '',
      isBuy ? 'Transfer Out' : 'Transfer In',
      '',
      '',
      '',
      isBuy ? -amount : amount,
      transferTxId,
    ];

    await _post({'rows': [tradeRow, transferRow]});
    debugPrint('SheetsSync: appended ${isBuy ? "Buy" : "Sell"} rows for $ticker');
  }

  @override
  Future<void> appendTransferRows({
    required DateTime date,
    required String fromAccountName,
    required String toAccountName,
    required double amount,
    required String debitTxId,
    required String creditTxId,
  }) async {
    if (AppConfig.sheetsWebAppUrl.isEmpty) return;

    final dateStr = date.toIso8601String();
    final debitRow = [dateStr, fromAccountName, 'Transfer', '', 'Transfer Out', '', '', '', -amount, debitTxId];
    final creditRow = [dateStr, toAccountName, 'Transfer', '', 'Transfer In', '', '', '', amount, creditTxId];

    await _post({'rows': [debitRow, creditRow]});
  }

  Future<void> _post(Map<String, dynamic> body) async {
    try {
      body['apiKey'] = AppConfig.sheetsApiKey;
      final resp = await http
          .post(
            Uri.parse(AppConfig.sheetsWebAppUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        debugPrint('SheetsSync error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('SheetsSync: $e');
    }
  }
}
