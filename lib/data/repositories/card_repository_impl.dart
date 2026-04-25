import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bank_card.dart';
import '../../domain/repositories/i_card_repository.dart';
import '../models/bank_card_model.dart';

class CardRepositoryImpl implements ICardRepository {
  CardRepositoryImpl(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<BankCardModel> _col(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('cards')
      .withConverter<BankCardModel>(
        fromFirestore: (snap, _) => BankCardModel.fromMap(snap.data()!),
        toFirestore: (model, _) => model.toMap(),
      );

  @override
  Stream<List<BankCard>> watchCards(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data().toEntity()).toList());
  }

  @override
  Future<void> addCard(String uid, BankCard card) =>
      _col(uid).doc(card.id).set(BankCardModel.fromEntity(card));

  @override
  Future<void> updateCard(String uid, BankCard card) => _col(uid)
      .doc(card.id)
      .set(BankCardModel.fromEntity(card), SetOptions(merge: true));

  @override
  Future<void> deleteCard(String uid, String id) =>
      _col(uid).doc(id).delete();
}
