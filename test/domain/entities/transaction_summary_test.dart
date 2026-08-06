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
  String account = 'BoA',
  TransactionCategory? category,
}) {
  return SheetTransaction(
    date: date,
    account: account,
    type: type,
    category: type == TransactionType.purchase
        ? (category ?? TransactionCategory.food)
        : null,
    quantity: quantity,
    price: price,
    amount: amount,
    rowIndex: rowIndex,
  );
}

/// The only currency in most tests; 'BoA' is [_tx]'s default account.
const _krw = {'boa': 'KRW'};

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
      expect(july.summarize().byCurrency.single.totalSpending, 30);
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
    test('trade amounts land in invested/divested; transfers are excluded', () {
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

      final s = txs.summarize(currencies: _krw).byCurrency.single;
      expect(s.invested, 1500);
      expect(s.divested, 550);
      expect(s.totalSpending, 0); // transfers/trades are not spending
    });

    test('a buy and sell of equal size read as activity, not a zero', () {
      // The whole reason invested/divested are reported separately: netting
      // them turns a busy month into a number indistinguishable from no trades.
      final txs = [
        _tx(
            date: DateTime(2026, 7, 2),
            type: TransactionType.buy,
            amount: 800000),
        _tx(
            date: DateTime(2026, 7, 20),
            type: TransactionType.sell,
            amount: -800000),
      ];

      final s = txs.summarize(currencies: _krw).byCurrency.single;
      expect(s.invested, 800000);
      expect(s.divested, 800000);
    });

    test('deposits become income, staying out of spending and categories', () {
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -30), // Expense: 30 of spending
        _tx(
            date: DateTime(2026, 7, 5),
            type: TransactionType.deposit,
            amount: 3000),
      ];

      final s = txs.summarize(currencies: _krw).byCurrency.single;
      expect(s.totalSpending, 30);
      expect(s.totalIncome, 3000);
      expect(s.netFlow, 2970); // 3000 in − 30 out
      expect(s.invested, 0);
      expect(s.divested, 0);
      expect(s.spendingByCategory, hasLength(1));
      expect(s.spendingByCategory.single.category, TransactionCategory.food);
      expect(s.spendingByCategory.single.amount, 30);
    });

    test('a month that outspends its income reports a negative net flow', () {
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -500),
        _tx(
            date: DateTime(2026, 7, 5),
            type: TransactionType.deposit,
            amount: 200),
      ];

      expect(txs.summarize(currencies: _krw).byCurrency.single.netFlow, -300);
    });

    test('unrecognized rows are excluded from every total and reported', () {
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -30),
        _tx(
            date: DateTime(2026, 7, 6),
            type: TransactionType.unknown,
            amount: 500),
      ];

      final summary = txs.summarize(currencies: _krw);
      final s = summary.byCurrency.single;
      expect(s.totalSpending, 30);
      expect(s.invested, 0);
      expect(s.divested, 0);
      expect(s.spendingByCategory, hasLength(1));
      expect(summary.uncounted.unknownType, 1);
      expect(summary.uncounted.total, 1);
    });
  });

  group('summarize — currency splitting', () {
    test('each currency gets its own totals and its own category bars', () {
      final txs = [
        _tx(
            date: DateTime(2026, 7, 1),
            account: 'KRW acct',
            amount: -30000,
            category: TransactionCategory.food),
        _tx(
            date: DateTime(2026, 7, 2),
            account: 'USD acct',
            amount: -50,
            category: TransactionCategory.fun),
      ];

      final summary = txs.summarize(
        currencies: {'krw acct': 'KRW', 'usd acct': 'USD'},
      );

      expect(summary.byCurrency, hasLength(2));
      // Ordered by activity: the KRW section is far larger.
      final krw = summary.byCurrency.first;
      final usd = summary.byCurrency.last;
      expect(krw.currency, 'KRW');
      expect(krw.totalSpending, 30000);
      expect(krw.spendingByCategory.single.category, TransactionCategory.food);
      expect(usd.currency, 'USD');
      expect(usd.totalSpending, 50);
      expect(usd.spendingByCategory.single.category, TransactionCategory.fun);
      // Each section's bars partition that section's own spending.
      expect(usd.spendingByCategory.single.fraction, 1.0);
      expect(summary.uncounted.isEmpty, isTrue);
    });

    test('a single-currency month yields one labelled section', () {
      final txs = [_tx(date: DateTime(2026, 7, 1), amount: -30)];

      final summary = txs.summarize(currencies: _krw);
      expect(summary.byCurrency.single.currency, 'KRW');
    });

    test(
        'with no currency known for any row, everything lands in one unlabelled '
        'section and nothing is reported missing', () {
      // The safeguard: an unreachable Accounts tab must not blank the card.
      final txs = [
        _tx(date: DateTime(2026, 7, 1), amount: -30),
        _tx(
            date: DateTime(2026, 7, 2),
            type: TransactionType.buy,
            amount: 100),
      ];

      final summary = txs.summarize(); // no currency map at all
      expect(summary.byCurrency, hasLength(1));
      expect(summary.byCurrency.single.currency, isNull);
      expect(summary.byCurrency.single.totalSpending, 30);
      expect(summary.byCurrency.single.invested, 100);
      expect(summary.uncounted.unknownCurrency, 0);
    });

    test('with partial knowledge, unmapped rows are excluded and counted', () {
      final txs = [
        _tx(date: DateTime(2026, 7, 1), account: 'BoA', amount: -30),
        _tx(date: DateTime(2026, 7, 2), account: 'Mystery', amount: -999),
      ];

      final summary = txs.summarize(currencies: _krw);
      expect(summary.byCurrency.single.totalSpending, 30); // 999 left out
      expect(summary.uncounted.unknownCurrency, 1);
    });

    test('an unmapped transfer is not counted as missing', () {
      // Transfers contribute to nothing even when their currency IS known, so
      // an unplaced one is not a gap in any total.
      final txs = [
        _tx(date: DateTime(2026, 7, 1), account: 'BoA', amount: -30),
        _tx(
            date: DateTime(2026, 7, 2),
            account: 'Mystery',
            type: TransactionType.transfer,
            amount: -999),
      ];

      expect(txs.summarize(currencies: _krw).uncounted.isEmpty, isTrue);
    });

    test('account names are matched ignoring case and surrounding space', () {
      final txs = [
        _tx(date: DateTime(2026, 7, 1), account: '  BoA ', amount: -30),
      ];

      expect(txs.summarize(currencies: _krw).byCurrency.single.currency, 'KRW');
    });
  });

  group('summarize — category breakdown', () {
    test('every category with spend gets an entry, sorted descending', () {
      // Six categories: the removed top-4 cap used to fold the tail into Misc.
      const cats = [
        TransactionCategory.food,
        TransactionCategory.transport,
        TransactionCategory.fun,
        TransactionCategory.clothing,
        TransactionCategory.travel,
        TransactionCategory.misc,
      ];
      final txs = [
        for (final (i, c) in cats.indexed)
          _tx(
              date: DateTime(2026, 7, 1 + i),
              amount: -(60 - i * 10).toDouble(),
              category: c),
      ];

      final bars = txs.summarize(currencies: _krw).byCurrency.single
          .spendingByCategory;

      expect(bars, hasLength(6));
      expect(bars.map((b) => b.category).toList(), cats);
      expect(bars.map((b) => b.amount).toList(), [60, 50, 40, 30, 20, 10]);
      // Misc. is its own smallest entry, not a fold of everything else.
      expect(bars.last.category, TransactionCategory.misc);
      expect(bars.last.amount, 10);
    });

    test('a category summing to zero gets no bar', () {
      final txs = [
        _tx(
            date: DateTime(2026, 7, 1),
            amount: -30,
            category: TransactionCategory.food),
        // A zero-amount purchase, and two rows that cancel out.
        _tx(
            date: DateTime(2026, 7, 2),
            amount: 0,
            category: TransactionCategory.fun),
        _tx(
            date: DateTime(2026, 7, 3),
            amount: -20,
            category: TransactionCategory.travel),
        _tx(
            date: DateTime(2026, 7, 4),
            amount: 20,
            category: TransactionCategory.travel),
      ];

      final bars = txs.summarize(currencies: _krw).byCurrency.single
          .spendingByCategory;

      expect(bars, hasLength(1));
      expect(bars.single.category, TransactionCategory.food);
    });
  });

  // The drill-down behind a category bar. Every case here exists because the
  // page's total has to equal the bar that opened it — any rule these two
  // disagree on shows up as a mismatch on screen.
  group('inCategory', () {
    test('keeps only purchases in that category', () {
      final txs = [
        _tx(date: DateTime(2026, 8, 1), amount: -10, rowIndex: 1),
        _tx(
            date: DateTime(2026, 8, 2),
            amount: -20,
            category: TransactionCategory.travel,
            rowIndex: 2),
        _tx(date: DateTime(2026, 8, 3), amount: -30, rowIndex: 3),
      ];

      final rows = txs.inCategory(TransactionCategory.food,
          currency: 'KRW', currencies: _krw);

      expect(rows.map((t) => t.rowIndex), [1, 3]);
    });

    test('a purchase with no category of its own counts as Misc.', () {
      // _tx defaults a purchase to food, so build this one directly.
      final uncategorized = SheetTransaction(
        date: DateTime(2026, 8, 1),
        account: 'BoA',
        type: TransactionType.purchase,
        amount: -10,
        rowIndex: 1,
      );

      expect(
        [uncategorized].inCategory(TransactionCategory.misc,
            currency: 'KRW', currencies: _krw),
        hasLength(1),
      );
      // And it is not double-counted under some other category.
      expect(
        [uncategorized].inCategory(TransactionCategory.food,
            currency: 'KRW', currencies: _krw),
        isEmpty,
      );
    });

    test('non-purchase rows never match', () {
      final txs = [
        _tx(
            date: DateTime(2026, 8, 1),
            type: TransactionType.deposit,
            amount: 500),
        _tx(
            date: DateTime(2026, 8, 2),
            type: TransactionType.buy,
            quantity: 1,
            price: 100),
      ];

      for (final cat in TransactionCategory.values) {
        expect(txs.inCategory(cat, currency: 'KRW', currencies: _krw), isEmpty,
            reason: cat.label);
      }
    });

    test('excludes rows whose account resolves to another currency', () {
      final txs = [
        _tx(date: DateTime(2026, 8, 1), amount: -10, rowIndex: 1),
        _tx(
            date: DateTime(2026, 8, 2),
            amount: -20,
            account: 'Schwab',
            rowIndex: 2),
      ];
      const currencies = {'boa': 'KRW', 'schwab': 'USD'};

      expect(
        txs
            .inCategory(TransactionCategory.food,
                currency: 'KRW', currencies: currencies)
            .map((t) => t.rowIndex),
        [1],
      );
      expect(
        txs
            .inCategory(TransactionCategory.food,
                currency: 'USD', currencies: currencies)
            .map((t) => t.rowIndex),
        [2],
      );
    });

    test('a null currency is the catch-all section and matches every row', () {
      // summarize() only produces a null-currency section when NO row resolved
      // a currency, so that section covers all of them.
      final txs = [
        _tx(date: DateTime(2026, 8, 1), amount: -10, rowIndex: 1),
        _tx(
            date: DateTime(2026, 8, 2),
            amount: -20,
            account: 'Schwab',
            rowIndex: 2),
      ];

      expect(
        txs.inCategory(TransactionCategory.food).map((t) => t.rowIndex),
        [1, 2],
      );
    });
  });

  group('monthlySpend', () {
    test('returns the whole window oldest-first, ending at endMonth', () {
      final trend = <SheetTransaction>[].monthlySpend(
        TransactionCategory.food,
        endMonth: DateTime(2026, 8),
        currencies: _krw,
      );

      expect(trend, hasLength(12));
      expect(trend.first.month, DateTime(2025, 9));
      expect(trend.last.month, DateTime(2026, 8));
    });

    test('months with no spend are present and zero', () {
      final txs = [_tx(date: DateTime(2026, 8, 10), amount: -300)];

      final trend = txs.monthlySpend(
        TransactionCategory.food,
        endMonth: DateTime(2026, 8),
        currency: 'KRW',
        currencies: _krw,
      );

      // A gap is a real observation, and it keeps the bar count fixed.
      expect(trend.last.amount, 300);
      expect(trend.take(11).map((p) => p.amount), everyElement(0));
    });

    test('sums a month and reports spending positive', () {
      final txs = [
        _tx(date: DateTime(2026, 8, 1), amount: -100, rowIndex: 1),
        _tx(date: DateTime(2026, 8, 2), amount: -250, rowIndex: 2),
        // Another category in the same month must not leak in.
        _tx(
            date: DateTime(2026, 8, 3),
            amount: -999,
            category: TransactionCategory.travel,
            rowIndex: 3),
      ];

      final trend = txs.monthlySpend(
        TransactionCategory.food,
        endMonth: DateTime(2026, 8),
        currency: 'KRW',
        currencies: _krw,
      );

      expect(trend.last.amount, 350);
    });

    test('a window crossing a year boundary walks back correctly', () {
      final txs = [_tx(date: DateTime(2025, 12, 5), amount: -40)];

      final trend = txs.monthlySpend(
        TransactionCategory.food,
        endMonth: DateTime(2026, 2),
        months: 4,
        currency: 'KRW',
        currencies: _krw,
      );

      expect(trend.map((p) => p.month),
          [DateTime(2025, 11), DateTime(2025, 12), DateTime(2026, 1), DateTime(2026, 2)]);
      expect(trend[1].amount, 40);
    });

    test('rows outside the window are left out', () {
      final txs = [
        _tx(date: DateTime(2024, 1, 5), amount: -999),
        _tx(date: DateTime(2026, 8, 5), amount: -10),
      ];

      final trend = txs.monthlySpend(
        TransactionCategory.food,
        endMonth: DateTime(2026, 8),
        currency: 'KRW',
        currencies: _krw,
      );

      expect(trend.fold<double>(0, (a, p) => a + p.amount), 10);
    });
  });
}
