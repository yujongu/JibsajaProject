import '../entities/dashboard_summary.dart';
import '../entities/result.dart';
import '../entities/sheet_account.dart';
import '../entities/sheet_holding.dart';
import '../entities/sheet_transaction.dart';

/// The single data boundary of the app: read rows from the Google Sheet and
/// append new transaction rows to it.
abstract class ISheetsRepository {
  /// Fetches all transaction rows from the sheet (newest first).
  Future<Result<List<SheetTransaction>>> fetchTransactions();

  /// Appends a single transaction as one or more rows to the sheet.
  Future<Result<void>> appendTransaction(SheetTransaction tx);

  /// Fetches the pre-computed portfolio snapshot from the `DashboardDB1` tab.
  Future<Result<DashboardSummary>> fetchDashboard();

  /// Fetches the `Accounts` tab, which names each account's currency. Read
  /// only — the app never appends to or edits that tab.
  Future<Result<List<SheetAccount>>> fetchAccounts();

  /// Fetches the `Holdings` tab — one row per stock position. Read only.
  Future<Result<List<SheetHolding>>> fetchHoldings();

  /// The rows from the last successful [fetchTransactions], persisted
  /// on-device, or null when nothing usable is cached. Synchronous and
  /// best-effort so startup can render before the live fetch lands.
  List<SheetTransaction>? cachedTransactions();

  /// The snapshot from the last successful [fetchDashboard], persisted
  /// on-device, or null when nothing usable is cached.
  DashboardSummary? cachedDashboard();

  /// The accounts from the last successful [fetchAccounts], persisted
  /// on-device, or null when nothing usable is cached.
  List<SheetAccount>? cachedAccounts();

  /// The positions from the last successful [fetchHoldings], persisted
  /// on-device, or null when nothing usable is cached.
  List<SheetHolding>? cachedHoldings();

  /// When the cached transactions were fetched from the sheet — i.e. how old
  /// the data currently shown is. Null when nothing is cached.
  DateTime? cachedTransactionsAt();

  /// When the cached dashboard snapshot was fetched from the sheet.
  DateTime? cachedDashboardAt();

  /// When the cached accounts were fetched from the sheet.
  DateTime? cachedAccountsAt();

  /// When the cached holdings were fetched from the sheet.
  DateTime? cachedHoldingsAt();
}
