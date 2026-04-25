import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/i_account_repository.dart';
import '../models/account_model.dart';

class AccountRepositoryImpl implements IAccountRepository {
  AccountRepositoryImpl(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<AccountModel> _col(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('accounts')
      .withConverter<AccountModel>(
        fromFirestore: (snap, _) => AccountModel.fromMap(snap.data()!),
        toFirestore: (model, _) => model.toMap(),
      );

  @override
  Stream<List<Account>> watchAccounts(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data().toEntity()).toList());
  }

  @override
  Future<void> addAccount(String uid, Account account) =>
      _col(uid).doc(account.id).set(AccountModel.fromEntity(account));

  @override
  Future<void> updateAccount(String uid, Account account) => _col(uid)
      .doc(account.id)
      .set(AccountModel.fromEntity(account), SetOptions(merge: true));

  @override
  Future<void> deleteAccount(String uid, String id) =>
      _col(uid).doc(id).delete();
}
