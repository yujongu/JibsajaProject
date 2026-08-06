/// One row of the sheet's `Accounts` tab — the currency an account's amounts
/// are denominated in, plus the balance the Accounts page lists.
///
/// Pure Dart — no Flutter/HTTP imports. Read-only: the app never writes to the
/// `Accounts` tab.
class SheetAccount {
  const SheetAccount({
    required this.name,
    required this.currency,
    this.type = '',
    this.currentBalance,
  });

  /// The account name as written in the sheet, matched against a transaction
  /// row's Account column.
  final String name;

  /// ISO code from the sheet's Currency cell ('KRW', 'USD'), or empty when the
  /// cell is blank — an unknown currency renders as a bare, unlabelled amount.
  final String currency;

  /// The sheet's Type cell as written ('Credit', 'Bank', 'Brokerage',
  /// 'Crypto'), or empty when the column is absent. Match it with [ofType]
  /// rather than comparing directly — the sheet's casing is not guaranteed.
  final String type;

  /// The sheet's Current Balance cell — card debt for a Credit account, cash on
  /// hand for a Bank one. **Signed exactly as the sheet stores it**; the app
  /// applies no sign convention of its own.
  ///
  /// Null when the cell is blank or unparseable — distinct from 0, which is a
  /// real balance (a paid-off card).
  final double? currentBalance;

  /// Lookup key for joining a transaction's Account column against this tab.
  /// Defined once so every join normalizes identically; absorbs whitespace and
  /// case drift between the two tabs, nothing more.
  static String key(String accountName) => accountName.trim().toLowerCase();
}

extension SheetAccountList on List<SheetAccount> {
  /// The accounts whose Type cell is [type], compared case- and
  /// whitespace-insensitively so `'bank '` in the sheet still matches `'Bank'`.
  List<SheetAccount> ofType(String type) {
    final wanted = type.trim().toLowerCase();
    return [for (final a in this) if (a.type.trim().toLowerCase() == wanted) a];
  }
}
