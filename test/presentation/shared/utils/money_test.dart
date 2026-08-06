import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/presentation/shared/utils/money.dart';

void main() {
  group('money', () {
    test('KRW gets a won sign and no decimals', () {
      expect(money(512300, 'KRW'), '₩512,300');
      // The won has no minor unit, so a fractional value is rounded away.
      expect(money(12500.4, 'KRW'), '₩12,500');
    });

    test('USD gets a dollar sign and up to two decimals', () {
      expect(money(1842.5, 'USD'), r'$1,842.5');
      expect(money(1234.56, 'USD'), r'$1,234.56');
      expect(money(1000, 'USD'), r'$1,000');
    });

    test('an unknown currency renders bare, not guessed at', () {
      // A missing account (or a blank Currency cell) must look exactly as it
      // did before the Accounts tab was read at all.
      expect(money(12.5, null), '12.5');
      expect(money(12.5, ''), '12.5');
    });

    test('an unfamiliar code is prefixed literally', () {
      expect(money(12.5, 'EUR'), 'EUR 12.5');
    });

    test('a negative keeps its sign, after the symbol', () {
      // Shipped behavior, unchanged by the move out of sheet_view_page: the
      // symbol is a prefix, so the minus lands between it and the digits. Every
      // negative-amount row on the Transactions list already reads this way.
      expect(money(-512300, 'KRW'), '₩-512,300');
    });
  });

  group('plainNumber', () {
    test('groups thousands and keeps up to two decimals', () {
      expect(plainNumber(1234.5), '1,234.5');
      expect(plainNumber(1234.567), '1,234.57');
      expect(plainNumber(1000), '1,000');
    });
  });
}
