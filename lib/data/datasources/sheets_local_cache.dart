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
  String get _accountsKey => 'cache.accounts.body.$profileId.v1';
  String get _accountsAtKey => 'cache.accounts.at.$profileId.v1';
  String get _holdingsKey => 'cache.holdings.body.$profileId.v1';
  String get _holdingsAtKey => 'cache.holdings.at.$profileId.v1';

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

  String? readAccounts() => _prefs.getString(_accountsKey);

  void writeAccounts(String body) {
    _prefs.setString(_accountsKey, body);
    _prefs.setInt(_accountsAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// When [writeAccounts] last ran. Null when nothing is cached — including for
  /// a body cached before this timestamp existed, which reads as "unknown"
  /// until the next successful fetch rather than as a wrong time.
  DateTime? accountsTimestamp() => _readAt(_accountsAtKey);

  String? readHoldings() => _prefs.getString(_holdingsKey);

  void writeHoldings(String body) {
    _prefs.setString(_holdingsKey, body);
    _prefs.setInt(_holdingsAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// When [writeHoldings] last ran. Null when nothing is cached.
  DateTime? holdingsTimestamp() => _readAt(_holdingsAtKey);

  /// Drops every cached body + timestamp for this profile. Call when the
  /// slot is re-pointed at a different sheet URL, so the previous sheet's
  /// rows/dashboard don't flash on the next load before the live refetch.
  void evict() {
    _prefs.remove(_transactionsKey);
    _prefs.remove(_transactionsAtKey);
    _prefs.remove(_dashboardKey);
    _prefs.remove(_dashboardAtKey);
    _prefs.remove(_accountsKey);
    _prefs.remove(_accountsAtKey);
    _prefs.remove(_holdingsKey);
    _prefs.remove(_holdingsAtKey);
  }

  DateTime? _readAt(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
