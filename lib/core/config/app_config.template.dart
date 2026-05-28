// Copy this file to app_config.dart and fill in your values.
// app_config.dart is gitignored — never commit real secrets.
abstract final class AppConfig {
  // Google Apps Script web app URL for Sheets sync.
  // Leave empty ('') to disable sync silently.
  static const String sheetsWebAppUrl = '';

  static const String sheetsApiKey = '';
}
