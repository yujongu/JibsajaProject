import '../entities/sync_settings.dart';

abstract class ISyncSettingsRepository {
  Stream<SyncSettings> watchSettings(String uid);
  Future<void> saveSettings(String uid, SyncSettings settings);
}
