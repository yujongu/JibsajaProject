import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/sync_settings.dart';
import '../../domain/repositories/i_sync_settings_repository.dart';
import '../models/sync_settings_model.dart';

class SyncSettingsRepositoryImpl implements ISyncSettingsRepository {
  SyncSettingsRepositoryImpl(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference<SyncSettingsModel> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('sync')
      .withConverter<SyncSettingsModel>(
        fromFirestore: (snap, _) =>
            SyncSettingsModel.fromMap(snap.data() ?? const {}),
        toFirestore: (model, _) => model.toMap(),
      );

  @override
  Stream<SyncSettings> watchSettings(String uid) {
    return _doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return SyncSettings.empty;
      return data.toEntity();
    });
  }

  @override
  Future<void> saveSettings(String uid, SyncSettings settings) =>
      _doc(uid).set(SyncSettingsModel.fromEntity(settings), SetOptions(merge: true));
}
