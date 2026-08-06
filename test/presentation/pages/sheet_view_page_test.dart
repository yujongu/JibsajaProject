import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_account.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/presentation/extensions/transaction_category_ui.dart';
import 'package:jibsaja/presentation/pages/category/category_detail_page.dart';
import 'package:jibsaja/presentation/pages/sheet/sheet_view_page.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';

/// Pumps the page with the sheet-backed providers stubbed out, so no repository
/// (and no network) is ever constructed. [transactionsUpdatedAtProvider] is
/// overridden too because it reaches for the repository directly.
Future<void> _pumpPage(
  WidgetTester tester,
  List<SheetTransaction> txs,
) async {
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
      child: const MaterialApp(home: SheetViewPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The page opens on the current month, so a row dated in the past leaves the
  // month on screen empty.
  final lastYear = DateTime(DateTime.now().year - 1, 6, 15);

  group('summary card with no transactions in the month', () {
    testWidgets('still renders its stat blocks', (tester) async {
      await _pumpPage(tester, [
        SheetTransaction(
          date: lastYear,
          account: 'BoA',
          type: TransactionType.purchase,
          category: TransactionCategory.food,
          amount: -10,
          rowIndex: 0,
        ),
      ]);

      // Regression: an empty month used to summarize to zero sections, leaving
      // the card's Column childless. It then shrank to its 18px padding, and
      // an 18px border radius on a 36px box renders as a circle.
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Net flow'), findsOneWidget);
    });

    testWidgets('keeps the card at full width, not collapsed to a circle',
        (tester) async {
      await _pumpPage(tester, [
        SheetTransaction(
          date: lastYear,
          account: 'BoA',
          type: TransactionType.purchase,
          category: TransactionCategory.food,
          amount: -10,
          rowIndex: 0,
        ),
      ]);

      // The card is the Container wrapping the 'Spending' stat block; 36px wide
      // was the bug, full width minus the page's 16px side padding is correct.
      final card = tester.getSize(
        find
            .ancestor(
              of: find.text('Spending'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(card.width, greaterThan(200));
    });

    testWidgets('shows zeroed, unlabelled amounts', (tester) async {
      await _pumpPage(tester, [
        SheetTransaction(
          date: lastYear,
          account: 'BoA',
          type: TransactionType.purchase,
          category: TransactionCategory.food,
          amount: -10,
          rowIndex: 0,
        ),
      ]);

      // No row means no currency to name, so the zeros carry no symbol.
      // Spending and Income both read '0'; the net-flow caption carries an
      // explicit sign, and _NetCaption treats any non-negative value as '+'.
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('+0'), findsOneWidget);
      // Nothing to break down, and no trades, so those sections stay hidden.
      expect(find.text('Spending by category'), findsNothing);
      expect(find.text('Invested'), findsNothing);
    });
  });

  testWidgets('a month with rows still shows its real totals', (tester) async {
    final now = DateTime.now();
    await _pumpPage(tester, [
      SheetTransaction(
        date: DateTime(now.year, now.month, 1),
        account: 'BoA',
        type: TransactionType.purchase,
        category: TransactionCategory.food,
        amount: -1200,
        rowIndex: 0,
      ),
    ]);

    expect(find.text('₩1,200'), findsWidgets);
    expect(find.text('Spending by category'), findsOneWidget);
  });

  testWidgets('a sell-only month shows Sold with no net line', (tester) async {
    final now = DateTime.now();
    await _pumpPage(tester, [
      SheetTransaction(
        date: DateTime(now.year, now.month, 1),
        account: 'BoA',
        type: TransactionType.sell,
        quantity: -8,
        price: 100000,
        amount: -800000,
        rowIndex: 0,
      ),
    ]);

    // Sell proceeds are cash in, reported as a positive magnitude.
    expect(find.text('Sold'), findsOneWidget);
    expect(find.text('₩800,000'), findsOneWidget);
    expect(find.text('Invested'), findsOneWidget);
    // Only the cash-flow caption remains; the trade net that used to echo
    // Sold back as −₩800,000 is gone. 'Net flow' is a distinct string.
    expect(find.text('Net'), findsNothing);
    expect(find.text('Net flow'), findsOneWidget);
  });

  testWidgets('purchase rows are colored by category, not by type',
      (tester) async {
    final now = DateTime.now();
    await _pumpPage(tester, [
      SheetTransaction(
        date: DateTime(now.year, now.month, 1),
        account: 'BoA',
        type: TransactionType.purchase,
        category: TransactionCategory.food,
        description: 'Lunch',
        amount: -1200,
        rowIndex: 0,
      ),
      SheetTransaction(
        date: DateTime(now.year, now.month, 1),
        account: 'BoA',
        type: TransactionType.purchase,
        category: TransactionCategory.wedding,
        description: 'Venue',
        amount: -5000,
        rowIndex: 1,
      ),
    ]);

    final food = _tileIconColor(tester, Icons.restaurant_rounded);
    final wedding = _tileIconColor(tester, Icons.favorite_rounded);

    // Both used to be AppColors.negative, which is what made a month of
    // spending unreadable without squinting at the icons.
    expect(food, TransactionCategory.food.color(false));
    expect(wedding, TransactionCategory.wedding.color(false));
    expect(food, isNot(wedding));
  });

  testWidgets('tapping a category bar opens that category', (tester) async {
    final now = DateTime.now();
    await _pumpPage(tester, [
      SheetTransaction(
        date: DateTime(now.year, now.month, 1),
        account: 'BoA',
        type: TransactionType.purchase,
        category: TransactionCategory.travel,
        description: 'Flight',
        amount: -186000,
        rowIndex: 0,
      ),
    ]);

    // The 14px icon is the bar's; the 20px one belongs to the row below it.
    final bar = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.flight_rounded && w.size == 14,
    );
    expect(bar, findsOneWidget);

    await tester.tap(bar);
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDetailPage), findsOneWidget);
    expect(find.text('Last 12 months'), findsOneWidget);
  });
}

/// Color of the 20px leading icon in a transaction row. The category bars in
/// the summary card draw the same [IconData] at 14px, so the size disambiguates.
Color _tileIconColor(WidgetTester tester, IconData data) {
  final icons = tester
      .widgetList<Icon>(find.byIcon(data))
      .where((i) => i.size == 20)
      .toList();
  expect(icons, hasLength(1));
  return icons.single.color!;
}
