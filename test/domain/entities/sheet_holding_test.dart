import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_holding.dart';

SheetHolding _h(
  String symbol, {
  String currency = 'USD',
  double? base,
  double? market,
  double? gain,
  double? qty,
}) =>
    SheetHolding(
      symbol: symbol,
      currency: currency,
      quantity: qty,
      baseValue: base,
      marketValue: market,
      unrealizedGain: gain,
    );

/// A position whose gain is consistent with its cost and value.
SheetHolding _pos(String symbol, double base, double market,
        {String currency = 'USD'}) =>
    _h(symbol,
        currency: currency,
        base: base,
        market: market,
        gain: market - base);

const _byValue = (field: HoldingSort.value, dir: SortDir.desc);

List<String> _symbols(CurrencyHoldings s) =>
    [for (final h in s.holdings) h.symbol];

void main() {
  group('SheetHolding.returnFraction', () {
    test('is the gain over the cost basis', () {
      expect(_h('NVDA', base: 2368, gain: 1434).returnFraction,
          closeTo(0.60557, 0.00001));
    });

    test('is negative for a losing position', () {
      expect(_h('TSLA', base: 4797, gain: -882).returnFraction,
          closeTo(-0.18386, 0.00001));
    });

    test('is null when the cost basis is zero, not infinity', () {
      expect(_h('FREE', base: 0, gain: 120).returnFraction, isNull);
    });

    test('is null when either input is missing', () {
      expect(_h('A', base: 100).returnFraction, isNull);
      expect(_h('B', gain: 10).returnFraction, isNull);
      expect(_h('C').returnFraction, isNull);
    });
  });

  group('SheetHolding.isValued', () {
    test('needs both a market value and a cost basis', () {
      expect(_h('A', base: 1, market: 2).isValued, isTrue);
      expect(_h('B', market: 2).isValued, isFalse);
      expect(_h('C', base: 1).isValued, isFalse);
    });

    test('a zero-value position is still valued — 0 is a real number', () {
      expect(_h('SOLD', base: 0, market: 0).isValued, isTrue);
    });
  });

  group('HoldingSort.naturalDir', () {
    test('names start A→Z, numbers start biggest-first', () {
      expect(HoldingSort.symbol.naturalDir, SortDir.asc);
      expect(HoldingSort.value.naturalDir, SortDir.desc);
      expect(HoldingSort.gain.naturalDir, SortDir.desc);
      expect(HoldingSort.gainPercent.naturalDir, SortDir.desc);
    });
  });

  group('groupByCurrency', () {
    test('splits by currency and totals each section independently', () {
      final sections = [
        _pos('NVDA', 2368, 3802),
        _pos('삼성전자', 8208000, 8916000, currency: 'KRW'),
        _pos('TSLA', 4797, 3915),
      ].groupByCurrency(_byValue);

      expect(sections.length, 2);
      final krw = sections.firstWhere((s) => s.currency == 'KRW');
      final usd = sections.firstWhere((s) => s.currency == 'USD');

      expect(usd.marketValue, 3802 + 3915);
      expect(usd.baseValue, 2368 + 4797);
      expect(usd.unrealizedGain, closeTo(552, 0.0001));
      expect(krw.marketValue, 8916000);
      expect(krw.unrealizedGain, 708000);
    });

    test('the largest section by market value leads', () {
      final sections = [
        _pos('NVDA', 2368, 3802),
        _pos('삼성전자', 8208000, 8916000, currency: 'KRW'),
      ].groupByCurrency(_byValue);

      expect(sections.first.currency, 'KRW');
    });

    test('currency matching ignores case and whitespace', () {
      final sections = [
        _pos('NVDA', 100, 200),
        _pos('GOOG', 100, 200, currency: ' usd '),
      ].groupByCurrency(_byValue);

      expect(sections.length, 1);
      expect(sections.single.currency, 'USD');
      expect(sections.single.holdings.length, 2);
    });

    test('a blank currency becomes an unlabelled section, always last', () {
      final sections = [
        _pos('MYSTERY', 1, 999999, currency: ''),
        _pos('NVDA', 2368, 3802),
      ].groupByCurrency(_byValue);

      // Despite being far larger, the unlabelled bucket does not lead — it is
      // "the sheet didn't say", not a currency.
      expect(sections.map((s) => s.currency).toList(), ['USD', null]);
    });

    test('rows missing a value are listed but excluded from the totals', () {
      final section = [
        _pos('NVDA', 2368, 3802),
        _h('VOO', base: 2809.2), // no market value
      ].groupByCurrency(_byValue).single;

      expect(section.holdings.length, 2);
      expect(section.marketValue, 3802);
      expect(section.baseValue, 2368);
      // market − cost == gain still holds for what the header shows.
      expect(section.unrealizedGain, 3802 - 2368);
    });

    test('an empty list yields no sections', () {
      expect(<SheetHolding>[].groupByCurrency(_byValue), isEmpty);
    });
  });

  group('CurrencyHoldings.share', () {
    test('is the position over the section market value', () {
      final section = [
        _pos('A', 100, 750),
        _pos('B', 100, 250),
      ].groupByCurrency(_byValue).single;

      expect(section.share(section.holdings.first), closeTo(0.75, 0.0001));
      expect(section.share(section.holdings.last), closeTo(0.25, 0.0001));
    });

    test('is zero for a row the totals exclude', () {
      final section = [
        _pos('A', 100, 750),
        _h('B', base: 100),
      ].groupByCurrency(_byValue).single;

      expect(section.share(section.holdings.last), 0);
    });

    test('is zero rather than NaN when the section is worth nothing', () {
      final section =
          [_pos('SOLD', 0, 0)].groupByCurrency(_byValue).single;

      expect(section.share(section.holdings.single), 0);
      expect(section.returnFraction, isNull);
    });
  });

  group('ordering', () {
    final rows = [
      _pos('MSFT', 3001.60, 3360.00), //  +358.40  +11.9%
      _pos('NVDA', 2368.00, 3802.00), // +1434.00  +60.6%
      _pos('TSLA', 4797.00, 3915.00), //  −882.00  −18.4%
      _pos('AMZN', 1847.00, 1890.00), //   +43.00   +2.3%
    ];

    List<String> order(HoldingSort field, SortDir dir) =>
        _symbols(rows.groupByCurrency((field: field, dir: dir)).single);

    test('by value, biggest first and reversed', () {
      expect(order(HoldingSort.value, SortDir.desc),
          ['TSLA', 'NVDA', 'MSFT', 'AMZN']);
      expect(order(HoldingSort.value, SortDir.asc),
          ['AMZN', 'MSFT', 'NVDA', 'TSLA']);
    });

    test('by gain — the biggest earner, not the best performer', () {
      expect(order(HoldingSort.gain, SortDir.desc),
          ['NVDA', 'MSFT', 'AMZN', 'TSLA']);
    });

    test('by gain percent — a different answer from by gain', () {
      expect(order(HoldingSort.gainPercent, SortDir.desc),
          ['NVDA', 'MSFT', 'AMZN', 'TSLA']);
      expect(order(HoldingSort.gainPercent, SortDir.asc),
          ['TSLA', 'AMZN', 'MSFT', 'NVDA']);
    });

    test('by symbol, A–Z and Z–A', () {
      expect(order(HoldingSort.symbol, SortDir.asc),
          ['AMZN', 'MSFT', 'NVDA', 'TSLA']);
      expect(order(HoldingSort.symbol, SortDir.desc),
          ['TSLA', 'NVDA', 'MSFT', 'AMZN']);
    });

    test('⭐ rows with no value stay last in BOTH directions', () {
      final withBlank = [
        _pos('NVDA', 2368, 3802),
        _h('VOO'), // nothing at all
        _pos('AMZN', 1847, 1890),
      ];

      for (final field in [
        HoldingSort.value,
        HoldingSort.gain,
        HoldingSort.gainPercent,
      ]) {
        for (final dir in SortDir.values) {
          final got =
              _symbols(withBlank.groupByCurrency((field: field, dir: dir)).single);
          expect(got.last, 'VOO', reason: 'field=$field dir=$dir');
        }
      }
    });

    test('equal values break the tie A–Z in both directions', () {
      final tied = [
        _pos('ZZZ', 100, 500),
        _pos('AAA', 100, 500),
      ];

      expect(_symbols(tied.groupByCurrency(_byValue).single), ['AAA', 'ZZZ']);
      expect(
        _symbols(tied
            .groupByCurrency((field: HoldingSort.value, dir: SortDir.asc))
            .single),
        ['AAA', 'ZZZ'],
      );
    });

    test('a zero-cost position sorts last by gain percent, not first', () {
      final withFreebie = [
        _pos('NVDA', 2368, 3802),
        _h('FREE', base: 0, market: 900, gain: 900), // returnFraction is null
      ];

      expect(
        _symbols(withFreebie
            .groupByCurrency(
                (field: HoldingSort.gainPercent, dir: SortDir.desc))
            .single),
        ['NVDA', 'FREE'],
      );
    });
  });
}
