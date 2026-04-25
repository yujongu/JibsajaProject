import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/i_sheets_sync_repository.dart';

class SheetsSyncRepositoryImpl implements ISheetsSyncRepository {
  const SheetsSyncRepositoryImpl();

  // Apps Script web app URL. Leave empty to disable (silently skips).
  static const String webAppUrl =
      'https://script.google.com/macros/s/AKfycbz7PwYJ4s1HSKX4Kx4ojrBZ-6uWyz80MqvJafXvQwU00UM3KrF7YacDBrAeG4Lw5Mml/exec';
  static const String apiKey = 'jibsaja-secret-2024-xk9m';

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
    if (webAppUrl.isEmpty) return;

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
    if (webAppUrl.isEmpty) return;

    final dateStr = date.toIso8601String();
    final debitRow = [dateStr, fromAccountName, 'Transfer', '', 'Transfer Out', '', '', '', -amount, debitTxId];
    final creditRow = [dateStr, toAccountName, 'Transfer', '', 'Transfer In', '', '', '', amount, creditTxId];

    await _post({'rows': [debitRow, creditRow]});
  }

  Future<void> _post(Map<String, dynamic> body) async {
    try {
      body['apiKey'] = apiKey;
      final resp = await http
          .post(
            Uri.parse(webAppUrl),
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
