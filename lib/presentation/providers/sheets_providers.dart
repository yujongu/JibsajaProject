import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sheets_repository_impl.dart';
import '../../domain/entities/sheet_transaction.dart';
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
