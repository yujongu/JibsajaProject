import 'package:uuid/uuid.dart';

import '../entities/transaction.dart';
import '../entities/transaction_category.dart';
import '../entities/transaction_type.dart';
import '../repositories/i_transaction_repository.dart';

/// Creates or updates a single income/expense transaction.
class AddIncomeOrExpense {
  const AddIncomeOrExpense(this._repo);
  final ITransactionRepository _repo;

  Future<void> call({
    required String uid,
    required TransactionType type,
    required String title,
    required double amount,
    required TransactionCategory category,
    required DateTime date,
    String? accountId,
    String? note,
    String currency = 'KRW',
    Transaction? existing,
  }) async {
    assert(type == TransactionType.income || type == TransactionType.expense,
        'AddIncomeOrExpense only handles income/expense');

    final now = DateTime.now();
    if (existing == null) {
      await _repo.addTransaction(
        uid,
        Transaction(
          id: const Uuid().v4(),
          userId: uid,
          accountId: accountId,
          title: title,
          amount: amount,
          type: type,
          category: category,
          date: date,
          note: note,
          currency: currency,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await _repo.updateTransaction(
        uid,
        existing.copyWith(
          accountId: accountId,
          title: title,
          amount: amount,
          type: type,
          category: category,
          date: date,
          note: note,
          currency: currency,
        ),
      );
    }
  }
}
