import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/sheet_account_model.dart';

void main() {
  group('SheetAccountModel.fromGrid', () {
    test('reads Account Name and Currency from the live column layout', () {
      final accounts = SheetAccountModel.fromGrid([
        [
          'Account Name',
          'Type',
          'Institution',
          'Currency',
          'Include?',
          'Starting Balance',
        ],
        ['BoA', 'Cash', 'Bank of America', 'USD', 'Y', 100],
        ['토스증권 국내 주식', 'Brokerage', '토스', 'KRW', 'Y', 0],
      ]);

      expect(accounts, hasLength(2));
      expect(accounts.first.name, 'BoA');
      expect(accounts.first.currency, 'USD');
      expect(accounts.last.name, '토스증권 국내 주식');
      expect(accounts.last.currency, 'KRW');
    });

    test('anchors on headers, so an inserted column does not shift the map', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Type', 'Nickname', 'Institution', 'Currency'],
        ['BoA', 'Cash', 'main', 'Bank of America', 'USD'],
      ]);

      expect(accounts.single.currency, 'USD');
    });

    test('trims names and upper-cases the currency code', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Currency'],
        ['  BoA  ', ' usd '],
      ]);

      expect(accounts.single.name, 'BoA');
      expect(accounts.single.currency, 'USD');
    });

    test('a blank Currency cell reads as an empty code, not a guess', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Currency'],
        ['Mystery', ''],
      ]);

      expect(accounts.single.currency, '');
    });

    test('skips rows with no account name', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Currency'],
        ['', 'USD'],
        ['   ', 'KRW'],
        ['BoA', 'USD'],
      ]);

      expect(accounts.single.name, 'BoA');
    });

    test('missing headers degrade to no accounts rather than throwing', () {
      // No 'Account Name' anywhere.
      expect(
        SheetAccountModel.fromGrid([
          ['Name', 'Currency'],
          ['BoA', 'USD'],
        ]),
        isEmpty,
      );
      // Name header present, Currency missing.
      expect(
        SheetAccountModel.fromGrid([
          ['Account Name', 'Type'],
          ['BoA', 'Cash'],
        ]),
        isEmpty,
      );
      expect(SheetAccountModel.fromGrid(const []), isEmpty);
    });

    test('tolerates ragged rows shorter than the currency column', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Type', 'Currency'],
        ['BoA'],
      ]);

      expect(accounts.single.name, 'BoA');
      expect(accounts.single.currency, '');
    });
  });
}
