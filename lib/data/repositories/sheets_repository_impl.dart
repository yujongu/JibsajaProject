import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_account.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/repositories/i_sheets_repository.dart';
import '../datasources/sheets_local_cache.dart';
import '../models/dashboard_summary_model.dart';
import '../models/sheet_account_model.dart';
import '../models/sheet_transaction_model.dart';

/// Talks to the Google Apps Script web app backing the sheet.
/// - GET  → returns all transaction rows as JSON.
/// - POST → appends row(s) for a new transaction.
class SheetsRepositoryImpl implements ISheetsRepository {
  const SheetsRepositoryImpl({
    required this.webAppUrl,
    this.apiKey = '',
    this.client,
    this.cache,
  });

  /// The Apps Script web app `/exec` URL to talk to. Injected (from the
  /// active [SheetProfile]) so the sheet can be switched at runtime; an
  /// empty value keeps the "not configured" Failure behavior.
  final String webAppUrl;

  /// Shared secret sent with each request; may be empty.
  final String apiKey;

  /// Injectable for tests; defaults to a one-shot [http.Client] per call.
  final http.Client? client;

  /// Optional on-device cache of the last successful responses; when absent,
  /// [cachedTransactions] and [cachedDashboard] simply return null.
  final SheetsLocalCache? cache;

  /// The `DashboardDB1` tab's live formulas make its read take ~10–13s, so the
  /// timeout must clear that with margin — a tighter bound tears the socket down
  /// mid-response on mobile ("software caused connection abort").
  static const _timeout = Duration(seconds: 30);

  /// GETs are idempotent, so retry a transient transport failure once with a
  /// fresh connection before giving up.
  static const _maxGetAttempts = 2;

  /// Runs an idempotent GET with a per-attempt timeout, retrying transient
  /// transport errors (e.g. connection aborts) and transient HTTP statuses
  /// (429/5xx — Apps Script answers concurrent cold-start bursts with these)
  /// on a fresh client. When a [client] is injected (tests) it is reused
  /// as-is and never retried/closed.
  Future<http.Response> _get(Uri uri) async {
    Object lastError = StateError('no attempts made');
    for (var attempt = 1; attempt <= _maxGetAttempts; attempt++) {
      final c = client ?? http.Client();
      try {
        final resp = await c.get(uri).timeout(_timeout);
        if (client == null &&
            attempt < _maxGetAttempts &&
            (resp.statusCode == 429 || resp.statusCode >= 500)) {
          debugPrint('SheetsRepository._get: attempt $attempt got '
              '${resp.statusCode}, retrying');
          continue;
        }
        return resp;
      } on Exception catch (e) {
        lastError = e;
        if (client != null || attempt == _maxGetAttempts) rethrow;
        debugPrint('SheetsRepository._get: attempt $attempt failed ($e), retrying');
      } finally {
        if (client == null) c.close();
      }
    }
    throw lastError; // unreachable: last attempt rethrows above.
  }

  @override
  Future<Result<List<SheetTransaction>>> fetchTransactions() async {
    if (webAppUrl.isEmpty) {
      return const Failure(
          'Google Sheet is not configured. Set the sheet URL in Settings.');
    }

    try {
      final uri = Uri.parse(webAppUrl).replace(
        queryParameters: {
          if (apiKey.isNotEmpty) 'apiKey': apiKey,
        },
      );
      final resp = await _get(uri);

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

      final txs = _parseTransactionsBody(resp.body);
      // Persist the raw body only after it parsed, so a later cache read
      // can't hit junk.
      cache?.writeTransactions(resp.body);
      return Success(txs);
    } catch (e) {
      debugPrint('SheetsRepository.fetch: $e');
      return Failure(e);
    }
  }

  static List<SheetTransaction> _parseTransactionsBody(String body) {
    final decoded = jsonDecode(body);
    final rawRows = decoded is Map<String, dynamic>
        ? (decoded['rows'] as List? ?? const [])
        : (decoded as List? ?? const []);

    // The list index is the row's sheet position — kept as the sort
    // tiebreaker so same-timestamp rows stay in a deterministic order.
    return [
      for (var i = 0; i < rawRows.length; i++)
        if (rawRows[i] case final Map r)
          SheetTransactionModel.fromJson(
              r.map((k, v) => MapEntry(k.toString(), v)),
              rowIndex: i),
    ]..sort(SheetTransaction.newestFirst);
  }

  @override
  List<SheetTransaction>? cachedTransactions() {
    final body = cache?.readTransactions();
    if (body == null) return null;
    try {
      return _parseTransactionsBody(body);
    } catch (e) {
      debugPrint('SheetsRepository.cachedTransactions: $e');
      return null;
    }
  }

