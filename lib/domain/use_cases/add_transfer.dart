import 'package:uuid/uuid.dart';

import '../entities/account.dart';
import '../entities/transaction.dart';
import '../entities/transaction_category.dart';
import '../entities/transaction_type.dart';
import '../repositories/i_sheets_sync_repository.dart';
import '../repositories/i_transaction_repository.dart';

/// Creates a pair of Transfer transactions (debit leg + credit leg) and
/// mirrors them to the external sheet. Sheet sync is fire-and-forget.
class AddTransfer {
  const AddTransfer(this._repo, this._sheets);
  final ITransactionRepository _repo;
  final ISheetsSyncRepository _sheets;

  Future<void> call({
    required String uid,
    required Account fromAccount,
    required Account toAccount,
    required double amount,
    required DateTime date,
  }) async {
    if (fromAccount.id == toAccount.id) {
      throw ArgumentError('From and To accounts must be different');
    }

    final now = DateTime.now();
    final debitId = const Uuid().v4();
    final creditId = const Uuid().v4();

    await _repo.batchAddTransactions(uid, [
      Transaction(
        id: debitId,
        userId: uid,
        accountId: fromAccount.id,
        title: 'Transfer to ${toAccount.name}',
        amount: amount,
        type: TransactionType.transfer,
        isDebit: true,
        category: TransactionCategory.other,
        date: date,
        currency: fromAccount.currency,
        createdAt: now,
        updatedAt: now,
      ),
      Transaction(
        id: creditId,
        userId: uid,
        accountId: toAccount.id,
        title: 'Transfer from ${fromAccount.name}',
        amount: amount,
        type: TransactionType.transfer,
        isDebit: false,
        category: TransactionCategory.other,
        date: date,
        currency: toAccount.currency,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    _sheets
        .appendTransferRows(
          date: date,
          fromAccountName: fromAccount.name,
          toAccountName: toAccount.name,
          amount: amount,
          debitTxId: debitId,
          creditTxId: creditId,
        )
        .ignore();
  }
}
