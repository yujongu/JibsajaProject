import '../entities/transaction.dart';

abstract class ITransactionRepository {
  Stream<List<Transaction>> watchTransactions(String uid);
  Stream<List<Transaction>> watchRecentTransactions(String uid, {int limit});
  Future<void> addTransaction(String uid, Transaction tx);
  Future<void> updateTransaction(String uid, Transaction tx);
  Future<void> deleteTransaction(String uid, String id);
  Future<void> batchAddTransactions(String uid, List<Transaction> txs);
}
