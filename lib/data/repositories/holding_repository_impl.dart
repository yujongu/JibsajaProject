import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/holding.dart';
import '../../domain/repositories/i_holding_repository.dart';
import '../models/holding_model.dart';

class HoldingRepositoryImpl implements IHoldingRepository {
  HoldingRepositoryImpl(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<HoldingModel> _col(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('holdings')
      .withConverter<HoldingModel>(
        fromFirestore: (snap, _) => HoldingModel.fromMap(snap.data()!),
        toFirestore: (model, _) => model.toMap(),
      );

  @override
  Stream<List<Holding>> watchHoldings(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data().toEntity()).toList());
  }

  @override
  Future<void> addHolding(String uid, Holding holding) =>
      _col(uid).doc(holding.id).set(HoldingModel.fromEntity(holding));

  @override
  Future<void> updateHolding(String uid, Holding holding) => _col(uid)
      .doc(holding.id)
      .set(HoldingModel.fromEntity(holding), SetOptions(merge: true));

  @override
  Future<void> deleteHolding(String uid, String id) =>
      _col(uid).doc(id).delete();
}
