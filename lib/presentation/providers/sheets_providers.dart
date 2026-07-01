import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sheets_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/repositories/i_sheets_repository.dart';

/// Single data boundary for the whole app.
final sheetsRepositoryProvider = Provider<ISheetsRepository>(
  (_) => const SheetsRepositoryImpl(),
);

/// All transaction rows from the sheet (newest first).
///
/// Throws on failure so the UI can render the error via `AsyncValue.when`.
/// Refresh with `ref.invalidate(transactionsProvider)`.
final transactionsProvider =
    FutureProvider<List<SheetTransaction>>((ref) async {
  final repo = ref.watch(sheetsRepositoryProvider);
  final result = await repo.fetchTransactions();
  return result.when(
    success: (txs) => txs,
    failure: (e) => throw e,
  );
});

/// Pre-computed portfolio snapshot from the `DashboardDB1` tab.
///
/// Throws on failure so the UI can render the error via `AsyncValue.when`.
/// Refresh with `ref.invalidate(dashboardProvider)`.
final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final repo = ref.watch(sheetsRepositoryProvider);
  final result = await repo.fetchDashboard();
  return result.when(
    success: (d) => d,
    failure: (e) => throw e,
  );
});

/// All-time aggregates (total spending, net invested, spend by category),
/// derived from the loaded rows. Yields zero totals while loading / on error.
final transactionSummaryProvider = Provider<TransactionSummary>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  return txs.summarize();
});

/// Transactions grouped by calendar month (newest month first, newest row
/// first within a month), for the grouped list view. Empty while loading.
final transactionsByMonthProvider = Provider<List<MonthGroup>>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  return txs.groupByMonth();
});

/// Distinct account names seen in the sheet, for the add-row dropdown.
/// Empty while loading or on error — the form still allows free-text entry.
final accountNamesProvider = Provider<List<String>>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final names = <String>{
    for (final t in txs)
      if (t.account.trim().isNotEmpty) t.account.trim(),
  }.toList()
    ..sort();
  return names;
});
