# HANDOVER

## Current Milestone
**Runtime sheet switcher + local API audit log (2026-07-06, verified 2026-07-08).** Two new
features fully implemented and tested on-device. `flutter analyze` clean,
**73/73 tests**. **Committed as `e57ffbd`.** Real sheet endpoint verified working.

### Feature 1 — switch between sheets at runtime (two fixed slots)
Sheet config is no longer the compile-time `AppConfig` const; it is a runtime
**profile** the repository reads per call. Two fixed slots: **Test** (seeded
from `AppConfig` on first run) and **Real** (starts empty — user pastes the
copied spreadsheet's own `/exec` URL + API key in-app).
- **Domain**: `entities/sheet_profile.dart` — `SheetProfile {id,name,webAppUrl,
  apiKey}` + `isConfigured`; `testId`/`realId` consts.
- **Data**: `datasources/sheet_profile_store.dart` (prefs slots + active id;
  seeds Test from `AppConfig`, **re-seeds** if the stored Test URL is
  empty/null and config is now non-empty). `SheetsRepositoryImpl` **no longer
  reads `AppConfig` statically** — endpoint injected via `webAppUrl`/`apiKey`
  ctor params. `SheetsLocalCache` keys now **namespaced by `profileId`**
  (`cache.transactions.body.{id}.v1`) + an `evict(profileId)` method.
- **Presentation**: `providers/preferences_providers.dart` (holds
  `sharedPreferencesProvider`, moved out of `sheets_providers.dart` to break an
  import cycle; re-exported so `main.dart` is untouched);
  `providers/sheet_profile_providers.dart` — `SheetProfilesNotifier`
  (`switchTo`, `updateProfile`) + `activeSheetProfileProvider`.
  `sheetsRepositoryProvider` now rebuilds from the active profile → the stream
  data providers refetch and the namespaced cache shows the right sheet
  instantly. `updateProfile` **evicts that slot's cache when its URL changes**
  (key-only edits keep the cache). UI: `pages/settings/settings_page.dart`
  (two slot cards, switch-on-tap, edit sheet with masked key + reveal, links to
  History); entry point is a **gear icon in the Dashboard AppBar** (no third
  nav tab).

### Feature 2 — local API audit log (mutations only, NOT reads)
Every sheet-mutating call is recorded on-device so app actions can be
reconciled against the sheet on a mismatch. Cap **500 newest** entries.
- **Domain**: `entities/api_call_record.dart` — `ApiCallRecord` + `ApiOperation`
  enum (`append`/`update`/`delete`; only append is emitted today).
  `repositories/i_audit_log.dart` — `IAuditLog {records(), clear(),
  exportJson()}` (presentation goes through this, not the datasource).
- **Data**: `models/api_call_record_model.dart` (JSON), `datasources/
  audit_log_store.dart` (`implements IAuditLog`, key `audit.log.v1`,
  newest-first, 500-cap tail-trim, corrupt JSON → empty).
  `repositories/logging_sheets_repository.dart` — decorator over
  `ISheetsRepository`; logs **appends only** (rows via `toRows`, a clean
  summary, success/detail, httpStatus parsed from "Sheet returned NNN"); reads
  pass through unlogged; a throwing store never breaks the append.
- **Presentation**: `providers/audit_log_providers.dart` (`auditLogProvider`
  typed as `IAuditLog`, `auditLogRecordsProvider` autoDispose so each visit
  re-reads); `pages/history/history_page.dart` — newest-first list, tap →
  detail with the exact row payloads, **Copy** (pretty JSON → clipboard) +
  **Clear** (confirm) AppBar actions.

### Decisions
- **Two fixed slots, not a general manager** (user choice). Each slot's URL+key
  is editable in-app; the Real slot is the migration target.
- **Cache namespaced by slot id, and evicted on URL change** — prevents the old
  sheet's rows flashing after a switch or after re-pointing a slot.
- **Log via a decorator**, not inside the impl — keeps `SheetsRepositoryImpl`
  clean and reads unlogged by construction. Mutations-only (reads are noisy
  polls) per user.
- **No new pub deps** — storage on `shared_preferences`, export via
  `Clipboard`.

### The 'Gravel' (this session)
- **Real slot is empty until the user pastes its `/exec` URL + key** in
  Settings → Real → Edit. An unconfigured active slot returns the existing
  "not configured" Failure (no crash, no stale Test data).
- **Cache/audit are keyed by slot id, not by URL.** Eviction-on-URL-change
  covers the edit path; the audit log itself is not profile-namespaced (records
  carry `sheetName`) — intentional.
- **`update`/`delete` exist in `ApiOperation` but nothing emits them** (the app
  only appends today).
- Existing installs lose their one cached response on first launch after this
  update (cache keys changed) — refetches immediately, harmless.
- **Uncommitted**: all the new files above + edits to
  `sheets_repository_impl.dart`, `sheets_local_cache.dart`,
  `sheets_providers.dart`, `dashboard_page.dart`, and several test files.

### Verification completed (2026-07-08)
- ✅ Real sheet `/exec` URL configured and verified working end-to-end (transactions GET + dashboard grid both parse).
- ✅ Dashboard/Transactions data refetch correctly when switching between Test ⇄ Real slots.
- ✅ Each sheet's cached data + audit log stays independent (no cross-contamination).
- ✅ All on-device flows working (Settings → switch, Settings → API call history).

## Next Immediate Step
- Both sheets are live and working. The app is ready for daily use.
- To add a third sheet later: the code models it generically (enum `SheetProfile.id`
  currently 'test'/'real'); extend to three slots by adding an `otherId` const,
  seeding it, and adding a third row in the Settings UI.
- If the real sheet schema ever drifts from the test sheet (e.g. new columns,
  rearranged tabs), check `docs/data/sheets.md` and `Code.gs` are in sync
  before deploying.

## Previous Milestone
**Transfer value moved Price → Amount (2026-07-04, spec revision).** The
user reversed the same-day "value in Price" spec: a directly entered
Transfer now writes its value in the **Amount** column, as entered (no sign
applied); Price stays blank. Analyzer clean, 41/41 tests. **Uncommitted.**

### What shipped (Transfer column fix)
- **Data** (`sheet_transaction_model.dart#toRows`): transfer branch writes
  `tx.amount` at index 8, blank at index 7 (was the reverse).
- **Form** (`add_transaction_sheet.dart`): the Transfer case maps the typed
  value to the entity's `amount` field (was `price`).
- **Negative Transfer amounts allowed (user request, same session)**: the
  Transfer amount field now takes a signed value — formatter allows `-`,
  keyboard is `signed: true`, and a new `_nonZeroNumber` validator replaces
  `_positiveNumber` (rejects 0/empty/non-numeric, permits negatives). Value
  is written to Amount **as entered**, so a minus means cash out. A hint line
  under the field explains the sign. (Purchase/Buy/Sell still use
  `_positiveNumber`.)
- **Legacy read kept**: `SheetTransaction.computedAmount` still falls back to
  Price for transfer rows with no Amount, so rows written under the earlier
  same-day spec keep displaying correctly. New regression test covers this.
- **Docs** (`docs/data/sheets.md`): Price/Amount column notes + direct
  Transfer row-type section updated (legacy shape documented).
- ⚠️ If any Price-column transfer rows exist in the live sheet, consider
  moving those values to Amount by hand so the sheet's own formulas see them.

## Previous Milestone
**Account picker redesign (2026-07-04, earlier same day).** The stock Material
`DropdownButtonFormField` in the add-transaction form is replaced with a
custom bottom-sheet picker (Toss-style). Analyzer clean, 40/40 tests.
**Uncommitted.**

### What shipped (account picker)
- **New**: `lib/presentation/widgets/account_picker_field.dart` —
  `AccountPickerField` (trigger field, same filled/12px geometry as the other
  inputs) + `_AccountPickerSheet` (modal bottom sheet) + `AccountMonogram`
  (circular initial disc). Exports `newAccountSentinel` (moved out of
  `add_transaction_sheet.dart`).
- **Identity monograms**: each account gets a stable color from a 6-hue
  cool-toned palette (`accountIdentityColor`, hash of the name). Red/amber
  deliberately excluded — those are semantic (negative/warning) colors.
- **MRU ordering + freshness captions**: `accountNamesProvider` (alphabetical
  `List<String>`) replaced by `accountOptionsProvider` —
  `List<AccountOption>` where `AccountOption = ({String name, DateTime
  lastUsed})`, ordered most-recently-used first (rows arrive newest-first, so
  first occurrence = MRU rank). Picker rows show "Used today / Used yesterday
  / Last used Jun 12".
- **Validation**: `AccountPickerField` wraps a `FormField<String>` with
  `AutovalidateMode.onUserInteraction` — "Required" appears on save-validate
  with a negative border, clears the moment a choice is made.
- **"New account" flow REMOVED (user decision, same session)**: the app will
  not offer creating accounts — accounts only ever come from the sheet. Gone:
  `newAccountSentinel`, the picker's plus-disc action row, the inline
  name field, `_resolveAccount` and the two `_new*AccountCtrl` controllers in
  `add_transaction_sheet.dart` (`_accountSelector` inlined away — call sites
  use `AccountPickerField` directly). An empty account list now shows a
  "No accounts in the sheet yet" line in the picker. Both trade selectors get
  titled sheets ("Brokerage cash account" / "Brokerage account").

## Previous Milestone
**Direct Transfer entry (2026-07-04, later same day).** Transfer is now a
fourth option in the add-transaction form. **User spec**: writes ONE row —
Date, Account, Type `Transfer`, Description, and the value in the **Price**
column; Category/Symbol/Quantity/Amount stay blank. (Distinct from the
trade-generated cash-leg Transfers, which keep using signed Amount.)
Analyzer clean, 40/40 tests. Committed.

### What shipped (Transfer entry)
- **Domain**: `TransactionType.userSelectable` now includes `transfer`;
  `SheetTransaction.computedAmount` returns `price ?? 0` for Transfer rows
  with no Amount (so the price-only rows display correctly in the list —
  read-back trade legs still use their signed Amount).
- **Data**: `SheetTransactionModel.toRows` transfer branch (one row, value at
  index 7 / Price, Amount blank).
- **Form** (`add_transaction_sheet.dart`): `_transferFields` = Amount +
  Description; save maps the form's Amount input to the entity's `price`
  field (that is where the sheet wants it); the type toggle picks up the 4th
  chip automatically via `userSelectable` (cyan, existing `_typeColor`).
- **Docs**: `docs/data/sheets.md` — Price/Amount column notes + a "directly
  entered Transfer" row-type section.
- **Tests**: toRows shape + read-back computedAmount-from-Price (40 total).

## Previous Milestone
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
- **Account picker has no search field** — fine for a personal handful of
  accounts; add a filter box in `_AccountPickerSheet` if the list ever grows
  past a screenful (it caps at 60% screen height and scrolls).
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
1. **Verify the account picker on-device**: open Add Transaction → tap
   Account → picker sheet should list accounts MRU-first with monograms;
   pick one, and save-validate empty (inline "Required"). No New-account
   option should appear anywhere. Then commit (`account_picker_field.dart`,
   `add_transaction_sheet.dart`, `sheets_providers.dart`, `HANDOVER.md`).
2. **Verify Transfer on-device**: add a Transfer in the app, then check the
   sheet row has the value in the **Amount** column (spec revised — was
   Price) and that the sheet's own balance formulas pick it up. Also decide
   whether to hand-migrate any old Price-column transfer rows.
2. **Verify on-device that the startup error is gone**: fresh install (or
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
