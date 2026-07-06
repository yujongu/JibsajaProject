import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../domain/entities/sheet_profile.dart';

/// Persists the two fixed sheet endpoint slots ("Test" / "Real") plus which
/// one is active, so the app can switch sheets at runtime instead of being
/// pinned to the compile-time `AppConfig` constants.
///
/// Seeding: the first ever read of the Test slot copies
/// `AppConfig.sheetsWebAppUrl` / `sheetsApiKey` into storage, so an existing
/// install keeps talking to the same sheet it always has. The Real slot
/// starts empty until the user configures it in Settings.
class SheetProfileStore {
  const SheetProfileStore(this._prefs);

  final SharedPreferences _prefs;

  static const _activeKey = 'profiles.active.v1';

  static String _urlKey(String id) => 'profiles.$id.url.v1';
  static String _apiKeyKey(String id) => 'profiles.$id.key.v1';

  /// Fixed display names — slots are not renameable.
  static String _nameOf(String id) =>
      id == SheetProfile.realId ? 'Real' : 'Test';

  /// Reads a slot. The Test slot is seeded from [AppConfig] on the first
  /// ever read (no stored url yet); the Real slot defaults to empty.
  SheetProfile read(String id) {
    var url = _prefs.getString(_urlKey(id));
    var key = _prefs.getString(_apiKeyKey(id));

    // Seed the Test slot from the compile-time endpoint. Re-seed when the
    // stored URL is empty (never stored, or a first run that seeded from an
    // *empty* AppConfig) as long as AppConfig now has a URL — so filling in
    // the config later still takes effect instead of being shadowed by a
    // stored empty string.
    if (id == SheetProfile.testId &&
        (url == null || url.isEmpty) &&
        AppConfig.sheetsWebAppUrl.isNotEmpty) {
      url = AppConfig.sheetsWebAppUrl;
      key = AppConfig.sheetsApiKey;
      _prefs.setString(_urlKey(id), url);
      _prefs.setString(_apiKeyKey(id), key);
    }

    return SheetProfile(
      id: id,
      name: _nameOf(id),
      webAppUrl: url ?? '',
      apiKey: key ?? '',
    );
  }

  /// The id of the currently active slot; defaults to 'test'. An unknown
  /// stored value (from a future schema change) also falls back to 'test'.
  String activeId() {
    final id = _prefs.getString(_activeKey);
    return id == SheetProfile.realId ? SheetProfile.realId : SheetProfile.testId;
  }

  void writeProfile(SheetProfile profile) {
    _prefs.setString(_urlKey(profile.id), profile.webAppUrl);
    _prefs.setString(_apiKeyKey(profile.id), profile.apiKey);
  }

  void setActive(String id) {
    _prefs.setString(_activeKey, id);
  }
}
