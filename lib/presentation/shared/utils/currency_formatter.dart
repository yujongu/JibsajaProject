import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static String format(double v, String currency) {
    switch (currency) {
      case 'USD': return '\$${NumberFormat('#,##0.00', 'en_US').format(v)}';
      case 'EUR': return '€${NumberFormat('#,##0.00', 'en_US').format(v)}';
      case 'JPY': return '¥${NumberFormat('#,###', 'en_US').format(v.toInt())}';
      default:    return '₩${NumberFormat('#,###', 'en_US').format(v.toInt())}';
    }
  }

  static String symbol(String currency) {
    switch (currency) {
      case 'KRW': return '₩';
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'JPY': return '¥';
      default:    return currency;
    }
  }
}
