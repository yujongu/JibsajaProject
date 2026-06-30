# HANDOVER

## Current Milestone
**Dashboard page — scoping complete, implementation not started (2026-07-01).**

The goal is to add a second page to the app showing a summary "Dashboard" view computed from the
Transactions data already fetched — no extra sheet call needed for the computable values.

### What was decided this session

**New Apps Script `/exec` URL:**
`https://script.google.com/macros/s/AKfycbz2BnfyQnx9QpCIIoSxVq7P0BN3YzJFI1khOS8K5L_isymeTSYMabGH7z3tlAWL_2iIXA/exec`
Update `AppConfig.sheetsWebAppUrl` to this URL (the old URL is now stale).

**`Code.gs` was updated** to support `?sheet=<name>` which returns the full sheet as a raw 2-D
`grid` array. This is deployed in the new version above. The Transactions endpoint (`rows`) still
works as before on the same URL.

**The ⭐Dashboard sheet KPI cards are Scorecard Chart objects**, not cell values. `getDataRange()`
only returns a 9-column grid with Monthly Report data, Top 10 Spendings, and Category breakdown —
the KPI values (보유 USD 현금, 보유 KRW 현금, 보유 미국 주식, 보유 한국 주식) and asset split
percentages are embedded chart overlays sourced from elsewhere and are NOT accessible via the grid.

**Decision: compute the dashboard from the Transactions data** (already fetched by
`transactionsProvider`) rather than making a second sheet call. The user confirmed this approach.

### What CAN be computed from Transactions

All account names in the transaction data are investment accounts (토스증권, 신한투자, 영웅문).
From Buy/Sell/Purchase transactions we can derive:

| Metric | How |
|---|---|
| Net KRW stocks invested | Sum of Buy amounts − Sell amounts for 국내 accounts |
| Net USD stocks invested | Sum of Buy amounts − Sell amounts for 해외 accounts |
| Total spending (KRW) | Sum of Purchase/Expense amounts |
| Spending by category | Already implemented in `TransactionSummary` |
| Stock vs spending asset split % | stocks / (stocks + spending) |

### What CANNOT be computed from Transactions alone

- 보유 USD/KRW 현금 (cash balances) — no deposit/withdrawal transactions exist in the sheet
- 환율 / Exchange rate — external data, not in the sheet
- Exact asset split matching the Google Sheets dashboard

**Open question for next session:** Is there another sheet tab (e.g. "Holdings", "잔고", "현금")
that stores cash balances? If yes, use `?sheet=<tabname>` to fetch it and augment the dashboard.
If no, build the dashboard with only the computable metrics and label them clearly.

### Sections the user wants on the Dashboard page
1. KPI cards (4 values: USD cash, KRW cash, US stocks, KR stocks)
2. Summary totals + exchange rate
3. Asset split (stocks % vs cash %)

Only items derivable from Transactions can be shown until cash balance data is located.

---

## Context & Logic Decisions

- **Backend = Google Apps Script web app only.** `SheetsRepositoryImpl` does `GET` (read all
  rows as JSON) and `POST` (append rows). Endpoint lives in `lib/core/config/app_config.dart`
  (gitignored; a local empty stub was created so the project compiles — fill in real values).
  Contract documented in `docs/data/sheets.md`.
- **Result type.** `lib/domain/entities/result.dart` (sealed Success/Failure). `fetchTransactions`
  returns `Result`; `transactionsProvider` (a `FutureProvider`) rethrows `Failure` so the UI uses
  `AsyncValue.when` for loading/error/data.
- **Account names derived from the sheet.** `accountNamesProvider` collects distinct Account-column
  values for the add-row dropdown; free-text "+ New account…" is also supported.
- **No router.** Single screen → dropped `go_router`; `main.dart` uses `MaterialApp(home:)`.
  Adding the Dashboard page will require either a `BottomNavigationBar` or a tab bar on the home
  screen — no router is needed, just a `StatefulWidget` with two tabs.
- **Reused UI.** Theme (`app_colors`/`app_theme`), glass widgets, `form_sheet_widgets`,
  `gradient_scaffold` (`FeatureScaffold`), `currency_formatter`, and the category chips
  (`transaction_category` + `transaction_category_ui`, trimmed to expense categories).
- **Dependencies stripped.** Removed firebase_*, cloud_firestore, fake_cloud_firestore, fl_chart,
  go_router, hive_flutter, and all codegen deps (no `part` files existed). Android: removed the
  `com.google.gms.google-services` plugin + `google-services.json`; added INTERNET permission to
  the main manifest (was debug-only).

## The 'Gravel'

- **`AppConfig.sheetsWebAppUrl` must be updated** to the new `/exec` URL above. The old URL
  (`AKfycbz4_GJUenGRnDfkO2cxPkbC4No9kDAcK7AhsAoZOU4wKduGcwSxCSLI8sbdgaqkU2cE8g/exec`) is stale.
- **`SheetTransactionModel.columns` is informational only.** Both `toRows` (POST) and `fromJson`
  (GET) bypass it — POST writes positions directly, GET reads keys case-insensitively. It survives
  as a length/order reference for tests. Wiring `toRows` from it was considered and REJECTED.
- **`currency_formatter.dart` is now fully unused** after the symbol-less switch. Left in place per
  lead decision. Delete it if it stays unused.
- **Buy/Sell row composition is a PLACEHOLDER.** `SheetTransactionModel._tradeRowsPlaceholder`
  emits a single straightforward trade row. The real companion cash-transfer leg logic is deferred.
- **Deployment is version-pinned.** Editing `docs/apps_script/Code.gs` in the Apps Script editor
  does NOT change what `/exec` serves — must Manage deployments → Edit → New version → Deploy.
- **The live `/exec` URL is gitignored** via `app_config.dart`. Only `app_config.template.dart` is
  tracked. Do not paste the real URL/key into tracked files.
- **`transactionSummaryProvider` / `transactionsByMonthProvider`** use `.valueOrNull ?? const []`,
  silently yielding zero/empty on loading & error. Safe only because consumed inside the `data`
  branch of `transactionsProvider.when`.

## Next Immediate Step

1. **Update `AppConfig.sheetsWebAppUrl`** in `lib/core/config/app_config.dart` to the new URL above.
2. **Ask the user** if there is a cash balance sheet tab — this determines whether KPI cards can
   show real cash values or only computed stock/spending values.
3. **If no cash sheet:** build the Dashboard page with computable metrics only:
   - Add a `BottomNavigationBar` to `main.dart` (Transactions tab + Dashboard tab)
   - Add domain logic in `transaction_summary.dart` for stock split (KRW vs USD net invested)
   - Build `lib/presentation/pages/dashboard/dashboard_page.dart` with KPI cards and asset split
4. **If cash sheet exists:** add `fetchDashboard()` to `ISheetsRepository` / `SheetsRepositoryImpl`
   using `?sheet=<tabname>`, parse the grid for the cash balance cells, and feed those into the
   dashboard page alongside the computed stock values.
