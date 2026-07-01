import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/repositories/i_sheets_repository.dart';
import '../models/dashboard_summary_model.dart';
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

      // Apps Script serves its own error pages (e.g. a missing doGet) as HTML
      // with a 200 status, so guard against decoding HTML as JSON.
      if (resp.body.trimLeft().startsWith('<')) {
        return const Failure(
            'Sheet endpoint returned HTML, not JSON. The Apps Script web app '
            'is likely deployed without a doGet function or an outdated '
            'version. Redeploy docs/apps_script/Code.gs as a new version with '
            'access set to "Anyone".');
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
  Future<Result<DashboardSummary>> fetchDashboard() async {
    if (AppConfig.sheetsWebAppUrl.isEmpty) {
      return const Failure('Google Sheet is not configured. Set '
          'AppConfig.sheetsWebAppUrl in lib/core/config/app_config.dart.');
    }

    final c = client ?? http.Client();
    try {
      final uri = Uri.parse(AppConfig.sheetsWebAppUrl).replace(
        queryParameters: {
          'sheet': DashboardSummaryModel.sheetName,
          if (AppConfig.sheetsApiKey.isNotEmpty) 'apiKey': AppConfig.sheetsApiKey,
        },
      );
      final resp = await c.get(uri).timeout(_timeout);

      if (resp.statusCode != 200) {
        return Failure('Sheet returned ${resp.statusCode}: ${resp.body}');
      }
      // Apps Script serves its own error pages as HTML with a 200 status.
      if (resp.body.trimLeft().startsWith('<')) {
        return const Failure(
            'Sheet endpoint returned HTML, not JSON. The Apps Script web app '
            'is likely deployed without a doGet function or an outdated '
            'version. Redeploy docs/apps_script/Code.gs as a new version with '
            'access set to "Anyone".');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return const Failure('Unexpected dashboard response shape.');
      }
      // The endpoint reports its own failures as {"error": "..."} with 200.
      final error = decoded['error'];
      if (error != null) {
        return Failure('Sheet error: $error');
      }

      final rawGrid = decoded['grid'] as List? ?? const [];
      final grid = rawGrid
          .map<List<dynamic>>((row) => row is List ? row : const [])
          .toList();

      return Success(DashboardSummaryModel.fromGrid(grid));
    } catch (e) {
      debugPrint('SheetsRepository.fetchDashboard: $e');
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
      if (resp.body.trimLeft().startsWith('<')) {
        return const Failure(
            'Sheet endpoint returned HTML, not JSON. The Apps Script web app '
            'is likely deployed without a doPost function or an outdated '
            'version. Redeploy docs/apps_script/Code.gs as a new version.');
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