  @override
  Future<Result<DashboardSummary>> fetchDashboard() async {
    if (webAppUrl.isEmpty) {
      return const Failure(
          'Google Sheet is not configured. Set the sheet URL in Settings.');
    }

    try {
      final uri = Uri.parse(webAppUrl).replace(
        queryParameters: {
          'sheet': DashboardSummaryModel.sheetName,
          if (apiKey.isNotEmpty) 'apiKey': apiKey,
        },
      );
      final resp = await _get(uri);

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

      final parsed = _parseDashboardBody(resp.body);
      if (parsed.isSuccess) {
        cache?.writeDashboard(resp.body);
      }
      return parsed;
    } catch (e) {
      debugPrint('SheetsRepository.fetchDashboard: $e');
      return Failure(e);
    }
  }

  static Result<DashboardSummary> _parseDashboardBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return const Failure('Unexpected dashboard response shape.');
    }
    // The endpoint reports its own failures as {"error": "..."} with 200.
    final error = decoded['error'];
    if (error != null) {
      return Failure('Sheet error: $error');
    }

    // A deployed Apps Script that predates ?sheet= support ignores the param
    // and answers with the transactions {"rows": ...} payload instead — every
    // KPI would silently parse as 0, so fail loudly with the redeploy hint.
    final rawGrid = decoded['grid'];
    if (rawGrid is! List) {
      return const Failure(
          'Dashboard response has no "grid" — the deployed Apps Script is an '
          'old version without ?sheet= support. Redeploy '
          'docs/apps_script/Code.gs as a new version (Deploy → Manage '
          'deployments → Edit → New version).');
    }
    final grid = rawGrid
        .map<List<dynamic>>((row) => row is List ? row : const [])
        .toList();

    return Success(DashboardSummaryModel.fromGrid(grid));
  }

  @override
  DashboardSummary? cachedDashboard() {
    final body = cache?.readDashboard();
    if (body == null) return null;
    try {
      return _parseDashboardBody(body).valueOrNull;
    } catch (e) {
      debugPrint('SheetsRepository.cachedDashboard: $e');
      return null;
    }
  }

  @override
  Future<Result<List<SheetAccount>>> fetchAccounts() async {
    if (webAppUrl.isEmpty) {
      return const Failure(
          'Google Sheet is not configured. Set the sheet URL in Settings.');
    }

    try {
      final uri = Uri.parse(webAppUrl).replace(
        queryParameters: {
          'sheet': SheetAccountModel.sheetName,
          if (apiKey.isNotEmpty) 'apiKey': apiKey,
        },
      );
      final resp = await _get(uri);

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

      final accounts = _parseAccountsBody(resp.body);
      cache?.writeAccounts(resp.body);
      return Success(accounts);
    } catch (e) {
      debugPrint('SheetsRepository.fetchAccounts: $e');
      return Failure(e);
    }
  }

  /// Unlike the dashboard, an unusable `Accounts` response is **not** an error:
  /// the tab only supplies currency labels, so a missing tab or an unexpected
  /// shape degrades to "no currencies known" (bare amounts) rather than
  /// breaking the Transactions page.
  static List<SheetAccount> _parseAccountsBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    if (decoded['error'] != null) return const [];

    final rawGrid = decoded['grid'];
    if (rawGrid is! List) return const [];
    final grid = rawGrid
        .map<List<dynamic>>((row) => row is List ? row : const [])
        .toList();

    return SheetAccountModel.fromGrid(grid);
  }

  @override
  List<SheetAccount>? cachedAccounts() {
    final body = cache?.readAccounts();
    if (body == null) return null;
    try {
      return _parseAccountsBody(body);
    } catch (e) {
      debugPrint('SheetsRepository.cachedAccounts: $e');
      return null;
    }
  }

  @override
  DateTime? cachedTransactionsAt() => cache?.transactionsTimestamp();

  @override
  DateTime? cachedDashboardAt() => cache?.dashboardTimestamp();

  @override
  DateTime? cachedAccountsAt() => cache?.accountsTimestamp();

  @override
  Future<Result<void>> appendTransaction(SheetTransaction tx) async {
    if (webAppUrl.isEmpty) {
      return const Failure('Google Sheet is not configured.');
    }

    final c = client ?? http.Client();
    try {
      final body = <String, dynamic>{
        'rows': SheetTransactionModel.toRows(tx),
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      };

      final resp = await c
          .post(
            Uri.parse(webAppUrl),
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
