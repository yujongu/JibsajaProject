import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/sheet_transaction_model.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';

void main() {
  group('SheetTransactionModel.fromJson', () {
    test('parses an Expense row with a sheet-native Korean category', () {
      final tx = SheetTransactionModel.fromJson({
        'date': '2026-06-01T00:00:00.000',
        'account': 'BoA',
        'type': 'Expense',
        'category': '식비',
        'description': 'Lunch',
        'amount': -12.5, // stored negative in the sheet
      });

      expect(tx.type, TransactionType.purchase);
      expect(tx.account, 'BoA');
      expect(tx.category, TransactionCategory.food);
      expect(tx.description, 'Lunch');
      expect(tx.computedAmount, -12.5);
    });

    test('legacy Purchase type and enum-name category still parse', () {
      final tx = SheetTransactionModel.fromJson({
        'type': 'Purchase',
        'category': 'food',
      });

      expect(tx.type, TransactionType.purchase);
      expect(tx.category, TransactionCategory.food);
    });

    test('unknown category falls back to Misc.', () {
      final tx = SheetTransactionModel.fromJson({
        'type': 'Expense',
        'category': 'no-such-category',
      });

      expect(tx.category, TransactionCategory.misc);
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

    test('parses a capitalized-key buy row with Symbol (live schema)', () {
      final tx = SheetTransactionModel.fromJson({
        'Date': '2026-01-31T15:00:00.000Z',
        'Account': '토스증권 국내 주식',
        'Type': 'Buy',
        'Category': '',
        'Description': '',
        'Symbol': '190510',
        'Quantity': 1,
        'Price': 27550,
        'Amount': 27550,
      });

      expect(tx.type, TransactionType.buy);
      expect(tx.account, '토스증권 국내 주식');
      expect(tx.ticker, '190510');
      expect(tx.quantity, 1);
      expect(tx.price, 27550);
      expect(tx.category, isNull);
      // UTC sheet timestamps are normalized to local time (same instant) so
      // day/month grouping matches the sheet's calendar date.
      expect(
        tx.date.isAtSameMomentAs(DateTime.parse('2026-01-31T15:00:00.000Z')),
        isTrue,
      );
      expect(tx.date.isUtc, isFalse);
    });

    test('carries the sheet row position through rowIndex', () {
      final tx = SheetTransactionModel.fromJson(
        {'type': 'Expense'},
        rowIndex: 42,
      );

      expect(tx.rowIndex, 42);
    });

    test('falls back gracefully on bad/empty values', () {
      final tx = SheetTransactionModel.fromJson({'type': 'wat'});
      expect(tx.type, TransactionType.purchase);
      expect(tx.account, '');
      expect(tx.category, isNull);
      expect(tx.ticker, isNull);
    });

    test('resolves keys case-insensitively (mixed-case)', () {
      final tx = SheetTransactionModel.fromJson({
        'dAtE': '2026-06-02',
        'tYpE': 'Buy',
        'sYmBoL': 'AAPL',
        'qUaNtItY': '10',
        'pRiCe': '150',
      });

      expect(tx.type, TransactionType.buy);
      expect(tx.ticker, 'AAPL');
      expect(tx.quantity, 10);
      expect(tx.price, 150);
    });

    test('empty Symbol falls back to legacy ticker', () {
      final tx = SheetTransactionModel.fromJson({
        'Symbol': '',
        'ticker': 'AAPL',
      });

      expect(tx.ticker, 'AAPL');
    });

    test('non-empty Symbol takes precedence over co-present ticker', () {
      final tx = SheetTransactionModel.fromJson({
        'Symbol': 'MSFT',
        'ticker': 'AAPL',
      });

      expect(tx.ticker, 'MSFT');
    });
  });

  group('SheetTransactionModel.toRows', () {
    test('purchase produces one Expense row in column order', () {
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
      expect(row[2], 'Expense'); // app-side "Purchase" stores as Expense
      expect(row[3], '식비'); // category wire value, not the enum name
      expect(row[5], ''); // symbol
      expect(row[6], ''); // quantity
      expect(row[7], ''); // price
      expect(row[8], -12.5); // expenses store a negative Amount (cash out)
    });

    test('direct transfer produces one row with the value in Amount only', () {
      final rows = SheetTransactionModel.toRows(SheetTransaction(
        date: DateTime(2026, 7, 4),
        account: 'Toss',
        type: TransactionType.transfer,
        description: 'Move to brokerage',
        amount: 500000,
      ));

      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.length, SheetTransactionModel.columns.length);
      expect(row[0], DateTime(2026, 7, 4).toIso8601String());
      expect(row[1], 'Toss');
      expect(row[2], 'Transfer');
      expect(row[3], ''); // category
      expect(row[4], 'Move to brokerage');
      expect(row[5], ''); // symbol
      expect(row[6], ''); // quantity
      expect(row[7], ''); // price stays blank
      expect(row[8], 500000); // the transfer value lives in Amount, as entered
    });

    test('buy produces a Transfer cash leg then the Buy trade leg', () {
      final rows = SheetTransactionModel.toRows(SheetTransaction(
        date: DateTime(2026, 7, 2),
        account: 'BoA',
        type: TransactionType.buy,
        description: 'AAPL buy',
        secondAccount: 'Robinhood',
        ticker: 'AAPL',
        quantity: 10,
        price: 150,
      ));

      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.length, SheetTransactionModel.columns.length);
        expect(row[0], DateTime(2026, 7, 2).toIso8601String());
        expect(row[4], 'AAPL buy');
      }

      final transfer = rows[0];
      expect(transfer[1], 'BoA');
      expect(transfer[2], 'Transfer');
      expect(transfer[3], ''); // category
      expect(transfer[5], ''); // symbol
      expect(transfer[6], ''); // quantity
      expect(transfer[7], ''); // price
      expect(transfer[8], -1500); // cash leaves the funding account

      final buy = rows[1];
      expect(buy[1], 'Robinhood');
      expect(buy[2], 'Buy');
      expect(buy[5], 'AAPL');
      expect(buy[6], 10);
      expect(buy[7], 150);
      expect(buy[8], 1500);
    });

    test('sell is the mirror image: cash comes back, trade leg negative', () {
      final rows = SheetTransactionModel.toRows(SheetTransaction(
        date: DateTime(2026, 7, 2),
        account: 'BoA',
        type: TransactionType.sell,
        secondAccount: 'Robinhood',
        ticker: 'AAPL',
        quantity: 10,
        price: 150,
      ));

      expect(rows, hasLength(2));

      final transfer = rows[0];
      expect(transfer[1], 'BoA');
      expect(transfer[2], 'Transfer');
      expect(transfer[8], 1500); // proceeds land in the cash account

      final sell = rows[1];
      expect(sell[1], 'Robinhood');
      expect(sell[2], 'Sell');
      expect(sell[5], 'AAPL');
      expect(sell[6], -10); // sheet stores Sell quantities negative
      expect(sell[7], 150);
      expect(sell[8], -1500); // = quantity × price
    });

    test('trade without a second account falls back to the same account', () {
      final rows = SheetTransactionModel.toRows(SheetTransaction(
        date: DateTime(2026, 7, 2),
        account: 'Robinhood',
        type: TransactionType.buy,
        ticker: 'AAPL',
        quantity: 1,
        price: 100,
      ));

      expect(rows, hasLength(2));
      expect(rows[0][1], 'Robinhood');
      expect(rows[1][1], 'Robinhood');
    });
  });

  group('Transfer rows (read-back)', () {
    test('fromJson parses a Transfer row with a signed amount', () {
      final tx = SheetTransactionModel.fromJson({
        'Date': '2026-07-02T00:00:00.000',
        'Account': 'BoA',
        'Type': 'Transfer',
        'Description': 'AAPL buy',
        'Amount': -1500,
      });

      expect(tx.type, TransactionType.transfer);
      expect(tx.account, 'BoA');
      expect(tx.computedAmount, -1500);
    });

    test('read-back direct transfer takes its value from Amount', () {
      final tx = SheetTransactionModel.fromJson({
        'Date': '2026-07-04T00:00:00.000',
        'Account': 'Toss',
        'Type': 'Transfer',
        'Description': 'Move to brokerage',
        'Symbol': '',
        'Quantity': '',
        'Price': '',
        'Amount': 500000,
      });

      expect(tx.type, TransactionType.transfer);
      expect(tx.computedAmount, 500000);
    });

    test('legacy direct transfer (value in Price, Amount blank) still reads',
        () {
      final tx = SheetTransactionModel.fromJson({
        'Date': '2026-07-04T00:00:00.000',
        'Account': 'Toss',
        'Type': 'Transfer',
        'Description': 'Move to brokerage',
        'Symbol': '',
        'Quantity': '',
        'Price': 500000,
        'Amount': '',
      });

      expect(tx.type, TransactionType.transfer);
      expect(tx.amount, isNull);
      expect(tx.computedAmount, 500000);
    });

    test('computedAmount is quantity × price for read-back Sell rows', () {
      // Read-back Sell rows carry a negative quantity, so the plain multiply
      // yields the sheet's negative total without special-casing the type.
      final tx = SheetTransaction(
        date: DateTime(2026, 7, 2),
        account: 'Robinhood',
        type: TransactionType.sell,
        quantity: -10,
        price: 150,
      );

      expect(tx.computedAmount, -1500);
    });
  });
}
