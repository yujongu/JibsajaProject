/// One configured Google Sheet endpoint the app can talk to.
///
/// The app keeps exactly two fixed slots — "Test" and "Real" — each backed by
/// its own Apps Script `/exec` URL and API key (a copied spreadsheet has its
/// own deployment). Pure Dart — no Flutter/HTTP imports.
class SheetProfile {
  const SheetProfile({
    required this.id,
    required this.name,
    required this.webAppUrl,
    required this.apiKey,
  });

  /// Slot id of the Test profile.
  static const String testId = 'test';

  /// Slot id of the Real profile.
  static const String realId = 'real';

  /// Stable slot identifier: [testId] or [realId].
  final String id;

  /// Fixed display name ('Test' or 'Real').
  final String name;

  /// The Apps Script web app `/exec` URL backing the sheet. Empty when the
  /// slot has not been configured yet.
  final String webAppUrl;

  /// Shared secret sent with each request; may be empty.
  final String apiKey;

  /// A slot is usable only once it has an endpoint URL.
  bool get isConfigured => webAppUrl.isNotEmpty;

  SheetProfile copyWith({
    String? id,
    String? name,
    String? webAppUrl,
    String? apiKey,
  }) {
    return SheetProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      webAppUrl: webAppUrl ?? this.webAppUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetProfile &&
          other.id == id &&
          other.name == name &&
          other.webAppUrl == webAppUrl &&
          other.apiKey == apiKey;

  @override
  int get hashCode => Object.hash(id, name, webAppUrl, apiKey);

  @override
  String toString() =>
      'SheetProfile($id, $name, url: ${webAppUrl.isEmpty ? '<empty>' : 'set'})';
}
