import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/repositories/i_sheets_repository.dart';
import '../models/sheet_transaction_model.dart';

/// Talks to the Google Apps Script web app backing the sheet.
/// - GET  → returns all transaction rows as JSON.
/// - POST → appends row(s) for a new transaction.
class SheetsRepositoryImpl implements ISheetsRepository {
  const SheetsRepositoryImpl({this.client});

  /// Injectable for tests; defaults to a one-shot [http.Client] per call.
  final http.Client? client;

  static const _timeout = Duration(seconds: 15);

  @override
  Future<Result<List<SheetTransaction>>> fetchTransactions() async {
    if (AppConfig.sheetsWebAppUrl.isEmpty) {
      return const Failure('Google Sheet is not configured. Set '
          'AppConfig.sheetsWebAppUrl in lib/core/config/app_config.dart.');
    }

    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(AppConfig.sheetsWebAppUrl).replace(
        queryParameters: {
          if (AppConfig.sheetsApiKey.isNotEmpty) 'apiKey': AppConfig.sheetsApiKey,
        },
      );
      final resp = await c.get(uri).timeout(_timeout);

      if (resp.statusCode != 200) {
        return Failure('Sheet returned ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      final rawRows = decoded is Map<String, dynamic>
          ? (decoded['rows'] as List? ?? const [])
          : (decoded as List? ?? const []);

      final txs = rawRows
          .whereType<Map>()
          .map((r) => SheetTransactionModel.fromJson(
              r.map((k, v) => MapEntry(k.toString(), v))))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // newest first

      return Success(txs);
    } catch (e) {
      debugPrint('SheetsRepository.fetch: $e');
      return Failure(e);
    } finally {
      if (client == null) c.close();
    }
  }

  @override
  Future<Result<void>> appendTransaction(SheetTransaction tx) async {
    if (AppConfig.sheetsWebAppUrl.isEmpty) {
      return const Failure('Google Sheet is not configured.');
    }

    final c = client ?? http.Client();
    try {
      final body = <String, dynamic>{
        'rows': SheetTransactionModel.toRows(tx),
        if (AppConfig.sheetsApiKey.isNotEmpty) 'apiKey': AppConfig.sheetsApiKey,
      };

      final resp = await c
          .post(
            Uri.parse(AppConfig.sheetsWebAppUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (resp.statusCode != 200) {
        return Failure('Sheet returned ${resp.statusCode}: ${resp.body}');
      }
      return const Success(null);
    } catch (e) {
      debugPrint('SheetsRepository.append: $e');
      return Failure(e);
    } finally {
      if (client == null) c.close();
    }
  }
}
