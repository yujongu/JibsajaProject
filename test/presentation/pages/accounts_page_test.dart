import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_account.dart';
import 'package:jibsaja/presentation/pages/accounts/accounts_page.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';
import 'package:jibsaja/presentation/shared/widgets/updated_at_label.dart';

/// Pumps the page with [accountsProvider] stubbed, so no repository (and no
/// network) is ever constructed. [accountsUpdatedAtProvider] is overridden too
/// because it reaches for the repository directly.
Future<void> _pumpPage(
  WidgetTester tester,
  List<SheetAccount> accounts, {
  DateTime? updatedAt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        accountsUpdatedAtProvider.overrideWithValue(updatedAt),
      ],
      child: const MaterialApp(home: AccountsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const credit = SheetAccount(
    name: '현대카드',
    currency: 'KRW',
    type: 'Credit',
    currentBalance: -512300,
  );
  const bank = SheetAccount(
    name: 'BoA Checking',
    currency: 'USD',
    type: 'Bank',
    currentBalance: 1842.5,
  );
  const brokerage = SheetAccount(
    name: '토스증권 국내 주식',
    currency: 'KRW',
    type: 'Brokerage',
    currentBalance: 9000000,
  );

  testWidgets('lists credit and bank accounts under their own headings',
      (tester) async {
    await _pumpPage(tester, const [credit, bank]);

    expect(find.text('Credit cards'), findsOneWidget);
    expect(find.text('Bank accounts'), findsOneWidget);
    expect(find.text('현대카드'), findsOneWidget);
    expect(find.text('BoA Checking'), findsOneWidget);
  });

  testWidgets('shows each balance as the sheet stores it, sign included',
      (tester) async {
    await _pumpPage(tester, const [credit, bank]);

    // No abs(), no sign convention of the app's own — a negative card balance
    // in the sheet reads as a negative here.
    expect(find.text('₩-512,300'), findsOneWidget);
    expect(find.text(r'$1,842.5'), findsOneWidget);
  });

  testWidgets('omits every other account type', (tester) async {
    await _pumpPage(tester, const [credit, brokerage]);

    expect(find.text('현대카드'), findsOneWidget);
    expect(find.text('토스증권 국내 주식'), findsNothing);
    // Its section heading goes too, rather than sitting empty.
    expect(find.text('Bank accounts'), findsNothing);
  });

  testWidgets('a blank balance cell shows a dash, not a zero', (tester) async {
    await _pumpPage(tester, const [
      SheetAccount(name: 'Mystery card', currency: 'KRW', type: 'Credit'),
    ]);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('₩0'), findsNothing);
  });

  testWidgets('no credit or bank rows at all shows the empty notice',
      (tester) async {
    await _pumpPage(tester, const [brokerage]);

    expect(
      find.text('No credit or bank accounts in the sheet'),
      findsOneWidget,
    );
  });

  testWidgets('carries the shared updated-at label, fed by its own provider',
      (tester) async {
    await _pumpPage(tester, const [credit]);

    // The regression this guards is the label being absent from the page
    // entirely, which is how the tab first shipped. That it renders nothing for
    // a null time is UpdatedAtLabel's documented behavior, and the value the
    // page feeds it is covered by accountsUpdatedAtProvider's own tests —
    // pumping a non-null one here would subscribe the widget's one-minute
    // ticker, which no amount of pumping settles.
    // skipOffstage: false because a null time makes the label render
    // SizedBox.shrink(), and a zero-size widget does not match the default
    // finder even though it is mounted.
    final label = find.byType(UpdatedAtLabel, skipOffstage: false);
    expect(label, findsOneWidget);
    expect(tester.widget<UpdatedAtLabel>(label).updatedAt, isNull);
    expect(find.textContaining('Updated'), findsNothing);
  });
}
