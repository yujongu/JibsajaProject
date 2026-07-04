# HANDOVER

## Current Milestone
**Startup cache — no more empty loading screen (2026-07-04).** The last
successful transactions + dashboard responses are now persisted on-device
(`shared_preferences`) and rendered instantly on cold start while the live
fetch revalidates in the background (stale-while-revalidate). Analyzer clean,
30/30 tests pass. **This session's changes are uncommitted.**

### What shipped this session (2026-07-04)
- **New**: `lib/data/datasources/sheets_local_cache.dart` — stores the *raw
  JSON response bodies* under `cache.transactions.body.v1` /
  `cache.dashboard.body.v1`.
- **Repository** (`sheets_repository_impl.dart`): parsing extracted into
  `_parseTransactionsBody` / `_parseDashboardBody`, shared by the live fetch
  and the new sync `cachedTransactions()` / `cachedDashboard()` (added to
  `ISheetsRepository`). Cache is written only after a body parses
  successfully; a corrupt/stale cached body reads back as null, never throws.
- **Providers** (`sheets_providers.dart`): `transactionsProvider` and
  `dashboardProvider` are now `StreamProvider`s — yield cached data first (if
  any), then the live result. If the live fetch fails *and* cache was shown,
  the error is swallowed (debugPrint only); with no cache it throws as before
  so the ErrorCard still appears on true first-run failures. New
  `sharedPreferencesProvider`, overridden in `main()` (prefs loaded before
  `runApp` so cache reads are synchronous at first frame).
- **Tests**: `test/data/repositories/sheets_repository_cache_test.dart` —
  cache round-trip, failed-fetch-doesn't-overwrite, corrupt-body → null,
  dashboard error payload not cached.
- **"Could not load data at startup" hardening** (user report, same session).
  User saw the error card on both pages at launch before live data arrived.
  Verified via provider state-sequence tests that cache-present runs never
  emit an error — so the on-device error means **empty cache + failed startup
  fetch**. Three deterministic fixes:
  1. `_get()` now also retries transient HTTP statuses (429/5xx — Apps Script
     rejects concurrent cold-start bursts with these), not just transport
     exceptions. Injected test clients still never retry.
  2. `_cachedThenLive()` (new shared stream loop in `sheets_providers.dart`):
     on a no-cache cold start, a failed fetch is retried once after 2s
     (`_coldStartAttempts`/`_coldStartRetryDelay`) before the error surfaces.
     Cache-present behavior unchanged (failure keeps cache, no retry).
  3. Both pages: while a refetch is in flight after a previous error,
     `async.isLoading` in the error branch shows the loading shimmer instead
     of re-surfacing the stale error card (Riverpod's `skipLoadingOnRefresh`
     otherwise re-shows the previous error during the whole reload).
  New `test/presentation/providers/sheets_providers_test.dart` (scriptable
  fake repo, records AsyncValue sequences; 38 tests total).
- **"Updated Xm ago" freshness caption** (user request, same session): cache
  now also stores a fetch timestamp (`cache.*.at.v1`, epoch ms) written
  alongside each body; exposed via `cachedTransactionsAt()` /
  `cachedDashboardAt()` on the repository, surfaced through
  `transactionsUpdatedAtProvider` / `dashboardUpdatedAtProvider` (they watch
  the data providers, so they re-read the moment live data lands). New shared
  widget `lib/presentation/shared/widgets/updated_at_label.dart` renders a
  tiny centered "Updated just now / 12m ago / 5h ago / Jul 1, 09:05" caption
  at the top of both the Dashboard and Transactions lists; a private
  minute-ticker StreamProvider keeps the relative label aging while the app
  sits open. Hidden until the first-ever successful fetch. 34 tests total now
  (label formatter + timestamp coverage added).

## Previous Milestone
**Buy/Sell two-row trade composition (2026-07-02, session 3).** Replaced the
Buy/Sell placeholder with the real double-entry logic the user specced: every
trade appends TWO rows — a `Transfer` cash leg on the first (cash) account and
the `Buy`/`Sell` trade leg on the second (brokerage) account. Analyzer clean,
17/17 tests pass. Committed as `2a8f223` (with session 2's work in earlier
commits).

