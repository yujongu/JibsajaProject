import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/sheet_transaction_model.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';

void main() {
  group('SheetTransactionModel.fromJson', () {
    test('parses a purchase row', () {
      final tx = SheetTransactionModel.fromJson({
        'date': '2026-06-01T00:00:00.000',
        'account': 'BoA',
        'type': 'Purchase',
        'category': 'food',
        'description': 'Lunch',
        'amount': 12.5,
      });

      expect(tx.type, TransactionType.purchase);
      expect(tx.account, 'BoA');
      expect(tx.category, TransactionCategory.food);
      expect(tx.description, 'Lunch');
      expect(tx.computedAmount, 12.5);
    });

    test('parses a buy row and computes total', () {
      final tx = SheetTransactionModel.fromJson({
        'date': '2026-06-02',
        'account': 'Robinhood',
        'type': 'Buy',
        'ticker': 'AAPL',
        'quantity': '10',
        'price': '150',
      });

      expect(tx.type, TransactionType.buy);
      expect(tx.ticker, 'AAPL');
      expect(tx.quantity, 10);
      expect(tx.price, 150);
      expect(tx.computedAmount, 1500);
    });

    test('falls back gracefully on bad/empty values', () {
      final tx = SheetTransactionModel.fromJson({'type': 'wat'});
      expect(tx.type, TransactionType.purchase);
      expect(tx.account, '');
      expect(tx.category, isNull);
      expect(tx.ticker, isNull);
    });
  });

  group('SheetTransactionModel.toRows', () {
    test('purchase produces one row in column order', () {
      final rows = SheetTransactionModel.toRows(SheetTransaction(
        date: DateTime(2026, 6, 1),
        account: 'BoA',
        type: TransactionType.purchase,
        category: TransactionCategory.food,
        description: 'Lunch',
        amount: 12.5,
      ));

      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.length, SheetTransactionModel.columns.length);
      expect(row[1], 'BoA');
      expect(row[2], 'Purchase');
      expect(row[3], 'food');
      expect(row[8], 12.5);
    });

    test('buy produces a trade row (placeholder)', () {
      final rows = SheetTransactionModel.toRows(SheetTransaction(
        date: DateTime(2026, 6, 2),
        account: 'Robinhood',
        type: TransactionType.buy,
        ticker: 'AAPL',
        quantity: 10,
        price: 150,
      ));

      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row[2], 'Buy');
      expect(row[5], 'AAPL');
      expect(row[8], 1500);
    });
  });
}
