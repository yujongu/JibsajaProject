# HANDOVER

## Current Milestone
**Dashboard page — implemented (2026-07-01).** Second tab showing a read-only
portfolio snapshot sourced entirely from the sheet's `DashboardDB1` tab. Analyzer
clean, 13/13 tests pass. APK build is done by the user (`flutter build apk --release`).

### What shipped this session
- **New backend wired up.** `AppConfig.sheetsWebAppUrl` updated to the new `/exec`
  URL and `sheetsApiKey` set to `jibsaja-secret-2024-xk9m` (matches `API_KEY` in
  `Code.gs`). The old URL was stale.
- **`DashboardDB1` is the data source — nothing is computed client-side.** Every
  KPI (cash/stocks/net worth/invested/return + a daily USD/KRW series) is
  pre-authored by the spreadsheet, so the app always matches the sheet. This
  replaced the earlier plan to derive KPIs from Transactions/Accounts (that
  approach disagreed with the sheet — e.g. Accounts-summed US stocks ≈ $32.5k vs
  the sheet's $40.2k).
- **Files added:**
  - `domain/entities/dashboard_summary.dart` — `DashboardSummary` + `FxPoint`.
  - `data/models/dashboard_summary_model.dart` — `fromGrid`, label-anchored.
  - `presentation/pages/dashboard/dashboard_page.dart` — the page.
  - `presentation/pages/dashboard/fx_sparkline.dart` — CustomPaint sparkline (no
    charting dep — fl_chart stays removed).
  - `test/data/models/dashboard_summary_model_test.dart` — 4 tests.
- **Files changed:** `i_sheets_repository.dart` (+`fetchDashboard()`),
  `sheets_repository_impl.dart` (impl via `?sheet=DashboardDB1`),
  `sheets_providers.dart` (+`dashboardProvider`), `main.dart` (2-tab `HomeShell`
  with a custom bottom nav + `IndexedStack`), `app_colors.dart`
  (+`secondaryFallback` cyan USD accent), `docs/data/sheets.md`.

## Context & Logic Decisions
- **Parse by label-anchor, not fixed cells.** `DashboardSummaryModel.fromGrid`
  finds each Korean label cell and reads the cell(s) to its right (dual-currency
  totals: USD at +1, KRW at +2). Survives row/column inserts in the sheet.
- **`총 자산` = cash + stocks only.** Confirmed by the sheet's own arithmetic.
  Crypto (업비트/빗썸) and card debt are in the `Accounts` tab, NOT in
  `DashboardDB1` totals. User accepted DashboardDB1's definition of net worth.
  To extend later: read `?sheet=Accounts` and sum `Current Balance` by `Type`.
- **FX rate solved.** `환율` at DashboardDB1 lives in the grid; no GOOGLEFINANCE
  cell / fallback constant needed. The `Date`/`Close` columns give the sparkline.
- **Dashboard surfaces endpoint errors.** Unlike `fetchTransactions` (missing
  `rows` → empty list), `fetchDashboard` turns `{"error": ...}` into a `Failure`
  so a bad apiKey shows in the UI instead of a blank dashboard.
- **Nav.** `HomeShell` (StatefulWidget) + `IndexedStack` preserves each tab's
  state. Custom bottom bar because the theme intentionally leaves `NavigationBar`
  transparent (see `app_theme.dart` comment). Still no router.

## The 'Gravel'
- **APK not built by this session** — user builds it (`flutter build apk --release`,
  output `build/app/outputs/flutter-apk/app-release.apk`). Not yet verified on the
  physical device.
- **Live Dashboard render unverified.** `fromGrid` is unit-tested against a slice
  of the real grid, and the raw endpoint was fetched successfully via curl, but
  the page has not been run on-device against live data yet.
- **`currency_formatter.dart` still fully unused.** Dashboard uses its own local
  `_krw`/`_usd`/`_rate` intl helpers (mirrors `sheet_view_page`'s local `_num`).
  Delete `currency_formatter.dart` if it stays unused.
- **One glitch cell in DashboardDB1**: a `Close` cell serialises as a bogus
  `1904-01-03T...` date string. The FX parser skips non-numeric `Close` cells, so
  it's handled — but it means the series can be 1 point short of the row count.
- **Sparkline** draws straight segments (no smoothing) and has no axis labels — a
  deliberate minimal choice. Min/max shown as text in the card header.
- **Buy/Sell row composition is still a PLACEHOLDER** (`_tradeRowsPlaceholder`) —
  unchanged this session, unrelated to the dashboard.

## Next Immediate Step
1. **Build + install the APK** and open the **Dashboard** tab against live data;
   confirm the four KPI cards, net-worth hero, totals, investment card, and the
   USD/KRW sparkline all render with sensible numbers.
2. If any label doesn't resolve (shows 0), check the exact cell text in
   `DashboardDB1` vs the anchors in `dashboard_summary_model.dart` (watch for
   trailing spaces / full-width chars).
3. Optional follow-ups: include crypto + card debt via the `Accounts` tab;
   delete unused `currency_formatter.dart`.
