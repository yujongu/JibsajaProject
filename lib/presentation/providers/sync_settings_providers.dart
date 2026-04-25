import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sync_settings_repository_impl.dart';
import '../../domain/entities/sync_settings.dart';
import '../../domain/repositories/i_sync_settings_repository.dart';
import 'auth_providers.dart';

final syncSettingsRepositoryProvider = Provider<ISyncSettingsRepository>((ref) {
  return SyncSettingsRepositoryImpl(FirebaseFirestore.instance);
});

final syncSettingsStreamProvider = StreamProvider<SyncSettings>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(syncSettingsRepositoryProvider).watchSettings(user.uid);
});
