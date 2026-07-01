import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/dashboard_summary_model.dart';

void main() {
  // A trimmed grid that preserves the real column indices from the live
  // `DashboardDB1` tab, so label-anchoring and the +1/+2 currency offsets are
  // exercised exactly as in production.
  List<List<dynamic>> grid() => [
        // 0     1        2   3                       4            5   6              7           8             9   10        11          12
        ['', '', '', '', '', '', '', '', '', '', '', '', ''],
        ['환율', 1551.425, '', '자산 현황', '', '', '', '', '', '', '', '', ''],
        ['', '', '', '', '', '', '', '', '', '', '', '', ''],
        ['', '', '', '', '', '', '', 'in USD', 'in KRW', '', '', 'in USD', 'in KRW'],
        ['Date', 'Close', '', '보유 USD 현금', 16568.52, '', '총 보유 현금', 98680.11, 153094790.141, '', '총 자산', 176493.15, 273815879.95],
        ['2026-01-02T14:58:00.000Z', 1441.47, '', '보유 KRW 현금', 127389974, '', '', '', '', '', '', '', ''],
        ['2026-01-03T14:58:00.000Z', 1441.07, '', '', '', '', '', '', '', '', '', '', ''],
        ['2026-01-04T14:58:00.000Z', 1440.48, '', '', '', '', '', '', '', '', '', '', ''],
        ['2026-01-05T14:58:00.000Z', 1445.56, '', '보유 미국 주식', 40213.98, '', '총 보유 주식 ', 77813.04, 120721089.81, '', '', '', ''],
        ['2026-01-06T14:58:00.000Z', 1444.96, '', '보유 한국 주식', 58332110, '', '', '', '', '', '', '', ''],
        // A cell the sheet serialises as a bogus 1904 date — must be skipped.
        ['2026-01-07T14:58:00.000Z', '1904-01-03T13:51:20.000Z', '', '', '', '', '', '', '', '', '', '', ''],
        ['2026-01-08T14:58:00.000Z', 1450.08, '', 'USD 투자 금액', 33916.5, '', '', '', '', '', '', '', ''],
        ['2026-01-09T14:58:00.000Z', 1456.33, '', 'KRW 투자 금액', 41218353.28, '', '', '', '', '', '', '', ''],
        ['2026-01-10T14:58:00.000Z', 1456.33, '', '총 투자 금액 (in USD)', 60484.56, '', '', '', '', '', '', '', ''],
        ['2026-01-11T14:58:00.000Z', 1455.24, '', '총 투자 금액 (in KRW)', 93837257.88, '', '', '', '', '', '', '', ''],
        ['2026-01-12T14:58:00.000Z', 1453.10, '', '총 수익률', 0.2865, '', '', '', '', '', '', '', ''],
      ];

  test('fromGrid reads single-value KPIs by label anchor', () {
    final d = DashboardSummaryModel.fromGrid(grid());

    expect(d.exchangeRate, 1551.425);
    expect(d.usdCash, 16568.52);
    expect(d.krwCash, 127389974);
    expect(d.usStocksUsd, 40213.98);
    expect(d.krStocksKrw, 58332110);
    expect(d.usdInvested, 33916.5);
    expect(d.krwInvested, 41218353.28);
    expect(d.returnRate, 0.2865);
  });

  test('fromGrid reads dual-currency totals at +1 (USD) and +2 (KRW)', () {
    final d = DashboardSummaryModel.fromGrid(grid());

    expect(d.totalCashUsd, 98680.11);
    expect(d.totalCashKrw, 153094790.141);
    // Anchored on a label with a trailing space ("총 보유 주식 ").
    expect(d.totalStocksUsd, 77813.04);
    expect(d.totalStocksKrw, 120721089.81);
    expect(d.totalAssetsUsd, 176493.15);
    expect(d.totalAssetsKrw, 273815879.95);
    expect(d.totalInvestedUsd, 60484.56);
    expect(d.totalInvestedKrw, 93837257.88);
  });

  test('fromGrid parses FX history and skips the bogus 1904 cell', () {
    final d = DashboardSummaryModel.fromGrid(grid());

    // 10 numeric Close cells; the 1904 string row is dropped.
    expect(d.fxHistory.length, 10);
    expect(d.fxHistory.first.rate, 1441.47);
    expect(d.fxHistory.first.date, DateTime.parse('2026-01-02T14:58:00.000Z'));
    expect(d.fxHistory.last.rate, 1453.10);
    expect(d.fxHistory.every((p) => p.rate > 1000), isTrue);
  });

  test('fromGrid tolerates missing labels by yielding zero', () {
    final d = DashboardSummaryModel.fromGrid([
      ['nothing', 'useful', 'here'],
    ]);

    expect(d.exchangeRate, 0);
    expect(d.totalAssetsKrw, 0);
    expect(d.fxHistory, isEmpty);
  });
}
