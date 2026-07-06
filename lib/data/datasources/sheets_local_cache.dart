import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last successful raw JSON responses from the sheet endpoint so
/// the next launch can render immediately instead of an empty loading screen
/// (stale-while-revalidate).
///
/// Stores the untouched response bodies — parsing stays in one place
/// (`SheetsRepositoryImpl`), and a schema change invalidates gracefully
/// because a body that no longer parses is simply treated as no cache.
///
/// Keys are namespaced by [profileId] ('test' / 'real') so each sheet keeps
/// its own cache — switching the active sheet instantly shows that sheet's
/// last data with no cross-contamination.
class SheetsLocalCache {
  const SheetsLocalCache(this._prefs, {required this.profileId});

  final SharedPreferences _prefs;

  /// The sheet profile these cached bodies belong to.
  final String profileId;

  String get _transactionsKey => 'cache.transactions.body.$profileId.v1';
  String get _transactionsAtKey => 'cache.transactions.at.$profileId.v1';
  String get _dashboardKey => 'cache.dashboard.body.$profileId.v1';
  String get _dashboardAtKey => 'cache.dashboard.at.$profileId.v1';

  String? readTransactions() => _prefs.getString(_transactionsKey);

  void writeTransactions(String body) {
    _prefs.setString(_transactionsKey, body);
    _prefs.setInt(_transactionsAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// When [writeTransactions] last ran — i.e. when the cached rows were
  /// fetched from the sheet. Null when nothing is cached.
  DateTime? transactionsTimestamp() => _readAt(_transactionsAtKey);

  String? readDashboard() => _prefs.getString(_dashboardKey);

  void writeDashboard(String body) {
    _prefs.setString(_dashboardKey, body);
    _prefs.setInt(_dashboardAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// When [writeDashboard] last ran. Null when nothing is cached.
  DateTime? dashboardTimestamp() => _readAt(_dashboardAtKey);

  /// Drops every cached body + timestamp for this profile. Call when the
  /// slot is re-pointed at a different sheet URL, so the previous sheet's
  /// rows/dashboard don't flash on the next load before the live refetch.
  void evict() {
    _prefs.remove(_transactionsKey);
    _prefs.remove(_transactionsAtKey);
    _prefs.remove(_dashboardKey);
    _prefs.remove(_dashboardAtKey);
  }

  DateTime? _readAt(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
