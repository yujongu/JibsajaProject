# HANDOVER

## Current Milestone
**Backend is LIVE + viewer reads real data — complete.** The Google Apps Script web app is deployed
and `AppConfig.sheetsWebAppUrl` is set (gitignored config). Verified the endpoint returns real rows.

**Schema alignment fix:** the live sheet returns CAPITALIZED JSON keys (`Date`, `Account`, `Type`,
`Category`, `Description`, `Symbol`, `Quantity`, `Price`, `Amount`) and the ticker column is named
**`Symbol`**, not `ticker`. `SheetTransactionModel.fromJson` now builds a lowercased key index
(`_lowerKeyIndex`, once per row) and reads every field case-insensitively; ticker resolves as
`_emptyToNull(lower['symbol']) ?? _emptyToNull(lower['ticker'])` (canonical `Symbol`, empty/absent
falls through to legacy `ticker`). POST/append is unchanged (position-based). `docs/data/sheets.md`
updated to the real schema. The Apps Script source is checked in at `docs/apps_script/Code.gs`.
Tests: 9/9 pass (incl. mixed-case, empty-Symbol fallback, Symbol-precedence cases).

### Previous milestone — Transactions viewer overview + month grouping
Added an all-time summary header
(Total spending, Net invested, Spending-by-category bars) above the list, and grouped the list into
month sections ("June 2026"), newest month/row first. `flutter analyze` is clean (0 issues).
Release APK built (`build/app/outputs/flutter-apk/app-release.apk`, ~49 MB).

Built via the orchestrator pipeline (Flutter dev → clean-code review → project-lead adjudication
→ dev applies accepted fixes). Lead-accepted fixes applied this cycle:
1. **Symbol-less money formatting, app-wide.** Dropped the `_summaryCurrency='USD'` assumption and
   `CurrencyFormatter` from the header; promoted `_num` (`#,##0.##`, no symbol) to a top-level fn so
   the header and the tiles format identically. Decision: no currency source of truth exists, so do
   NOT introduce a symbol/currency provider.
2. **Category breakdown capped at Top 4 + "Other".** Fold logic lives in the domain layer
   (`transaction_summary.dart`); UI loop unchanged. Keeps the header short (minimalist).
3. **Sell color uses `AppColors.warning`** instead of a raw `0xFFF59E0B` literal.

### Context & decisions for this change
- **Aggregation is pure-Dart domain logic** in `lib/domain/entities/transaction_summary.dart`:
  immutable `TransactionSummary` / `CategorySpending` / `MonthGroup`, plus a
  `TransactionAggregates` extension on `List<SheetTransaction>` (`.summarize()`, `.groupByMonth()`).
  No Flutter imports. Handles empty data → `TransactionSummary.empty` / `const []`.
- **Exposed via simple derived providers** in `lib/presentation/providers/sheets_providers.dart`:
  `transactionSummaryProvider` and `transactionsByMonthProvider`, both `Provider`s reading
  `transactionsProvider.valueOrNull` (zero/empty while loading or on error).
- **UI** (`sheet_view_page.dart`): the flat data `ListView` is now `_TransactionsList` — a single
  scroll view with `_SummaryHeader` (uses `CurrencyFormatter`, glass/dark-aware styling, bars built
  from plain Containers — no new deps) then `_MonthHeader` + existing unchanged `_TransactionTile`s.
  Loading shimmer, error card, empty state, pull-to-refresh, and Add FAB are untouched.
- **Money is shown symbol-less everywhere** (`#,##0.##` via the top-level `_num`). The sheet stores
  bare numbers with no per-row currency, so no symbol is asserted. If a display currency is ever
  wanted, add ONE app-level currency setting and thread it through both the header and the tiles.

## Previous Milestone
**Structural pivot — complete.** The app was gutted from a full Firebase/Firestore finance
app (auth, accounts, holdings, cards, dashboard, live price & FX feeds) down to a **Google
Sheets thin client** with exactly two features:
1. **View** transactions read from the sheet (`SheetViewPage`).
2. **Add a row** of type Purchase / Buy / Sell (`AddTransactionSheet`).

All Firebase is removed. `flutter analyze` is clean and `flutter test` passes (5 tests).

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
- **Reused UI.** Theme (`app_colors`/`app_theme`), glass widgets, `form_sheet_widgets`,
  `gradient_scaffold` (`FeatureScaffold`), `currency_formatter`, and the category chips
  (`transaction_category` + `transaction_category_ui`, trimmed to expense categories).
- **Dependencies stripped.** Removed firebase_*, cloud_firestore, fake_cloud_firestore, fl_chart,
  go_router, hive_flutter, and all codegen deps (no `part` files existed). Android: removed the
  `com.google.gms.google-services` plugin + `google-services.json`; added INTERNET permission to
  the main manifest (was debug-only).

## The 'Gravel'
- **`SheetTransactionModel.columns` is informational only.** Both `toRows` (POST) and `fromJson`
  (GET) bypass it — POST writes positions directly, GET reads keys case-insensitively. It survives
  as a length/order reference for tests. Wiring `toRows` from it was considered and REJECTED (churn
  on the pre-existing POST path + Buy/Sell placeholder). Revisit when real trade-row logic lands.
- **`currency_formatter.dart` is now fully unused** after the symbol-less switch (no code references;
  only mentioned in this file). Left in place per lead decision. Delete it if it stays unused.
- **Deferred review findings (lead chose not to fix this cycle):**
  - `transactionSummaryProvider` / `transactionsByMonthProvider` use `.valueOrNull ?? const []`,
    silently yielding zero/empty on loading & error. Safe only because they're read inside the
    `data` branch of `transactionsProvider.when`. Fix the misleading doc-comment (or convert to
    `AsyncValue`) if ever consumed outside that branch.
  - Month-key formula `year*100+month` is duplicated in 3 spots in `transaction_summary.dart`
    (build, `MonthGroup.sortKey`, inverse). Centralize into one helper next time the file is edited.
- **Buy/Sell row composition is a PLACEHOLDER.** `SheetTransactionModel._tradeRowsPlaceholder`
  emits a single straightforward trade row. The real logic (e.g. companion cash-transfer leg) is
  to be wired up later, per the user. `toRows()` for Purchase is the finished worked example.
- **`app_config.dart` has empty values.** Until `sheetsWebAppUrl` is filled in, the viewer shows a
  "not configured" message and adding a row fails gracefully.
- **Apps Script GET endpoint must be implemented** on the user's side to return the documented JSON
  (the previous script was write-only).

## Next Immediate Step
Fill in `lib/core/config/app_config.dart` with the real `sheetsWebAppUrl`, then implement the
Apps Script `doGet` to return `{rows:[...]}` as described in `docs/data/sheets.md`. After that,
replace the Buy/Sell placeholder in `lib/data/models/sheet_transaction_model.dart`.
