import '../../domain/entities/sync_settings.dart';

class SyncSettingsModel {
  const SyncSettingsModel({required this.enabled, this.lastSyncedAt});

  final bool enabled;
  final DateTime? lastSyncedAt;

  factory SyncSettingsModel.fromEntity(SyncSettings e) =>
      SyncSettingsModel(enabled: e.enabled, lastSyncedAt: e.lastSyncedAt);

  SyncSettings toEntity() =>
      SyncSettings(enabled: enabled, lastSyncedAt: lastSyncedAt);

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
      };

  factory SyncSettingsModel.fromMap(Map<String, dynamic> map) =>
      SyncSettingsModel(
        enabled: map['enabled'] as bool? ?? false,
        lastSyncedAt: map['lastSyncedAt'] != null
            ? DateTime.parse(map['lastSyncedAt'] as String).toLocal()
            : null,
      );
}
