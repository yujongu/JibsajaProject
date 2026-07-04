import '../entities/dashboard_summary.dart';
import '../entities/result.dart';
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

  /// The rows from the last successful [fetchTransactions], persisted
  /// on-device, or null when nothing usable is cached. Synchronous and
  /// best-effort so startup can render before the live fetch lands.
  List<SheetTransaction>? cachedTransactions();

  /// The snapshot from the last successful [fetchDashboard], persisted
  /// on-device, or null when nothing usable is cached.
  DashboardSummary? cachedDashboard();

  /// When the cached transactions were fetched from the sheet — i.e. how old
  /// the data currently shown is. Null when nothing is cached.
  DateTime? cachedTransactionsAt();

  /// When the cached dashboard snapshot was fetched from the sheet.
  DateTime? cachedDashboardAt();
}
