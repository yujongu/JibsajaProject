import '../entities/account.dart';
import '../entities/transaction.dart';
import '../entities/transaction_type.dart';

/// Derives an account's current balance from its initial balance plus the
/// signed sum of its linked transactions. Pure — no I/O.
class ComputeAccountBalance {
  const ComputeAccountBalance();

  double call({
    required Account account,
    required Iterable<Transaction> transactions,
  }) {
    final linked = transactions.where((tx) => tx.accountId == account.id);

    double income = 0, expenses = 0, transferIn = 0, transferOut = 0;
    for (final tx in linked) {
      switch (tx.type) {
        case TransactionType.income:
          income += tx.amount;
          break;
        case TransactionType.expense:
          expenses += tx.amount;
          break;
        case TransactionType.transfer:
          if (tx.isDebit ?? false) {
            transferOut += tx.amount;
          } else {
            transferIn += tx.amount;
          }
          break;
        case TransactionType.buy:
        case TransactionType.sell:
          break;
      }
    }

    return account.initialBalance + income - expenses + transferIn - transferOut;
  }
}
