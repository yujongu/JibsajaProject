import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/sheet_holding_model.dart';

/// The live layout: `Name` is column A, `Symbol` starts at B and `Currency`
/// ends at J.
List<List<dynamic>> _liveGrid() => [
      ['Name', 'Symbol', 'Quantity', 'Avg Price', 'Current Price', 'Base Value',
        'Market Value', 'Unrealized Gain', 'Percentage', 'Currency'],
      ['NVIDIA', 'NVDA', 20, 118.40, 190.10, 2368.0, 3802.0, 1434.0, 0.6056, 'USD'],
      ['삼성전자', '005930', 120, 68400, 74300, 8208000, 8916000, 708000, 0.0863, 'KRW'],
    ];

void main() {
  group('SheetHoldingModel.fromGrid', () {
    test('maps the live layout, including the Name column', () {
      final holdings = SheetHoldingModel.fromGrid(_liveGrid())!;

      expect(holdings.length, 2);
      final nvda = holdings.first;
      expect(nvda.symbol, 'NVDA');
      expect(nvda.name, 'NVIDIA');
      expect(nvda.quantity, 20);
      expect(nvda.avgPrice, 118.40);
      expect(nvda.currentPrice, 190.10);
      expect(nvda.baseValue, 2368.0);
      expect(nvda.marketValue, 3802.0);
      expect(nvda.unrealizedGain, 1434.0);
      expect(nvda.currency, 'USD');
      expect(holdings.last.symbol, '005930');
      expect(holdings.last.name, '삼성전자');
      expect(holdings.last.currency, 'KRW');
    });

    test('a blank Name cell yields null, not an empty string', () {
      final grid = [
        ['Name', 'Symbol', 'Market Value'],
        ['', 'VOO', 3802.0],
      ];

      expect(SheetHoldingModel.fromGrid(grid)!.single.name, isNull);
    });

    test('missing Name header yields null name', () {
      final grid = [
        ['Symbol', 'Market Value'],
        ['VOO', 3802.0],
      ];

      expect(SheetHoldingModel.fromGrid(grid)!.single.name, isNull);
    });

    test('the derived percentage matches the sheet\'s own Percentage cell', () {
      // The Percentage column is read by nobody; this pins that deriving it
      // gives the same answer, which is the whole reason for not reading it.
      final nvda = SheetHoldingModel.fromGrid(_liveGrid())!.first;
      expect(nvda.returnFraction, closeTo(0.6056, 0.0001));
    });

    test('anchors on the header text, not on fixed rows or columns', () {
      final shifted = [
        ['My holdings', '', '', ''],
        [],
        ['note', 'Currency', 'Market Value', 'Symbol'],
        ['x', 'USD', 3802.0, 'NVDA'],
      ];

      final holdings = SheetHoldingModel.fromGrid(shifted)!;
      expect(holdings.single.symbol, 'NVDA');
      expect(holdings.single.currency, 'USD');
      expect(holdings.single.marketValue, 3802.0);
    });

    test('returns null when the Symbol header is missing', () {
      final noHeader = [
        ['Ticker', 'Quantity', 'Market Value'],
        ['NVDA', 20, 3802.0],
      ];
      expect(SheetHoldingModel.fromGrid(noHeader), isNull);
    });

    test('a blank cell is null, not zero', () {
      final grid = [
        ['Symbol', 'Quantity', 'Market Value', 'Unrealized Gain', 'Currency'],
        ['VOO', 6, '', '', 'USD'],
      ];

      final voo = SheetHoldingModel.fromGrid(grid)!.single;
      expect(voo.quantity, 6);
      expect(voo.marketValue, isNull);
      expect(voo.unrealizedGain, isNull);
      expect(voo.isValued, isFalse);
    });

    test('missing optional headers still yield positions', () {
      final grid = [
        ['Symbol'],
        ['NVDA'],
        ['TSLA'],
      ];

      final holdings = SheetHoldingModel.fromGrid(grid)!;
      expect(holdings.map((h) => h.symbol), ['NVDA', 'TSLA']);
      expect(holdings.first.currency, '');
      expect(holdings.first.marketValue, isNull);
    });

    test('a value stored as text is still parsed', () {
      final grid = [
        ['Symbol', 'Market Value', 'Unrealized Gain', 'Currency'],
        ['NVDA', r'$3,802.00', '-882.50', 'usd'],
      ];

      final nvda = SheetHoldingModel.fromGrid(grid)!.single;
      expect(nvda.marketValue, 3802.0);
      expect(nvda.unrealizedGain, -882.50);
      // Currency is upper-cased on the way in.
      expect(nvda.currency, 'USD');
    });

    test('ragged rows do not throw', () {
      final grid = [
        ['Symbol', 'Quantity', 'Market Value', 'Currency'],
        ['NVDA'], // row ends before the other columns
        ['TSLA', 15],
      ];

      final holdings = SheetHoldingModel.fromGrid(grid)!;
      expect(holdings.length, 2);
      expect(holdings.first.marketValue, isNull);
      expect(holdings.last.quantity, 15);
    });

    test('blank symbol rows are skipped', () {
      final grid = [
        ['Symbol', 'Market Value'],
        ['NVDA', 3802.0],
        ['', 999.0],
        ['   ', 999.0],
        ['TSLA', 3915.0],
      ];

      expect(SheetHoldingModel.fromGrid(grid)!.map((h) => h.symbol),
          ['NVDA', 'TSLA']);
    });

    test('an empty grid yields no positions rather than null', () {
      // Null means "wrong tab"; an empty list means "the tab is empty". Only
      // a grid with no header at all is the former.
      expect(SheetHoldingModel.fromGrid([]), isNull);
      expect(SheetHoldingModel.fromGrid([
        ['Symbol', 'Market Value']
      ]), isEmpty);
    });
  });
}
