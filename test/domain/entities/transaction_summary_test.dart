import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_summary.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';

SheetTransaction _tx({
  required DateTime date,
  TransactionType type = TransactionType.purchase,
  double? amount,
  double? quantity,
  double? price,
  int rowIndex = 0,
}) {
  return SheetTransaction(
    date: date,
    account: 'BoA',
    type: type,
    category: type == TransactionType.purchase ? TransactionCategory.food : null,
    quantity: quantity,
    price: price,
    amount: amount,
    rowIndex: rowIndex,
  );
}

void main() {
  group('inMonth', () {
    test('keeps only rows in the given calendar month', () {
      // Expense rows store negative Amounts; spending reports positive.
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -10),
        _tx(date: DateTime(2026, 7, 31), amount: -20),
        _tx(date: DateTime(2026, 6, 30), amount: -99), // previous month
        _tx(date: DateTime(2025, 7, 15), amount: -99), // same month, last year
      ];

      final july = txs.inMonth(2026, 7);
      expect(july, hasLength(2));
      expect(july.summarize().totalSpending, 30);
    });
  });

  group('newestFirst ordering', () {
    test('same-timestamp rows order by sheet position, later rows first', () {
      final sameDay = DateTime(2026, 7, 2); // midnight — timestamps tie
      final txs = [
        _tx(date: sameDay, amount: -1, rowIndex: 10),
        _tx(date: DateTime(2026, 7, 3), amount: -2, rowIndex: 11),
        _tx(date: sameDay, amount: -3, rowIndex: 12),
        _tx(date: sameDay, amount: -4, rowIndex: 5),
      ];

      final groups = txs.groupByMonth();
      expect(groups, hasLength(1));
      final ordered = groups.first.transactions;

      // Newest date first, then descending sheet position among ties.
      expect(ordered.map((t) => t.rowIndex).toList(), [11, 12, 10, 5]);
    });
  });

  group('summarize', () {
    test('netInvested sums signed trade amounts; transfers are excluded', () {
      final txs = [
        // Buy leg pair: Transfer −1500 + Buy +1500.
        _tx(
            date: DateTime(2026, 7, 2),
            type: TransactionType.transfer,
            amount: -1500),
        _tx(
            date: DateTime(2026, 7, 2),
            type: TransactionType.buy,
            quantity: 10,
            price: 150,
            amount: 1500),
        // Sell leg pair: Transfer +550 + Sell −550 (negative quantity).
        _tx(
            date: DateTime(2026, 7, 3),
            type: TransactionType.transfer,
            amount: 550),
        _tx(
            date: DateTime(2026, 7, 3),
            type: TransactionType.sell,
            quantity: -5,
            price: 110,
            amount: -550),
      ];

      final summary = txs.summarize();
      expect(summary.netInvested, 950); // 1500 − 550
      expect(summary.totalSpending, 0); // transfers/trades are not spending
    });

    test('deposits are excluded from spending and the category breakdown', () {
      // A positive-Amount Deposit used to be typed as a Purchase, so −amount
      // was subtracted from spending — understating the total.
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -30), // Expense: 30 of spending
        _tx(
            date: DateTime(2026, 7, 5),
            type: TransactionType.deposit,
            amount: 3000),
      ];

      final summary = txs.summarize();
      expect(summary.totalSpending, 30);
      expect(summary.netInvested, 0);
      expect(summary.spendingByCategory, hasLength(1));
      expect(summary.spendingByCategory.single.category,
          TransactionCategory.food);
      expect(summary.spendingByCategory.single.amount, 30);
    });

    test('unrecognized rows are excluded from every total', () {
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -30),
        _tx(
            date: DateTime(2026, 7, 6),
            type: TransactionType.unknown,
            amount: 500),
      ];

      final summary = txs.summarize();
      expect(summary.totalSpending, 30);
      expect(summary.netInvested, 0);
      expect(summary.spendingByCategory, hasLength(1));
    });
  });
}
