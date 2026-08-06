import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/sheets_local_cache.dart';
import '../../data/repositories/logging_sheets_repository.dart';
import '../../data/repositories/sheets_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_account.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_category.dart';
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

/// Labels of sheet fetches currently hitting the network. Lets the UI show a
/// "syncing" bar even while stale cached data stays on screen: the cache-first
/// stream below emits the cached value before the live fetch returns, so
/// `AsyncValue.isLoading` is already false during that window.
class FetchStatusNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void start(String label) => state = {...state, label};
  void stop(String label) => state = {...state}..remove(label);
}

final fetchStatusProvider =
    NotifierProvider<FetchStatusNotifier, Set<String>>(FetchStatusNotifier.new);

/// Whether a live fetch for [label] is currently in flight.
final isFetchingProvider = Provider.family<bool, String>(
  (ref, label) => ref.watch(fetchStatusProvider).contains(label),
);

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
  required Ref ref,
  required T? cached,
  required Future<Result<T>> Function() fetch,
  required String label,
}) async* {
  if (cached != null) yield cached;

  final status = ref.read(fetchStatusProvider.notifier);
  for (var attempt = 1; attempt <= _coldStartAttempts; attempt++) {
    status.start(label);
    final Result<T> result;
    try {
      result = await fetch();
    } finally {
      // Clears the label on success, failure, and stream cancellation
      // (invalidate/dispose) alike, so the syncing bar never sticks on.
      status.stop(label);
    }
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
    ref: ref,
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
    ref: ref,
    cached: repo.cachedDashboard(),
    fetch: repo.fetchDashboard,
    label: 'dashboardProvider',
  );
});

/// Rows of the sheet's `Accounts` tab — read only, purely to learn each
/// account's currency.
///
/// Same cache-first behavior as [transactionsProvider]. A failure here must not
/// break the Transactions page; [accountCurrenciesProvider] degrades to an
/// empty map, so amounts simply render without a currency symbol.
final accountsProvider = StreamProvider<List<SheetAccount>>((ref) {
  final repo = ref.watch(sheetsRepositoryProvider);
  return _cachedThenLive(
    ref: ref,
    cached: repo.cachedAccounts(),
    fetch: repo.fetchAccounts,
    label: 'accountsProvider',
  );
});

/// Account name (trimmed, lowercased) → currency code, for looking up the
/// currency of a transaction row's Account. Accounts with a blank Currency
/// cell are left out, so a miss and a blank cell behave identically: no symbol.
final accountCurrenciesProvider = Provider<Map<String, String>>((ref) {
  final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
  return {
    for (final a in accounts)
      if (a.currency.isNotEmpty) SheetAccount.key(a.name): a.currency,
  };
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

/// When the account balances currently on screen were fetched from the sheet.
final accountsUpdatedAtProvider = Provider<DateTime?>((ref) {
  ref.watch(accountsProvider);
  return ref.watch(sheetsRepositoryProvider).cachedAccountsAt();
});

/// The calendar month the Transactions page is showing, normalized to the 1st
/// with no time component. Starts on the current month every launch (not
/// persisted — reopening the app should land on "now").
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// Step [months] forward (positive) or back (negative). `DateTime` normalizes
  /// out-of-range months, so month 0 → December of the previous year and month
  /// 13 → January of the next; no manual year arithmetic needed.
  void shift(int months) => state = DateTime(state.year, state.month + months);

  /// Jump to the month containing [date].
  void select(DateTime date) => state = DateTime(date.year, date.month);
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(
        SelectedMonthNotifier.new);

/// Inclusive range of months the month bar may navigate to.
typedef MonthRange = ({DateTime oldest, DateTime newest});

/// Oldest → newest navigable month, so the arrows can stop at the edges of the
/// data instead of walking forever into empty months. Null when there are no
/// rows at all (nothing to navigate).
final monthBoundsProvider = Provider<MonthRange?>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  if (txs.isEmpty) return null;

  // Explicit scan rather than trusting the newest-first sort order.
  var oldest = DateTime(txs.first.date.year, txs.first.date.month);
  var newest = oldest;
  for (final tx in txs) {
    final month = DateTime(tx.date.year, tx.date.month);
    if (month.isBefore(oldest)) oldest = month;
    if (month.isAfter(newest)) newest = month;
  }

  // The current month stays reachable even before it has any rows; a
  // future-dated row (the add form allows up to tomorrow) extends past it.
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  if (newest.isBefore(currentMonth)) newest = currentMonth;
  if (oldest.isAfter(currentMonth)) oldest = currentMonth;

  return (oldest: oldest, newest: newest);
});

/// Whether each month-bar arrow is enabled. Both false when there is nothing
/// to navigate.
final monthNavProvider = Provider<({bool canGoBack, bool canGoForward})>((ref) {
  final bounds = ref.watch(monthBoundsProvider);
  if (bounds == null) return (canGoBack: false, canGoForward: false);
  final selected = ref.watch(selectedMonthProvider);
  return (
    canGoBack: selected.isAfter(bounds.oldest),
    canGoForward: selected.isBefore(bounds.newest),
  );
});

/// Selected-month aggregates (spending, net invested, spend by category) for
/// the summary card. Yields zero totals while loading / on error, and for a
/// month with no rows.
final selectedMonthSummaryProvider = Provider<TransactionSummary>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final month = ref.watch(selectedMonthProvider);
  // Watching the currencies means the card re-splits the moment the Accounts
  // tab lands, rather than staying stuck on the unlabelled fallback.
  final currencies = ref.watch(accountCurrenciesProvider);
  return txs.inMonth(month.year, month.month).summarize(currencies: currencies);
});

/// The selected month's rows, newest first — the source list is already sorted
/// and `inMonth` preserves its order. Empty while loading.
final selectedMonthTransactionsProvider =
    Provider<List<SheetTransaction>>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final month = ref.watch(selectedMonthProvider);
  return txs.inMonth(month.year, month.month);
});

/// Identifies one category bar on the summary card: a category within one
/// currency's section. Records compare structurally, so this works as a
/// provider-family key.
typedef CategoryQuery = ({TransactionCategory category, String? currency});

/// The selected month's rows behind one category bar, newest first.
final categoryTransactionsProvider =
    Provider.autoDispose.family<List<SheetTransaction>, CategoryQuery>(
        (ref, query) {
  final txs = ref.watch(selectedMonthTransactionsProvider);
  final currencies = ref.watch(accountCurrenciesProvider);
  return txs.inCategory(
    query.category,
    currency: query.currency,
    currencies: currencies,
  );
});

/// Spend on one category over the 12 months ending at the selected one, oldest
/// first. Reads **all** transactions, not just the selected month's — the
/// window is the point.
final categoryTrendProvider =
    Provider.autoDispose.family<List<MonthlySpend>, CategoryQuery>((ref, query) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final month = ref.watch(selectedMonthProvider);
  final currencies = ref.watch(accountCurrenciesProvider);
  return txs.monthlySpend(
    query.category,
    endMonth: month,
    currency: query.currency,
    currencies: currencies,
  );
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
