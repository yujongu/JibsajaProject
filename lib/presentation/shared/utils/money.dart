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
      // Always two decimals, unlike [plainNumber] — a dollar amount that drops
      // its trailing zeros reads as truncated ('$118.4' for a $118.40 price).
      return '\$${NumberFormat('#,##0.00', 'en_US').format(v)}';
    case null || '':
      return plainNumber(v);
    default:
      // An unfamiliar code is still labelled honestly rather than guessed at.
      return '$currency ${plainNumber(v)}';
  }
}

/// [money] with an explicit sign: '+$1,434.00', '−₩882,000'.
///
/// The sign is carried outside the formatter, and uses U+2212 MINUS SIGN rather
/// than a hyphen, so the currency symbol stays next to the digits ('+₩100', not
/// '₩+100'). Zero counts as positive, matching how the app reads a flat return.
String signedMoney(double v, String? currency) =>
    '${v < 0 ? '−' : '+'}${money(v.abs(), currency)}';

/// A fraction as a signed percentage with one decimal: 0.6057 → '+60.6%'.
/// Same U+2212 convention as [signedMoney].
String signedPercent(double fraction) {
  final pct = NumberFormat('#,##0.0', 'en_US').format(fraction.abs() * 100);
  return '${fraction < 0 ? '−' : '+'}$pct%';
}
