import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';
import 'package:jibsaja/domain/entities/bank_card.dart';
import 'package:jibsaja/domain/entities/card_network.dart';
import 'package:jibsaja/domain/entities/card_type.dart';
import 'package:jibsaja/domain/entities/holding.dart';
import 'package:jibsaja/domain/entities/holding_type.dart';
import 'package:jibsaja/domain/use_cases/calculate_net_worth.dart';

Account makeAccount({
  String id = 'acc-1',
  double balance = 0,
  AccountType type = AccountType.checking,
  String currency = 'KRW',
}) {
  final now = DateTime.now();
  return Account(
    id: id,
    userId: 'user-1',
    name: 'Test',
    type: type,
    balance: balance,
    currency: currency,
    createdAt: now,
    updatedAt: now,
  );
}

Holding makeHolding({
  String id = 'h-1',
  double quantity = 1,
  double currentPrice = 1000,
  String currency = 'KRW',
}) {
  final now = DateTime.now();
  return Holding(
    id: id,
    userId: 'user-1',
    name: 'Asset',
    ticker: 'TST',
    type: HoldingType.stock,
    quantity: quantity,
    avgCostPrice: currentPrice,
    currentPrice: currentPrice,
    currency: currency,
    createdAt: now,
    updatedAt: now,
  );
}

BankCard makeCard({
  String id = 'card-1',
  double balance = 0,
  String currency = 'KRW',
}) {
  final now = DateTime.now();
  return BankCard(
    id: id,
    userId: 'user-1',
    name: 'Card',
    last4Digits: '1234',
    type: CardType.credit,
    network: CardNetwork.visa,
    balance: balance,
    currency: currency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const calculate = CalculateNetWorth();

  group('CalculateNetWorth', () {
    test('returns 0 when all inputs are empty', () {
      expect(
        calculate(
          accounts: [],
          holdings: [],
          cards: [],
          usdToKrwRate: 1300,
        ),
        0,
      );
    });

    test('sums non-investment account balances', () {
      final result = calculate(
        accounts: [
          makeAccount(id: 'a1', balance: 100000, type: AccountType.checking),
          makeAccount(id: 'a2', balance: 50000, type: AccountType.savings),
        ],
        holdings: [],
        cards: [],
        usdToKrwRate: 1300,
      );
      expect(result, 150000);
    });

    test('investment accounts are excluded from account total', () {
      final result = calculate(
        accounts: [
          makeAccount(id: 'a1', balance: 999999, type: AccountType.investment),
        ],
        holdings: [],
        cards: [],
        usdToKrwRate: 1300,
      );
      expect(result, 0);
    });

    test('holdings are added to total', () {
      final result = calculate(
        accounts: [],
        holdings: [
          makeHolding(quantity: 10, currentPrice: 5000),
        ],
        cards: [],
        usdToKrwRate: 1300,
      );
      expect(result, 50000);
    });

    test('card balances are subtracted', () {
      final result = calculate(
        accounts: [makeAccount(balance: 200000)],
        holdings: [],
        cards: [makeCard(balance: 30000)],
        usdToKrwRate: 1300,
      );
      expect(result, 170000);
    });

    test('USD accounts are converted to KRW', () {
      final result = calculate(
        accounts: [
          makeAccount(balance: 100, currency: 'USD'),
        ],
        holdings: [],
        cards: [],
        usdToKrwRate: 1300,
      );
      expect(result, closeTo(130000, 0.01));
    });

    test('USD holdings are converted to KRW', () {
      final result = calculate(
        accounts: [],
        holdings: [
          makeHolding(quantity: 1, currentPrice: 200, currency: 'USD'),
        ],
        cards: [],
        usdToKrwRate: 1300,
      );
      expect(result, closeTo(260000, 0.01));
    });

    test('USD card balances are converted before subtracting', () {
      final result = calculate(
        accounts: [],
        holdings: [],
        cards: [makeCard(balance: 100, currency: 'USD')],
        usdToKrwRate: 1300,
      );
      expect(result, closeTo(-130000, 0.01));
    });

    test('combined scenario: accounts + holdings - cards', () {
      // accounts: 500,000 KRW
      // holdings: 10 shares @ 10,000 = 100,000 KRW
      // cards: 50,000 KRW
      // net = 550,000
      final result = calculate(
        accounts: [makeAccount(balance: 500000)],
        holdings: [makeHolding(quantity: 10, currentPrice: 10000)],
        cards: [makeCard(balance: 50000)],
        usdToKrwRate: 1300,
      );
      expect(result, closeTo(550000, 0.01));
    });
  });
}