### What shipped this session (2026-07-02, session 3)
- **User-confirmed spec** (Sell is the exact mirror of Buy; revised same
  session: **Sell quantity is written NEGATIVE**, so Amount is always plain
  Quantity × Price):
  | Row | Account | Type | Quantity | Amount (Buy) | Amount (Sell) |
  | :-- | :-- | :-- | :-- | :-- | :-- |
  | 1 cash leg | brokerage cash account | `Transfer` | blank | −qty×price | +qty×price |
  | 2 trade leg | brokerage account | `Buy`/`Sell` | Buy +qty, Sell **−qty** | +qty×price | −qty×price |
  Same Date + Description on both rows; both go in ONE POST (all-or-nothing).
- **Domain**: `TransactionType.transfer` added (+ `userSelectable` const —
  Transfer is never user-pickable, only generated). `SheetTransaction` gained
  write-only `secondAccount`. `computedAmount` = amount ?? qty×price (plain
  multiply — the sign lives in the Sell quantity). `summarize()`: netInvested
  = Σ signed trade amounts; Transfer rows excluded from all aggregates.
- **Data**: `_tradeRowsPlaceholder` → `_tradeRows` (composition above; the
  form passes positive qty, the model negates for Sell; falls back to
  `account` if `secondAccount` is null).
- **Form** (`add_transaction_sheet.dart`): second dropdown for trades (each
  with its own "+ New account…" entry) + a caption stating the two rows about
  to be written. Trade labels renamed per user: **'Brokerage cash account'**
  (was Account) and **'Brokerage account'** (was Second account); Purchase
  keeps plain 'Account'. Type toggle iterates `userSelectable`.
- **List** (`sheet_view_page.dart`): Transfer rows render with swap icon,
  cyan `secondaryFallback` color, description-or-'Transfer' title.
- **Expense Amounts are stored NEGATIVE** (user spec, cash-out convention):
  model negates the form's positive input on write; `summarize()` reports
  spending as the positive magnitude (−Σ expense amounts). ⚠️ Any legacy
  expense rows with POSITIVE Amounts would now *subtract* from the spending
  stat — glance at the live sheet if Spending looks low.
- **Purchase finalized (user spec)**: writes ONE row with Type **`Expense`**
  (not `Purchase` — reading stays lenient to both). Category enum replaced
  with the sheet's real 12 values: `Monthly, 교통, 식비, 생필품, 의류, Fun,
  배달음식, Misc., Work, 경조사, 웨딩, 여행` — `sheetValue` is both wire value
  and display label; parsing matches wire value case-insensitively or legacy
  enum name, unknown → `Misc.`. `TransactionCategory.other` → `misc`
  everywhere; model writes `category.sheetValue` (was `.name`); new
  icons/colors per category in `transaction_category_ui.dart`.
- **Ordering + date fixes** (user reported "order seems weird"):
  1. `SheetTransaction.rowIndex` (sheet position) + `newestFirst` comparator —
     Dart's sort is unstable, so same-timestamp rows (same-day entries, trade
     leg pairs) used to shuffle randomly; now they tiebreak by sheet position,
     later rows first. Used in both the repository sort and `groupByMonth`.
  2. `_parseDate` now `.toLocal()`s — Apps Script serializes date cells as UTC
     (`2026-02-01` KST → `"2026-01-31T15:00:00.000Z"`), which shifted displayed
     dates back a day and could group rows under the wrong month header.
- **Success toast on save** (user request): after a successful append the form
  shows "Sheet updated — Purchase added" / "… Buy added (2 rows)" / "… Sell
  added (2 rows)" via the root ScaffoldMessenger (survives the sheet pop),
  then closes.
- **Summary header is now CURRENT-MONTH, not all-time** (user request):
  "This month · July 2026" caption, Spending + Net invested stats and the
  category breakdown all come from `currentMonthSummaryProvider`
  (replaces `transactionSummaryProvider`), which filters via the new domain
  helper `TransactionAggregates.inMonth(year, month)` before `summarize()`.
  New domain test file `test/domain/entities/transaction_summary_test.dart`
  (19 tests total now).
- **Docs**: `docs/data/sheets.md` row-types + Quantity/Amount columns now
  document the signed two-row contract.

### Previously shipped (2026-07-02, session 2)
- **Dashboard all-zeros diagnosed: the deployed `/exec` Apps Script is an OLD
  version without `?sheet=` support.** Verified via curl:
  `GET ...?apiKey=...&sheet=DashboardDB1` returns the transactions
  `{"rows": [...]}` payload, not `{"grid": [...]}` — the deployment predates
  commit `c3cef27`. The app parsed the missing `grid` as an empty grid, so every
  label-anchored lookup fell back to 0.
  - **Client fix** in `sheets_repository_impl.dart#fetchDashboard`: a response
    without a `grid` list is now a `Failure` with a redeploy hint, so the UI
    shows an ErrorCard instead of silently rendering zeros.
  - **Real fix is user-side**: open the Apps Script project → Deploy → Manage
    deployments → Edit → **New version** → Deploy (same URL stays valid).
    `docs/apps_script/Code.gs` already has the `?sheet=` code — it just was
    never published.
