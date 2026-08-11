import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/presentation/shared/utils/money.dart';

void main() {
  group('money', () {
    test('KRW gets a won sign and no decimals', () {
      expect(money(512300, 'KRW'), '₩512,300');
      // The won has no minor unit, so a fractional value is rounded away.
      expect(money(12500.4, 'KRW'), '₩12,500');
    });

    test('USD gets a dollar sign and always two decimals', () {
      // Unlike plainNumber, trailing zeros are kept: a price that renders as
      // '$118.4' reads as truncated rather than as money.
      expect(money(1842.5, 'USD'), r'$1,842.50');
      expect(money(1234.56, 'USD'), r'$1,234.56');
      expect(money(1000, 'USD'), r'$1,000.00');
      expect(money(118.4, 'USD'), r'$118.40');
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

    test('is unaffected by the USD rule — it labels no currency', () {
      // Quantities go through here: '20 sh', never '20.00 sh'.
      expect(plainNumber(20), '20');
    });
  });

  group('signedMoney', () {
    test('puts the sign before the symbol, unlike money', () {
      expect(signedMoney(1434, 'USD'), r'+$1,434.00');
      expect(signedMoney(-882, 'USD'), r'−$882.00');
      expect(signedMoney(708000, 'KRW'), '+₩708,000');
      expect(signedMoney(-1206000, 'KRW'), '−₩1,206,000');
    });

    test('uses a real minus sign, not a hyphen', () {
      expect(signedMoney(-882, 'USD').startsWith('−'), isTrue);
      expect(signedMoney(-882, 'USD').contains('-'), isFalse);
    });

    test('zero reads as positive', () {
      expect(signedMoney(0, 'USD'), r'+$0.00');
    });

    test('an unlabelled amount still gets its sign', () {
      expect(signedMoney(-12.5, null), '−12.5');
    });
  });

  group('signedPercent', () {
    test('renders a fraction as a signed percentage to one decimal', () {
      expect(signedPercent(0.60557), '+60.6%');
      expect(signedPercent(-0.18386), '−18.4%');
      expect(signedPercent(0), '+0.0%');
    });

    test('groups thousands for an outsized return', () {
      expect(signedPercent(12.5), '+1,250.0%');
    });
  });
}
