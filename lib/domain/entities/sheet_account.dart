/// One row of the sheet's `Accounts` tab — the app reads it only to learn
/// which currency an account's amounts are denominated in.
///
/// Pure Dart — no Flutter/HTTP imports. Read-only: the app never writes to the
/// `Accounts` tab.
class SheetAccount {
  const SheetAccount({required this.name, required this.currency});

  /// The account name as written in the sheet, matched against a transaction
  /// row's Account column.
  final String name;

  /// ISO code from the sheet's Currency cell ('KRW', 'USD'), or empty when the
  /// cell is blank — an unknown currency renders as a bare, unlabelled amount.
  final String currency;
}