- **Launcher icon artwork enlarged.** The trend-line glyph occupied only ~21% of
  the 1024² canvas. Regenerated with Pillow:
  - `icon_foreground.png`: glyph scaled **2.1×** (~45% of canvas — the max that
    keeps its half-diagonal, 291px, inside the 313px adaptive-icon safe-zone
    circle radius).
  - `icon.png`: rebuilt as **full-bleed opaque** (background color + glyph at
    2.7× ≈ 57%). The old file had baked-in transparent rounded corners, which
    iOS would have rendered as black; the OS masks corners itself.
  - Ran `dart run flutter_launcher_icons` — all Android mipmaps + iOS appiconset
    regenerated.
- **Tab order swapped** in `main.dart`: `_pages = [DashboardPage(), SheetViewPage()]`,
  nav items reordered — Dashboard is now index 0 (left), Transactions index 1.

### Previously shipped (2026-07-02, session 1)
- **Fixed `ClientException: software caused connection abort`**: `DashboardDB1`
  read takes ~10–13s (live formulas), old 15s timeout tore the socket down.
  `_timeout` 15s → 30s; `_get()` retries idempotent GETs once; POST never
  retried. Commit `05d92ce`.
- **Launcher icon wired up** (`flutter_launcher_icons ^0.14.3`, sources in
  `assets/icon/`). Commit `bf7f079`.

### Previously shipped (2026-07-01) — Dashboard page
- `AppConfig.sheetsWebAppUrl` updated to new `/exec`, `sheetsApiKey =
  'jibsaja-secret-2024-xk9m'` (matches `API_KEY` in `Code.gs`).
- **`DashboardDB1` is the data source — nothing computed client-side.** Files:
  `domain/entities/dashboard_summary.dart`,
  `data/models/dashboard_summary_model.dart` (label-anchored `fromGrid`),
  `presentation/pages/dashboard/dashboard_page.dart`, `fx_sparkline.dart`
  (CustomPaint, no charting dep), plus `fetchDashboard()` through repo/provider.

## Context & Logic Decisions
- **Cache stores raw response bodies, not serialized entities.** Entities have
  no `toJson`; caching the body means one parser for live + cached data, and a
  future schema change degrades to "no cache" instead of a migration.
- **StreamProvider over AsyncNotifier for cache-first emit.** A `FutureProvider`
  can only resolve once; `async*` yields cached-then-live naturally, and
  `AsyncValue.when`'s default `skipLoadingOnRefresh` keeps pull-to-refresh
  behavior identical.
- **Failed refresh keeps stale data silently (when cache exists).** Rationale:
  stale numbers beat an error card for a glance-first app; the error still
  surfaces when there is nothing cached. The "Updated Xm ago" caption is the
  staleness signal — after a failed silent refresh it honestly keeps aging.
- **Freshness = cache write time, not a separate clock.** The timestamp is
  written in the same `write*` call as the body, so "Updated X ago" is by
  construction the age of the data on screen — including the offline case.
- **Parse by label-anchor, not fixed cells.** `DashboardSummaryModel.fromGrid`
  finds each Korean label cell and reads the cell(s) to its right (dual-currency
  totals: USD at +1, KRW at +2). Survives row/column inserts in the sheet.
- **Missing `grid` is a hard Failure, not an empty dashboard.** All-zeros KPIs
  are worse than an error card: they look like real data. Same philosophy as the
  existing `{"error": ...}` → `Failure` handling; `fetchTransactions` keeps its
  lenient missing-`rows` → empty-list behavior.
