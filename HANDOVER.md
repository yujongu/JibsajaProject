# HANDOVER

## Current Milestone
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
