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
}