- **Adaptive-icon glyph sizing is geometry-bound.** Foreground content must fit
  the 66/108 safe-zone circle (radius ≈ 313px on a 1024 canvas); 2.1× was chosen
  from the measured glyph bbox (217×172, centered), not eyeballed.
- **`총 자산` = cash + stocks only.** Crypto (업비트/빗썸) and card debt live in
  the `Accounts` tab, NOT in `DashboardDB1` totals. Extend later via
  `?sheet=Accounts`.
- **Nav.** `HomeShell` + `IndexedStack` preserves tab state; custom bottom bar
  because the theme leaves `NavigationBar` transparent. Still no router.

### Dashboard-zeros RESOLVED (same day, later in session)
The user's redeploy had created a **new deployment with a new URL**
(`.../AKfycbz2BnfyQnx9.../exec`); the old URL stayed pinned to old code forever.
`app_config.dart` (gitignored) now points at the new URL. Verified end-to-end:
`?sheet=DashboardDB1` returns the grid, transactions GET works, and
`DashboardSummaryModel.fromGrid` run against the live grid resolves **every**
KPI (e.g. totalAssetsKrw ≈ ₩270.6M, returnRate ≈ +25.9%, 179 FX points).
Bonus: the new deployment answers in ~2.6s vs the old ~13s.

## The 'Gravel'
- **The freshness label only ticks per minute** and the empty-transactions
  state (`_EmptyState`) doesn't show it — both fine, just deliberate.
- **Cache is unbounded**: the full transactions body is one prefs string; fine
  for years of personal data, but SharedPreferences loads it all into memory.
  Switch to a file (path_provider) if the sheet ever gets huge.
- **The OLD Apps Script deployment (`AKfycbz4_GJUe...`) is still active** and
  serves stale code. Nothing points at it anymore, but archive it in
  Deploy → Manage deployments to avoid future confusion.
- **Session's changes are uncommitted** (icon assets + generated mipmaps/appiconset,
  `main.dart`, `sheets_repository_impl.dart`, `HANDOVER.md`, `pubspec.lock` was
  already dirty before the session).
- **The 30s timeout may now be overly generous** — the new deployment answers
  the DashboardDB1 read in ~2.6s (old one took ~10–13s). Harmless as-is; could
  be tightened once on-device behavior is confirmed.
- **One glitch cell in DashboardDB1**: a `Close` cell serialises as a bogus
  `1904-01-03T...` date; the FX parser skips non-numeric cells (series can be 1
  point short).
- **`currency_formatter.dart` still fully unused** — delete if it stays unused.
- Sparkline stays deliberately minimal (straight segments, no axis labels).
- **Sign convention & existing sheet rows**: `netInvested` now assumes Sell
  amounts are stored NEGATIVE (the user's convention). If any pre-existing
  manual Sell rows have positive Amounts, Net invested will read high — worth a
  glance at the live sheet.
- The two-row hint caption under "Brokerage account" uses literal wording
  ("Writes 2 rows: …"); tweak copy if it feels un-minimalist.
- Read-back Sell rows show the stored negative quantity in the list subtitle
  ("−10 @ 150") — honest to the sheet, but could display abs(qty) if the user
  prefers.

## Next Immediate Step
1. **Verify on-device that the startup error is gone**: fresh install (or
   clear app data) + launch → should shimmer, retry silently if the first
   fetch hiccups, and only error if the network is truly down. Then relaunch —
   cached data should paint instantly with the "Updated …" caption. If the
   error card still appears, **the small text under "Could not load data" is
   the actual exception — capture it**, it pinpoints the remaining cause.
2. Commit this session's work (`pubspec.yaml`, `pubspec.lock`, `main.dart`,
   `sheets_local_cache.dart`, `i_sheets_repository.dart`,
   `sheets_repository_impl.dart`, `sheets_providers.dart`,
   `updated_at_label.dart`, both pages, new test files, `HANDOVER.md`). Optional backlog: `git push`, Accounts-tab crypto/debt,
   delete unused `currency_formatter.dart`, archive the old Apps Script
   deployment, verify Buy/Sell on-device (carried over from session 3).
