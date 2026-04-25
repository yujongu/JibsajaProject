import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sheets_sync_repository_impl.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/i_sheets_sync_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../../domain/use_cases/add_income_or_expense.dart';
import '../../domain/use_cases/add_trade.dart';
import '../../domain/use_cases/add_transfer.dart';
import 'auth_providers.dart';

final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  return TransactionRepositoryImpl(FirebaseFirestore.instance);
});

final sheetsSyncRepositoryProvider = Provider<ISheetsSyncRepository>((ref) {
  return const SheetsSyncRepositoryImpl();
});

final addIncomeOrExpenseUseCaseProvider = Provider<AddIncomeOrExpense>((ref) {
  return AddIncomeOrExpense(ref.watch(transactionRepositoryProvider));
});

final addTradeUseCaseProvider = Provider<AddTrade>((ref) {
  return AddTrade(
    ref.watch(transactionRepositoryProvider),
    ref.watch(sheetsSyncRepositoryProvider),
  );
});

final addTransferUseCaseProvider = Provider<AddTransfer>((ref) {
  return AddTransfer(
    ref.watch(transactionRepositoryProvider),
    ref.watch(sheetsSyncRepositoryProvider),
  );
});

final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(transactionRepositoryProvider).watchTransactions(user.uid);
});

final recentTransactionsProvider = Provider<List<Transaction>>((ref) {
  final all = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
  return all.take(5).toList();
});

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyTransactionsProvider = Provider<List<Transaction>>((ref) {
  final allTx = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
  final month = ref.watch(selectedMonthProvider);
  return allTx.where((tx) {
    return tx.date.year == month.year && tx.date.month == month.month;
  }).toList();
});

final monthlyIncomeProvider = Provider<double>((ref) {
  final txs = ref.watch(monthlyTransactionsProvider);
  return txs
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (total, t) => total + t.amount);
});

final monthlyExpensesProvider = Provider<double>((ref) {
  final txs = ref.watch(monthlyTransactionsProvider);
  return txs
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (total, t) => total + t.amount);
});

final categoryExpensesProvider = Provider<Map<TransactionCategory, double>>((ref) {
  final txs = ref.watch(monthlyTransactionsProvider);
  final result = <TransactionCategory, double>{};
  for (final tx in txs.where((t) => t.type == TransactionType.expense)) {
    result[tx.category] = (result[tx.category] ?? 0) + tx.amount;
  }
  final sorted = Map.fromEntries(
    result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );
  return sorted;
});
