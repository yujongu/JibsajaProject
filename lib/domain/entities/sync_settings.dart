class SyncSettings {
  const SyncSettings({required this.enabled, this.lastSyncedAt});

  final bool enabled;
  final DateTime? lastSyncedAt;

  static const empty = SyncSettings(enabled: false);

  SyncSettings copyWith({bool? enabled, DateTime? lastSyncedAt}) {
    return SyncSettings(
      enabled: enabled ?? this.enabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
