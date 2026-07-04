import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last successful raw JSON responses from the sheet endpoint so
/// the next launch can render immediately instead of an empty loading screen
/// (stale-while-revalidate).
///
/// Stores the untouched response bodies — parsing stays in one place
/// (`SheetsRepositoryImpl`), and a schema change invalidates gracefully
/// because a body that no longer parses is simply treated as no cache.
class SheetsLocalCache {
  const SheetsLocalCache(this._prefs);

  final SharedPreferences _prefs;

  static const _transactionsKey = 'cache.transactions.body.v1';
  static const _transactionsAtKey = 'cache.transactions.at.v1';
  static const _dashboardKey = 'cache.dashboard.body.v1';
  static const _dashboardAtKey = 'cache.dashboard.at.v1';

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

  DateTime? _readAt(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
