import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_holding.dart';
import 'package:jibsaja/presentation/pages/holdings/holdings_page.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';
import 'package:jibsaja/presentation/shared/widgets/updated_at_label.dart';

/// Pumps the page with [holdingsProvider] stubbed, so no repository (and no
/// network) is ever constructed. [holdingsUpdatedAtProvider] is overridden too
/// because it reaches for the repository directly.
Future<void> _pumpPage(
  WidgetTester tester,
  List<SheetHolding> holdings, {
  DateTime? updatedAt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        holdingsProvider.overrideWith((ref) => Stream.value(holdings)),
        holdingsUpdatedAtProvider.overrideWithValue(updatedAt),
      ],
      child: const MaterialApp(home: HoldingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The symbols currently on screen, top to bottom. Symbol labels are the 15px
/// bold texts inside the rows; the sort header's are 10px, so filtering by
/// size separates them from everything else.
List<String> _rowSymbols(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.style?.fontSize == 15 &&
            t.style?.fontWeight == FontWeight.w700 &&
            _looksLikeSymbol(t.data))
          t.data!,
    ];

bool _looksLikeSymbol(String? s) =>
    s != null && !s.startsWith(r'$') && !s.startsWith('₩') && s != '—';

/// The section header totals, top to bottom. Found by their 28px size, because
/// a section holding a single position has a total equal to that row's own
/// value — `find.text` alone cannot tell the two apart.
List<String> _headerTotals(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.style?.fontSize == 28) t.data!,
    ];

