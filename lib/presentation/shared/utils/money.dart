import 'package:intl/intl.dart';

/// Formats a bare number with grouping and up to 2 decimals. No currency
/// symbol — used for unit-less fragments such as quantity × price.
String plainNumber(double v) => NumberFormat('#,##0.##', 'en_US').format(v);

/// Formats an amount prefixed with its account's currency from the sheet's
/// `Accounts` tab. A [currency] of null or empty means the sheet does not say —
/// the amount then renders unlabelled, so an unmarked figure is a visible hint
/// that the account is missing from that tab.
String money(double v, String? currency) {
  switch (currency) {
    case 'KRW':
      // The won has no minor unit, so decimals would be noise.
      return '₩${NumberFormat('#,##0', 'en_US').format(v)}';
    case 'USD':
      return '\$${plainNumber(v)}';
    case null || '':
      return plainNumber(v);
    default:
      // An unfamiliar code is still labelled honestly rather than guessed at.
      return '$currency ${plainNumber(v)}';
  }
}
