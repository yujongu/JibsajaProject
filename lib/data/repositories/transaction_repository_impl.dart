import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements ITransactionRepository {
  TransactionRepositoryImpl(this._firestore);
  final fs.FirebaseFirestore _firestore;

  fs.CollectionReference<TransactionModel> _col(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .withConverter<TransactionModel>(
        fromFirestore: (snap, _) => TransactionModel.fromMap(snap.data()!),
        toFirestore: (model, _) => model.toMap(),
      );

  @override
  Stream<List<Transaction>> watchTransactions(String uid) {
    return _col(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data().toEntity()).toList());
  }

  @override
  Stream<List<Transaction>> watchRecentTransactions(String uid, {int limit = 5}) {
    return _col(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data().toEntity()).toList());
  }

  @override
  Future<void> addTransaction(String uid, Transaction tx) =>
      _col(uid).doc(tx.id).set(TransactionModel.fromEntity(tx));

  @override
  Future<void> updateTransaction(String uid, Transaction tx) => _col(uid)
      .doc(tx.id)
      .set(TransactionModel.fromEntity(tx), fs.SetOptions(merge: true));

  @override
  Future<void> deleteTransaction(String uid, String id) =>
      _col(uid).doc(id).delete();

  @override
  Future<void> batchAddTransactions(String uid, List<Transaction> txs) async {
    final batch = _firestore.batch();
    final col = _col(uid);
    for (final tx in txs) {
      batch.set(col.doc(tx.id), TransactionModel.fromEntity(tx));
    }
    await batch.commit();
  }
}