void main() {
  const nvda = SheetHolding(
    symbol: 'NVDA',
    currency: 'USD',
    quantity: 20,
    avgPrice: 118.40,
    currentPrice: 190.10,
    baseValue: 2368,
    marketValue: 3802,
    unrealizedGain: 1434,
  );
  const tsla = SheetHolding(
    symbol: 'TSLA',
    currency: 'USD',
    quantity: 15,
    avgPrice: 319.80,
    currentPrice: 261.00,
    baseValue: 4797,
    marketValue: 3915,
    unrealizedGain: -882,
  );
  const amzn = SheetHolding(
    symbol: 'AMZN',
    currency: 'USD',
    quantity: 10,
    baseValue: 1847,
    marketValue: 1890,
    unrealizedGain: 43,
  );
  const samsung = SheetHolding(
    symbol: '삼성전자',
    currency: 'KRW',
    quantity: 120,
    avgPrice: 68400,
    currentPrice: 74300,
    baseValue: 8208000,
    marketValue: 8916000,
    unrealizedGain: 708000,
  );

  testWidgets('splits into one section per currency, largest first',
      (tester) async {
    await _pumpPage(tester, const [nvda, samsung]);

    expect(find.text('KRW · Market value'), findsOneWidget);
    expect(find.text('USD · Market value'), findsOneWidget);
    // ₩8,916,000 dwarfs $3,802, so the KRW section leads. No FX anywhere: the
    // two totals stay separate and are never combined into one figure.
    expect(_headerTotals(tester), ['₩8,916,000', r'$3,802.00']);
  });

  testWidgets('a section total is the sum of its rows', (tester) async {
    await _pumpPage(tester, const [nvda, tsla]);

    expect(find.text(r'$7,717.00'), findsOneWidget); // 3802 + 3915
    expect(find.text(r'Cost $7,165.00'), findsOneWidget); // 2368 + 4797
    expect(find.text(r'+$552.00'), findsOneWidget); // and the gain agrees
  });

  testWidgets('a row shows its gain in money and in percent', (tester) async {
    await _pumpPage(tester, const [nvda]);

    expect(find.text(r'+$1,434.00'), findsWidgets);
    expect(find.text('+60.6%'), findsWidgets);
    expect(find.text(r'20 sh · avg $118.40 → $190.10'), findsOneWidget);
  });

  testWidgets('a loss renders negative, with a real minus sign',
      (tester) async {
    await _pumpPage(tester, const [tsla]);

    expect(find.text(r'−$882.00'), findsWidgets);
    expect(find.text('−18.4%'), findsWidgets);
  });

  testWidgets('the sort header repeats once per currency section',
      (tester) async {
    await _pumpPage(tester, const [nvda, samsung]);

    expect(find.text('SYMBOL'), findsNWidgets(2));
    expect(find.text('VALUE'), findsNWidgets(2));
    expect(find.text('GAIN'), findsNWidgets(2));
    expect(find.text('GAIN %'), findsNWidgets(2));
  });

  testWidgets('opens on largest-position-first', (tester) async {
    await _pumpPage(tester, const [amzn, nvda, tsla]);

    expect(_rowSymbols(tester), ['TSLA', 'NVDA', 'AMZN']);
    expect(find.text('▼'), findsOneWidget); // on VALUE
  });

  testWidgets('tapping the active column reverses it', (tester) async {
    await _pumpPage(tester, const [amzn, nvda, tsla]);

    await tester.tap(find.text('VALUE'));
    await tester.pumpAndSettle();

    expect(_rowSymbols(tester), ['AMZN', 'NVDA', 'TSLA']);
    expect(find.text('▲'), findsOneWidget);
  });

  testWidgets('tapping another column sorts by it, biggest first',
      (tester) async {
    await _pumpPage(tester, const [amzn, nvda, tsla]);

    await tester.tap(find.text('GAIN %'));
    await tester.pumpAndSettle();

    // NVDA +60.6%, AMZN +2.3%, TSLA −18.4% — a different order from by value.
    expect(_rowSymbols(tester), ['NVDA', 'AMZN', 'TSLA']);
  });

  testWidgets('the symbol column says which way the alphabet runs',
      (tester) async {
    await _pumpPage(tester, const [amzn, nvda, tsla]);

    await tester.tap(find.text('SYMBOL'));
    await tester.pumpAndSettle();

    expect(_rowSymbols(tester), ['AMZN', 'NVDA', 'TSLA']);
    expect(find.text('A–Z'), findsOneWidget);
    expect(find.text('▼'), findsNothing);

    await tester.tap(find.text('SYMBOL'));
    await tester.pumpAndSettle();

    expect(_rowSymbols(tester), ['TSLA', 'NVDA', 'AMZN']);
    expect(find.text('Z–A'), findsOneWidget);
  });

  testWidgets('one sort drives every section at once', (tester) async {
    await _pumpPage(tester, const [nvda, tsla, samsung]);

    await tester.tap(find.text('SYMBOL').first);
    await tester.pumpAndSettle();

    // Both headers moved, not just the one that was tapped.
    expect(find.text('A–Z'), findsNWidgets(2));
  });

  testWidgets('a blank market value shows a dash and sorts last',
      (tester) async {
    const voo = SheetHolding(symbol: 'VOO', currency: 'USD', quantity: 6);
    await _pumpPage(tester, const [voo, nvda]);

    expect(find.text('—'), findsWidgets);
    expect(find.text(r'$0.00'), findsNothing);
    expect(_rowSymbols(tester), ['NVDA', 'VOO']);

    // Reversing must not float it to the top — a blank row is never the answer
    // to "show me the smallest position".
    await tester.tap(find.text('VALUE'));
    await tester.pumpAndSettle();
    expect(_rowSymbols(tester), ['NVDA', 'VOO']);
  });

  testWidgets('a blank market value is left out of the section total',
      (tester) async {
    const voo = SheetHolding(
      symbol: 'VOO',
      currency: 'USD',
      quantity: 6,
      baseValue: 2809.20,
    );
    await _pumpPage(tester, const [voo, nvda]);

    // NVDA alone, not NVDA + VOO's cost basis.
    expect(_headerTotals(tester), [r'$3,802.00']);
    expect(find.text(r'Cost $2,368.00'), findsOneWidget);
  });

  testWidgets('no positions at all shows the empty notice', (tester) async {
    await _pumpPage(tester, const []);

    expect(find.text('No positions in the sheet'), findsOneWidget);
  });

  testWidgets('carries the shared updated-at label, fed by its own provider',
      (tester) async {
    await _pumpPage(tester, const [nvda]);

    // skipOffstage: false because a null time makes the label render
    // SizedBox.shrink(), which the default finder skips. A non-null time
    // cannot be pumped — the label's one-minute ticker never settles — so the
    // value itself is covered at the provider level.
    final label = find.byType(UpdatedAtLabel, skipOffstage: false);
    expect(label, findsOneWidget);
    expect(tester.widget<UpdatedAtLabel>(label).updatedAt, isNull);
  });
}
