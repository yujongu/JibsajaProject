import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/sheets_local_cache.dart';
import '../../data/repositories/logging_sheets_repository.dart';
import '../../data/repositories/sheets_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/repositories/i_sheets_repository.dart';
import 'audit_log_providers.dart';
import 'preferences_providers.dart';
import 'sheet_profile_providers.dart';

export 'preferences_providers.dart' show sharedPreferencesProvider;

/// Single data boundary for the whole app, built against the **active**
/// sheet profile. Switching the profile rebuilds this provider, and because
/// [transactionsProvider] / [dashboardProvider] watch it, they refetch
/// against the new sheet automatically. Wrapped in [LoggingSheetsRepository]
/// so every mutation lands in the local audit log.
final sheetsRepositoryProvider = Provider<ISheetsRepository>((ref) {
  final active = ref.watch(activeSheetProfileProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return LoggingSheetsRepository(
    delegate: SheetsRepositoryImpl(
      webAppUrl: active.webAppUrl,
      apiKey: active.apiKey,
      cache: SheetsLocalCache(prefs, profileId: active.id),
    ),
    auditLog: ref.watch(auditLogStoreProvider),
    sheetName: active.name,
  );
});

/// How often a no-cache cold start re-attempts a failed fetch before giving
/// up, and the pause between attempts. Cold boots hit transient failures
/// (network stack warming up, Apps Script rejecting concurrent bursts), so
/// erroring on the first miss is premature when there is nothing else to show.
const _coldStartAttempts = 2;
const _coldStartRetryDelay = Duration(seconds: 2);

/// Shared cache-first fetch loop for [transactionsProvider] /
/// [dashboardProvider]:
/// - yields [cached] immediately when present, then the live fetch;
/// - a failed refresh keeps the cached value on screen (error only logged);
/// - with no cache, transient failures are retried before the error surfaces.
Stream<T> _cachedThenLive<T>({
  required T? cached,
  required Future<Result<T>> Function() fetch,
  required String label,
}) async* {
  if (cached != null) yield cached;

  for (var attempt = 1; attempt <= _coldStartAttempts; attempt++) {
    final result = await fetch();
    switch (result) {
      case Success(:final value):
        yield value;
        return;
      case Failure(:final error):
        if (cached != null) {
          debugPrint('$label: refresh failed, keeping cached data ($error)');
          return;
        }
        if (attempt == _coldStartAttempts) throw error;
        debugPrint('$label: attempt $attempt failed ($error), retrying');
    }
    await Future<void>.delayed(_coldStartRetryDelay);
  }
}

/// All transaction rows from the sheet (newest first).
///
/// Emits the last persisted rows immediately (when present) so a cold start
/// renders instantly, then the live fetch. A failed refresh keeps the cached
/// rows on screen; the error only surfaces when there is nothing to show.
/// Refresh with `ref.invalidate(transactionsProvider)`.
final transactionsProvider =
    StreamProvider<List<SheetTransaction>>((ref) {
  final repo = ref.watch(sheetsRepositoryProvider);
  return _cachedThenLive(
    cached: repo.cachedTransactions(),
    fetch: repo.fetchTransactions,
    label: 'transactionsProvider',
  );
});

/// Pre-computed portfolio snapshot from the `DashboardDB1` tab.
///
/// Same cache-first behavior as [transactionsProvider].
/// Refresh with `ref.invalidate(dashboardProvider)`.
final dashboardProvider = StreamProvider<DashboardSummary>((ref) {
  final repo = ref.watch(sheetsRepositoryProvider);
  return _cachedThenLive(
    cached: repo.cachedDashboard(),
    fetch: repo.fetchDashboard,
    label: 'dashboardProvider',
  );
});

/// When the transaction rows currently on screen were fetched from the sheet
/// (== the cache write time of the last successful fetch). Null until the
/// first successful fetch ever. Re-reads whenever [transactionsProvider]
/// emits, so it advances the moment live data lands.
final transactionsUpdatedAtProvider = Provider<DateTime?>((ref) {
  ref.watch(transactionsProvider);
  return ref.watch(sheetsRepositoryProvider).cachedTransactionsAt();
});

/// When the dashboard snapshot currently on screen was fetched from the sheet.
final dashboardUpdatedAtProvider = Provider<DateTime?>((ref) {
  ref.watch(dashboardProvider);
  return ref.watch(sheetsRepositoryProvider).cachedDashboardAt();
});

/// Current-month aggregates (spending, net invested, spend by category) for
/// the summary header, derived from the loaded rows. Yields zero totals while
/// loading / on error.
final currentMonthSummaryProvider = Provider<TransactionSummary>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return txs.inMonth(now.year, now.month).summarize();
});

/// Transactions grouped by calendar month (newest month first, newest row
/// first within a month), for the grouped list view. Empty while loading.
final transactionsByMonthProvider = Provider<List<MonthGroup>>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  return txs.groupByMonth();
});

/// One choice in the add-row account picker.
typedef AccountOption = ({String name, DateTime lastUsed});

/// Distinct account names seen in the sheet with the date each was last used,
/// ordered most-recently-used first so the picker surfaces likely choices at
/// the top. Empty while loading or on error — the form still allows free-text
/// entry via "New account".
final accountOptionsProvider = Provider<List<AccountOption>>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  // Rows arrive newest-first, so the first occurrence of a name is both its
  // most recent use and its MRU rank.
  final lastUsed = <String, DateTime>{};
  for (final t in txs) {
    final name = t.account.trim();
    if (name.isEmpty) continue;
    lastUsed.putIfAbsent(name, () => t.date);
  }
  return [
    for (final e in lastUsed.entries) (name: e.key, lastUsed: e.value),
  ];
});
