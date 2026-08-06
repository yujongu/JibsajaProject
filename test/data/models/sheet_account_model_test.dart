import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/sheet_account_model.dart';
import 'package:jibsaja/domain/entities/sheet_account.dart';

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

  group('SheetAccountModel.fromGrid — Type and Current Balance', () {
    test('reads both from the live column layout', () {
      final accounts = SheetAccountModel.fromGrid([
        [
          'Account Name',
          'Type',
          'Institution',
          'Currency',
          'Include?',
          'Starting Balance',
          'Current Balance',
          'Normal Sign',
        ],
        ['현대카드', 'Credit', '현대', 'KRW', 'Y', 0, -512300, -1],
        ['BoA Checking', 'Bank', 'Bank of America', 'USD', 'Y', 0, 1842.5, 1],
      ]);

      expect(accounts.first.type, 'Credit');
      expect(accounts.first.currentBalance, -512300);
      expect(accounts.last.type, 'Bank');
      expect(accounts.last.currentBalance, 1842.5);
    });

    test('a balance stored as text still parses', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Currency', 'Current Balance'],
        ['BoA', 'USD', '1,234.56'],
        ['현대카드', 'KRW', '-₩512,300'],
      ]);

      expect(accounts.first.currentBalance, 1234.56);
      expect(accounts.last.currentBalance, -512300);
    });

    test('a blank balance reads as null, not zero', () {
      // 0 is a real balance (a paid-off card); "the sheet didn't say" is not.
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Currency', 'Current Balance'],
        ['Mystery', 'KRW', ''],
        ['Paid off', 'KRW', 0],
      ]);

      expect(accounts.first.currentBalance, isNull);
      expect(accounts.last.currentBalance, 0);
    });

    test('missing Type/Current Balance headers still yield accounts', () {
      // These two columns are OPTIONAL, unlike Account Name and Currency: the
      // Transactions page's currency labels predate them, so a tab without them
      // must degrade to blank type / null balance, never to an empty list.
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Currency'],
        ['BoA', 'USD'],
      ]);

      expect(accounts.single.currency, 'USD');
      expect(accounts.single.type, '');
      expect(accounts.single.currentBalance, isNull);
    });

    test('tolerates ragged rows shorter than the balance column', () {
      final accounts = SheetAccountModel.fromGrid([
        ['Account Name', 'Type', 'Currency', 'Current Balance'],
        ['BoA', 'Bank'],
      ]);

      expect(accounts.single.type, 'Bank');
      expect(accounts.single.currentBalance, isNull);
    });
  });

  group('SheetAccountList.ofType', () {
    const accounts = [
      SheetAccount(name: '현대카드', currency: 'KRW', type: 'Credit'),
      SheetAccount(name: 'BoA', currency: 'USD', type: 'Bank'),
      SheetAccount(name: '토스뱅크', currency: 'KRW', type: ' bank '),
      SheetAccount(name: '토스증권', currency: 'KRW', type: 'Brokerage'),
      SheetAccount(name: 'Nameless type', currency: 'KRW'),
    ];

    test('selects only the requested type', () {
      expect(accounts.ofType('Credit').single.name, '현대카드');
    });

    test('matches case- and whitespace-insensitively', () {
      expect(
        accounts.ofType('Bank').map((a) => a.name),
        ['BoA', '토스뱅크'],
      );
    });

    test('a type nothing matches yields an empty list', () {
      expect(accounts.ofType('Crypto'), isEmpty);
    });
  });
}
