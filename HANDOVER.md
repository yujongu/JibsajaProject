# HANDOVER

## Current Milestone
**Dashboard reliability + app icon (2026-07-02).** Fixed the Dashboard page's
"connection abort" crash and applied the new launcher icon. Analyzer clean,
13/13 tests pass, release APK built (50.0 MB). Both changes committed on `main`
(not pushed).

### What shipped this session (2026-07-02)
- **Fixed `ClientException: software caused connection abort` on the Dashboard
  page.** Root cause diagnosed via curl: the `DashboardDB1` read consistently
  takes **~10–13s** (live formulas recalculate on read; the JSON is only 13KB, so
  it is latency, not size) vs ~2s for Transactions. That sat right at the old
  **15s** HTTP timeout, so on-device the socket was torn down mid-response.
  - Fix in `sheets_repository_impl.dart`: `_timeout` raised **15s → 30s**; added a
    `_get()` helper that retries a transient transport failure **once** on a fresh
    client for the idempotent GETs. **POST is deliberately not retried** (never
    duplicate a row append). Injected test clients are reused as-is, never retried.
  - Commit `05d92ce`.
- **New app launcher icon** (asset-tracker trend-line). Wired
  `flutter_launcher_icons: ^0.14.3` into `pubspec.yaml`; source PNGs live in
  `assets/icon/` (`icon.png` + adaptive `icon_background.png`/`icon_foreground.png`).
  Generated Android adaptive icons (all densities, foreground inset 16%) and the
  full iOS appiconset. Regenerate with `dart run flutter_launcher_icons`. The
  user's original `Asset tracker app icon/` folder was applied then deleted.
  Commit `bf7f079`.

### Previously shipped (2026-07-01) — Dashboard page
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
- **The 30s timeout is a mitigation, not a cure.** The real problem is the ~10–13s
  server-side `DashboardDB1` read. If a durable fix is wanted, speed up that read
  (it is slow because the tab's formulas recalc on every `getDataRange().getValues()`
  in `Code.gs` `readGrid`) — e.g. cache/snapshot the KPIs to static values, or bound
  the read range. Until then the Dashboard will always take ~10s+ to load and the
  single retry can push worst-case wait toward ~60s before it errors.
- **APK built this session but NOT verified on-device.** Output at
  `build/app/outputs/flutter-apk/app-release.apk` (50.0 MB). The Dashboard fix and
  new icon still need a real-device sanity check (does the Dashboard now load, does
  the launcher icon look right).
- **Adaptive icon foreground may render small.** `icon_foreground.png`'s artwork
  sits small/centered on its 1024² canvas, and Android insets it a further 16% +
  masks corners. The full `icon.png` looks fine; if the home-screen icon feels tiny,
  enlarge the foreground artwork and re-run `dart run flutter_launcher_icons`.
- **Live Dashboard render still unverified.** `fromGrid` is unit-tested against a
  slice of the real grid, and the raw endpoint was fetched successfully via curl,
  but the page has not been run on-device against live data yet.
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
1. **Install the freshly built APK** (`flutter install` or
   `adb install -r build/app/outputs/flutter-apk/app-release.apk`) and open the
   **Dashboard** tab: confirm it now loads (no connection-abort) and that the four
   KPI cards, net-worth hero, totals, investment card, and USD/KRW sparkline all
   render with sensible numbers. Also check the new launcher icon.
2. If the Dashboard still fails or feels too slow, tackle the server-side
   `DashboardDB1` read time (see Gravel) rather than nudging the client timeout again.
3. If any label doesn't resolve (shows 0), check the exact cell text in
   `DashboardDB1` vs the anchors in `dashboard_summary_model.dart` (watch for
   trailing spaces / full-width chars).
4. Optional follow-ups: `git push` the two new commits; include crypto + card debt
   via the `Accounts` tab; delete unused `currency_formatter.dart`.
