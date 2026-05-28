import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';
import 'package:jibsaja/domain/entities/asset_type.dart';
import 'package:jibsaja/domain/entities/holding_type.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/use_cases/compute_holdings.dart';

Account makeAccount({String id = 'invest-1', String currency = 'USD'}) {
  final now = DateTime.now();
  return Account(
    id: id,
    userId: 'user-1',
    name: 'Investment',
    type: AccountType.investment,
    balance: 0,
    currency: currency,
    createdAt: now,
    updatedAt: now,
  );
}

Transaction makeTrade({
  required String id,
  required TransactionType type,
  required String ticker,
  required double quantity,
  required double price,
  String accountId = 'invest-1',
  DateTime? date,
}) {
  final now = DateTime.now();
  return Transaction(
    id: id,
    userId: 'user-1',
    accountId: accountId,
    title: '${type == TransactionType.buy ? 'Buy' : 'Sell'} $ticker',
    amount: quantity * price,
    type: type,
    category: TransactionCategory.investment,
    date: date ?? now,
    ticker: ticker,
    assetName: ticker,
    assetType: AssetType.stock,
    quantity: quantity,
    pricePerUnit: price,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const compute = ComputeHoldings();
  final account = makeAccount();

  group('ComputeHoldings', () {
    test('returns empty list when no transactions', () {
      expect(compute(transactions: [], accounts: [account]), isEmpty);
    });

    test('single buy creates one holding', () {
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 10, price: 150),
        ],
        accounts: [account],
      );
      expect(holdings, hasLength(1));
      expect(holdings.first.ticker, 'AAPL');
      expect(holdings.first.quantity, 10);
      expect(holdings.first.avgCostPrice, 150);
    });

    test('buy then partial sell reduces quantity', () {
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 10, price: 150,
              date: DateTime(2025, 1, 1)),
          makeTrade(id: 'tx-2', type: TransactionType.sell, ticker: 'AAPL',
              quantity: 4, price: 160,
              date: DateTime(2025, 2, 1)),
        ],
        accounts: [account],
      );
      expect(holdings, hasLength(1));
      expect(holdings.first.quantity, 6);
    });

    test('sell to zero removes holding from results', () {
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 5, price: 100, date: DateTime(2025, 1, 1)),
          makeTrade(id: 'tx-2', type: TransactionType.sell, ticker: 'AAPL',
              quantity: 5, price: 110, date: DateTime(2025, 2, 1)),
        ],
        accounts: [account],
      );
      expect(holdings, isEmpty);
    });

    test('two buys at different prices produce weighted average cost', () {
      // Buy 10 @ 100 = cost 1000; buy 10 @ 200 = cost 2000; avg = 150
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 10, price: 100, date: DateTime(2025, 1, 1)),
          makeTrade(id: 'tx-2', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 10, price: 200, date: DateTime(2025, 1, 2)),
        ],
        accounts: [account],
      );
      expect(holdings, hasLength(1));
      expect(holdings.first.quantity, 20);
      expect(holdings.first.avgCostPrice, closeTo(150, 0.001));
    });

    test('different tickers produce separate holdings', () {
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 5, price: 150),
          makeTrade(id: 'tx-2', type: TransactionType.buy, ticker: 'TSLA',
              quantity: 2, price: 200),
        ],
        accounts: [account],
      );
      expect(holdings, hasLength(2));
      final tickers = holdings.map((h) => h.ticker).toSet();
      expect(tickers, containsAll(['AAPL', 'TSLA']));
    });

    test('same ticker in different accounts are separate holdings', () {
      final account2 = makeAccount(id: 'invest-2');
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 5, price: 150, accountId: 'invest-1'),
          makeTrade(id: 'tx-2', type: TransactionType.buy, ticker: 'AAPL',
              quantity: 3, price: 160, accountId: 'invest-2'),
        ],
        accounts: [account, account2],
      );
      expect(holdings, hasLength(2));
    });

    test('holding type maps from AssetType correctly', () {
      final holdings = compute(
        transactions: [
          makeTrade(id: 'tx-1', type: TransactionType.buy, ticker: 'ETH',
              quantity: 1, price: 3000),
        ],
        accounts: [account],
      );
      // makeTrade uses AssetType.stock → HoldingType.stock
      expect(holdings.first.type, HoldingType.stock);
    });

    test('non-trade transactions are ignored', () {
      final now = DateTime.now();
      final holdings = compute(
        transactions: [
          Transaction(
            id: 'tx-income',
            userId: 'user-1',
            accountId: 'invest-1',
            title: 'Dividend',
            amount: 5000,
            type: TransactionType.income,
            category: TransactionCategory.investment,
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        accounts: [account],
      );
      expect(holdings, isEmpty);
    });
  });
}
