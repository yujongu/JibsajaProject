import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_account.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/presentation/pages/category/category_detail_page.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';

/// Pumps the page with the sheet-backed providers stubbed out, so no repository
/// (and no network) is ever constructed — same shape as the sheet-view test.
Future<void> _pumpPage(
  WidgetTester tester,
  List<SheetTransaction> txs, {
  TransactionCategory category = TransactionCategory.food,
  String? currency = 'KRW',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionsProvider.overrideWith((ref) => Stream.value(txs)),
        accountsProvider.overrideWith(
          (ref) => Stream.value(
            const [SheetAccount(name: 'BoA', currency: 'KRW')],
          ),
        ),
        transactionsUpdatedAtProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        home: CategoryDetailPage(category: category, currency: currency),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SheetTransaction _purchase({
  required DateTime date,
  required TransactionCategory category,
  required String description,
  required double amount,
  required int rowIndex,
}) =>
    SheetTransaction(
      date: date,
      account: 'BoA',
      type: TransactionType.purchase,
      category: category,
      description: description,
      amount: amount,
      rowIndex: rowIndex,
    );

void main() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 1);
  final lastMonth = DateTime(now.year, now.month - 1, 1);

  testWidgets('lists only the chosen category, in the selected month',
      (tester) async {
    await _pumpPage(tester, [
      _purchase(
        date: thisMonth,
        category: TransactionCategory.food,
        description: 'Lunch',
        amount: -1200,
        rowIndex: 0,
      ),
      _purchase(
        date: thisMonth,
        category: TransactionCategory.travel,
        description: 'Flight',
        amount: -186000,
        rowIndex: 1,
      ),
      _purchase(
        date: lastMonth,
        category: TransactionCategory.food,
        description: 'Old dinner',
        amount: -9000,
        rowIndex: 2,
      ),
    ]);

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Flight'), findsNothing);
    expect(find.text('Old dinner'), findsNothing);
  });

  testWidgets('the header total matches the bar that opens the page',
      (tester) async {
    await _pumpPage(tester, [
      _purchase(
        date: thisMonth,
        category: TransactionCategory.food,
        description: 'Lunch',
        amount: -1200,
        rowIndex: 0,
      ),
      _purchase(
        date: thisMonth,
        category: TransactionCategory.food,
        description: 'Coffee',
        amount: -800,
        rowIndex: 1,
      ),
      // Half the month's spending is another category, so the share is 50%.
      _purchase(
        date: thisMonth,
        category: TransactionCategory.travel,
        description: 'Flight',
        amount: -2000,
        rowIndex: 2,
      ),
    ]);

    // This is the acceptance criterion: a drill-down whose total disagrees with
    // its bar means the filter drifted from summarize()'s rules.
    expect(find.text('₩2,000'), findsOneWidget);
    expect(
      find.textContaining('2 transactions · 50% of spending'),
      findsOneWidget,
    );
  });

  testWidgets('a purchase with no category of its own lands under Misc.',
      (tester) async {
    await _pumpPage(
      tester,
      [
        SheetTransaction(
          date: thisMonth,
          account: 'BoA',
          type: TransactionType.purchase,
          description: 'Cash withdrawal',
          amount: -8000,
          rowIndex: 0,
        ),
      ],
      category: TransactionCategory.misc,
    );

    expect(find.text('Cash withdrawal'), findsOneWidget);
    expect(find.text('₩8,000'), findsOneWidget);
  });

  testWidgets('the trend always renders a full 12-month window',
      (tester) async {
    await _pumpPage(tester, [
      _purchase(
        date: thisMonth,
        category: TransactionCategory.food,
        description: 'Lunch',
        amount: -1200,
        rowIndex: 0,
      ),
    ]);

    expect(find.text('Last 12 months'), findsOneWidget);
    // One single-letter label per month. Months with no spend still get a slot,
    // so the bar count never changes with how much history the sheet holds.
    final labels = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(Row),
          matching: find.byType(Text),
        ))
        .where((t) => (t.data ?? '').length == 1);
    expect(labels, hasLength(12));
  });

  testWidgets('a month with no rows in the category shows the empty notice',
      (tester) async {
    await _pumpPage(tester, [
      _purchase(
        date: lastMonth,
        category: TransactionCategory.food,
        description: 'Old dinner',
        amount: -9000,
        rowIndex: 0,
      ),
    ]);

    expect(find.text('No transactions in this category'), findsOneWidget);
    // The header falls back to a zeroed stand-in rather than breaking.
    expect(find.text('₩0'), findsOneWidget);
  });
}
