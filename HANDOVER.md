# HANDOVER

## Current Milestone
**Summary card reworked: currency-scoped totals, income, invested/divested
(2026-08-03).** Analyzer clean, **108/108 tests**, release APK built.
**Uncommitted.**

The card showed two stats — Spending and Net invested — that between them had
four problems. All four were fixed in one pass.

### Context & Decisions
1. **⭐ The card's totals added KRW and USD into one meaningless number.** The
   real defect, made visible by the per-row currency work in `0af12d8`: the
   card's total matched no single row's currency. `summarize()` now splits by
   currency and emits a `CurrencySummary` per code. **No FX conversion** — the
   project takes no live rate feeds.
2. **Sections stack; there is no currency toggle.** The user confirmed a month
   almost always has exactly one currency, so both layouts collapse to the same
   thing in the common case. A control seen twice a year is one you've
   forgotten, and it would hide a second currency behind a tab you'd never think
   to tap. **The currency header is suppressed when there is only one section** —
   the ₩/$ prefixes already establish scope — so a normal month's card reads
   almost exactly like the old one.
3. **⭐ Safeguard: if *no* row resolves a currency, everything lands in one
   unlabelled section.** Without this, an unreachable `Accounts` tab (or the
   window before it loads) would render an all-zeros card — strictly worse than
   before. Same philosophy as `fetchDashboard`'s missing-`grid` guard: all-zero
   numbers look like real data. Rows that can't be placed are otherwise excluded
   and **reported** in a footer note naming the reason.
4. **Deposits are now Income**, with a `Net flow` (income − spending) caption.
   They were previously dropped from every total, so a month had no notion of
   surplus or deficit.
5. **Net invested split into Invested / Divested**, two positive magnitudes,
   with the net underneath. Netting alone made a month where you bought ₩800k
   and sold ₩800k read as a flat zero — indistinguishable from no trading.
6. **The top-4 category cap is gone; every category with spend gets a bar.**
   Side benefit: the cap folded its tail into `TransactionCategory.misc`, so a
   genuine `Misc.` spend and "everything else, small" were indistinguishable.
   Now `Misc.` means only itself. Categories summing to **zero** are dropped —
   an empty bar labelled `₩0` is noise.
7. **Read-only.** No new network call at all; nothing in the POST path touched.

### What shipped
- **Domain** (`transaction_summary.dart`, substantially rewritten):
  `TransactionSummary` is now `{List<CurrencySummary> byCurrency, UncountedRows
  uncounted}`. New `CurrencySummary` (spending, income, invested, divested,
  per-currency category bars; `netFlow` / `netInvested` / `activity` getters)
  and `UncountedRows {unknownType, unknownCurrency}`. `summarize()` takes an
  optional `currencies` map and buckets rows through a private `_Accumulator`
  that holds the per-type switch. **`_capCategories` deleted** (orphaned by the
  change; no test covered it).
- **Domain** (`sheet_account.dart`): `SheetAccount.key(name)` —
  `trim().toLowerCase()`, the account-join normalization, now defined once and
  used by all three join sites (provider, `summarize`, the tile lookup).
- **Presentation** (`sheets_providers.dart`): `selectedMonthSummaryProvider`
  watches `accountCurrenciesProvider` and passes it to `summarize`, so the card
  re-splits the moment the Accounts tab lands.
- **Presentation** (`sheet_view_page.dart`): `_SummaryHeader` now renders one
  `_CurrencySection` per currency (divided, header only when >1) plus the
  uncounted note (`_uncountedNote`). New `_NetCaption` for the two net lines.
  `_CategoryBar` gained a `currency` and prints via `_money` instead of `_num`.
  The Invested/Divested block is hidden entirely when both are zero, so
  expense-only months stay as compact as before.
- **Tests** (+10 → 108): `transaction_summary_test.dart` reworked — existing
  three moved to `byCurrency.single.…`, plus currency splitting/ordering,
  the no-currency safeguard, partial knowledge, unmapped transfers not counted,
  case/space-insensitive account matching, income + net flow, the equal
  buy/sell case, all-categories-shown, and zero-category omission.

### The 'Gravel' (this session)
- **Not verified on-device yet.** APK built, not installed.
- ⚠️ **The card is what the month-switch animation sizes against**
  (`AnimatedSize`, the 2026-08-02 milestone). Removing the category cap raises
  its worst case from 5 bars to **12**, and the new Income/Net-flow/Invested
  rows add height too. Build cost is not the concern (the row list was the
  bottleneck, not the card) — what to watch for is a longer, more noticeable
  height animation between months with very different category counts. If it
  reads badly the lever is the `AnimatedSize` duration/curve, **not** re-adding
  the cap.
- **A category that nets negative is dropped along with the zero ones** (the
  filter is `> 0`). Only reachable if refunds are ever entered as
  negative-amount expense rows; if that starts happening, the visible bars would
  no longer sum to Spending.
- **`totalIncome` sums Deposit amounts as stored.** A negative-Amount Deposit
  would reduce income rather than being treated as an expense — honest to the
  sheet, but untested against real data since nothing writes Deposits.
- **The uncounted note is static text, not a tap target.** It names the reason
  ("1 account missing from Accounts") but not *which* account — cross-reference
  the bare-number rows in the list below it.
- `TransactionSummary.empty` has an empty `byCurrency`, so any consumer must
  handle a card with no sections (a month with no rows). Only `_SummaryHeader`
  consumes it today and it iterates, so this is safe by construction.
- Pre-existing and untouched: dead `groupByMonth()` + `MonthGroup` in
  `transaction_summary.dart`; the two duplicate `_typeColor` functions; the
  Gradle KGP deprecation warnings on every APK build.

## Next Immediate Step
- **Install `build/app/outputs/flutter-apk/app-release.apk`** and open
  Transactions against the **Real** sheet:
  - A normal single-currency month shows **no currency header** and reads like
    the old card, with ₩/$ on every figure.
  - Spending still equals the sum of its category bars, and **every** category
    with spend has a bar — no "Other" fold, no empty ₩0 bars.
  - A month with Deposits shows Income and a Net flow equal to income −
    spending; a month with trades shows Invested/Divested; an expense-only
    month hides that block entirely.
  - If a KRW+USD month exists, both sections appear with headers and their own
    bars.
  - The uncounted note, if present, names how many rows and why.
  - **Month switching still animates acceptably** — especially between months
    with very different category counts (see Gravel).
  - **Do not tap Add while verifying** — this change is read-only.
- Then commit (`transaction_summary.dart`, `sheet_account.dart`,
  `sheets_providers.dart`, `sheet_view_page.dart`, the two test files,
  `HANDOVER.md`).

## Previous Milestone
**Per-row currency from the sheet's `Accounts` tab (2026-08-03).** Analyzer
clean, **98/98 tests**, release APK built. **Committed as `0af12d8`, pushed.**

Transaction amounts were bare, unlabelled numbers — a ₩12,500 lunch and a
$12,500 trade looked identical. Each row's amount now carries its account's
currency: `₩12,500` / `$1,234.56`.

### Context & Decisions
1. **⭐ The currency source is an existing sheet column, not a new one.** This
   was the open question that parked multi-currency back in June (options were:
   add a Currency column / infer from the account name / hardcode). It turned
   out the **`Accounts` tab already had it** — `Account Name` in column A,
   `Currency` in column D. No sheet change, no inference, no guessing.
2. **No backend change and no redeploy.** `Code.gs`'s `doGet` already serves any
   tab as a raw grid via `?sheet=<name>` (the path `DashboardDB1` uses), so
   `?sheet=Accounts` worked against the deployed script as-is. Verified live
   before writing the parser: the response's header row is exactly
   `Account Name | Type | Institution | Currency | Include? | …`.
3. **Read-only by construction** (explicit user requirement — nothing may be
   written to the sheet). The feature adds exactly one call, a `GET`; the POST
   path, `appendTransaction`, `toRows`, and `add_transaction_sheet.dart` are all
   untouched, and the app never writes the `Accounts` tab.
4. **Header-anchored parsing, not fixed A/D indices** — same rationale as
   `DashboardSummaryModel.fromGrid`. Find the `Account Name` cell, then
   `Currency` in that same header row, so a column inserted in the tab does not
   silently shift the mapping.
5. **A broken/missing `Accounts` tab must not break the Transactions page.**
   Unlike `fetchDashboard` (where a missing `grid` is a hard `Failure`, because
   all-zero KPIs look like real data), `_parseAccountsBody` degrades to `const
   []` on an error payload, a missing grid, or missing headers. The tab only
   supplies labels.
6. **Unmapped rows render exactly as before — a bare number** (user's choice
   over defaulting to KRW or USD). Honest, and it makes accounts missing from
   the `Accounts` tab visible at a glance.
7. **KRW prints with no decimals** (`#,##0`) since the won has no minor unit;
   USD keeps today's `#,##0.##`. An unfamiliar code is prefixed literally
   (`EUR 12.5`) rather than guessed at.
8. **Summary card totals deliberately still mix currencies.** Out of scope per
   the user; see Gravel.

### What shipped
- **Domain**: `entities/sheet_account.dart` (`SheetAccount {name, currency}`);
  `i_sheets_repository.dart` gained `fetchAccounts()` + `cachedAccounts()`
  (no `cachedAccountsAt()` — nothing shows an accounts freshness label).
- **Data**: `models/sheet_account_model.dart` (`fromGrid`, header-anchored);
  `sheets_repository_impl.dart` — `fetchAccounts()` + `_parseAccountsBody()` +
  `cachedAccounts()`, modelled on the dashboard trio; `sheets_local_cache.dart`
  — `cache.accounts.body.{profileId}.v1` (body only, no timestamp key), included
  in `evict()`; `logging_sheets_repository.dart` — two pass-throughs in the
  reads block (reads stay unlogged).
- **Presentation**: `sheets_providers.dart` — `accountsProvider`
  (`StreamProvider`, reuses `_cachedThenLive` verbatim) and
  `accountCurrenciesProvider` (`Map<String,String>`, keys trimmed+lowercased,
  blank currencies dropped). `sheet_view_page.dart` — new top-level
  `_money(double, String?)`; `_TransactionTile` gained a `String? currency`
  field; `_TransactionsListState.build` watches the map **once** and passes the
  code per tile (no per-tile `ref.watch` — the sliver builder is the hot path
  from the previous milestone).
- **Docs**: `docs/data/sheets.md` — new "Accounts tab" section (column table,
  header-anchoring, the fallback rule); the stale "Account names" section now
  says the picker comes from the Transactions tab via `accountOptionsProvider`,
  not from `Accounts`.
- **Tests** (+11 → 98): new `test/data/models/sheet_account_model_test.dart`
  (live layout, inserted column, trimming/upper-casing, blank currency, nameless
  rows, missing headers, ragged rows); 3 `accountCurrenciesProvider` cases;
  accounts round-trip + evict in the cache test. Both `ISheetsRepository` fakes
  (`_FakeRepo`, `_FakeDelegate`) implement the two new members — `_FakeRepo`
  gained a scriptable `accountsResult`.

### The 'Gravel' (this session)
- **Not verified on-device yet.** The APK is built but not installed — see Next
  Immediate Step.
- ~~The summary card still adds KRW and USD into one Spending / Net invested
  number.~~ **Resolved by the current milestone** — that gravel note is what
  prompted it.
- **This adds a third GET on the Transactions page** (`?sheet=Accounts`). It is
  cache-first, so it never blocks first paint, and its label
  (`'accountsProvider'`) is *not* what the syncing bar watches
  (`isFetchingProvider('transactionsProvider')`) — so the bar's behavior is
  unchanged. A cold start with no cache retries it twice before giving up, same
  as the others.
- **The currency join is by account *name* string.** Rename an account in the
  Transactions tab without renaming it in `Accounts` (or vice versa) and that
  row silently loses its symbol. Trimming + lowercasing absorbs whitespace and
  case drift only.
- **`_money` is a private top-level function in `sheet_view_page.dart` and has
  no direct test** — coverage is at the model and provider level. It is 12 lines;
  if it grows (more currencies, negative-sign styling), lift it out to a shared
  util and test it.
- The `Accounts` tab's `Current Balance` / `Type` columns are read into the grid
  but **not** parsed — they are what a future net-worth extension (crypto + card
  debt, absent from `DashboardDB1`) would sum.
- Pre-existing and untouched: the Gradle KGP deprecation warnings on every APK
  build (`shared_preferences_android`); the two duplicate `_typeColor` functions
  (`sheet_view_page.dart` / `add_transaction_sheet.dart`); dead `groupByMonth()`
  + `MonthGroup` in `transaction_summary.dart`.
- **Stale notes now corrected**: the previous milestone's "Uncommitted" claim was
  wrong (it shipped as `942182b`), and its gravel item about
  `currency_formatter.dart` is moot — that file no longer exists.

### Next steps (carried over — still not verified on-device)
- Open Transactions against the **Real** sheet:
  - KRW accounts show `₩` with no decimals; USD accounts (e.g. 토스증권 달러,
    토스증권 해외 주식) show `$`.
  - Both legs of a Buy/Sell pair show the same symbol when the cash and
    brokerage accounts share a currency.
  - Note any row still rendering a **bare number** — that account is missing
    from the `Accounts` tab (or its Currency cell is blank). Those are rows to
    add to the sheet, not a bug.
  - Airplane mode → relaunch: cached currencies still render.
  - **Do not tap Add while verifying** — this change is read-only and the append
    flow is unrelated.
- Then commit: `sheet_account.dart`, `sheet_account_model.dart`,
  `i_sheets_repository.dart`, `sheets_repository_impl.dart`,
  `sheets_local_cache.dart`, `logging_sheets_repository.dart`,
  `sheets_providers.dart`, `sheet_view_page.dart`, `docs/data/sheets.md`, the
  four test files, `HANDOVER.md`.

## Previous Milestone
**Transactions month-switch motion made smooth (2026-08-02).** Analyzer clean,
**87/87 tests**. **Committed as `942182b`.** Verified on a physical device with
a release build (2026-08-03): the motion reads clean.

The month-change animation looked janky. Three separate causes, found and fixed
in order by driving the iPhone 17 simulator and capturing mid-transition frames.

### Context & Decisions
1. **`AnimatedSize` wrapped directly around `AnimatedSwitcher` stalls, then
   snaps.** `AnimatedSwitcher`'s default `layoutBuilder` leaves outgoing children
   unpositioned, so while both children are mounted the `Stack` sizes to their
   **union** — `AnimatedSize` sees that inflated size for the whole crossfade and
   only learns the real target when the old child unmounts at the very end.
   Captured frames showed the old month's category bars and rows still occupying
   full height most of the way, then a hard collapse.
   Fix: `_topAlignedSwitcherLayout` — a `layoutBuilder` that wraps previous
   children in `Positioned`, excluding them from the Stack's sizing pass. Plus
   `alignment: Alignment.topCenter` on the `AnimatedSize` so it grows from a
   fixed top anchor instead of the center (the card used to drift vertically).
2. **Cross-fading the row list doubled the tile cost.** Both months' tiles stayed
   mounted for the whole 260ms. Removed the row list's animation entirely — it
   now swaps instantly. Only the card animates; it is bounded at ≤5 category
   bars, so it is cheap regardless of how many transactions the month has.
3. **⭐ The real bottleneck: the rows were a `Column` inside a `ListView`.**
   A `Column` counts as **one** scroll child, so `ListView` virtualization never
   applied to it — *every* tile in the month was built and laid out in the frame
   the month changed. Measured against the live sheet: **March/April hold 131–134
   rows**, so each switch was constructing ~131 tiles (~1,300+ widgets)
   synchronously. This is why light months felt fine and heavy months did not.
   Fix: `ListView` → `CustomScrollView`; the rows are now a lazy
   `SliverList.builder`. Verified by temporary `debugPrint` instrumentation
   (since removed): a switch into a 131-row month builds **8 tiles, not 131** —
   ~16× less per-switch build work, and now flat in month size.

### What shipped
All in `lib/presentation/pages/sheet/sheet_view_page.dart`:
- New top-level `_topAlignedSwitcherLayout(currentChild, previousChildren)`.
- `_TransactionsList` is now a `ConsumerStatefulWidget` building a
  `CustomScrollView`: a `SliverList.list` header (updated-at label, `_MonthBar`,
  the animated summary card) + a `SliverList.builder` of tiles (or a
  `SliverToBoxAdapter` empty notice) + a trailing 96px spacer sliver.
- **`_MonthSection` / `_MonthSectionState` deleted.** Its direction state
  (`_direction`, `_lastKey`) and the `_slide` transition builder moved verbatim
  into `_TransactionsListState`; behavior is unchanged.

### The 'Gravel' (this session)
- ⚠️ **Profile mode does not run on the iOS simulator** ("Profilemode is not
  supported by iPhone 17"), so every observation this session was **debug mode**,
  which inflates widget-build cost substantially. The structural win is real in
  both modes, but the *felt* smoothness should be judged on a physical device or
  a release build — see Next Immediate Step.
- The frame captures were `xcrun simctl io booted screenshot` in a tight loop
  (~8–16 frames over the 260ms transition). Crude but it is what made causes 1
  and 2 visible. There is **no frame-timing profile** — the 8-vs-131 tile count
  is a build-work proxy, not a measured ms-per-frame improvement.
- The previous milestone's gravel note about "`_MonthSection` derives slide
  direction by comparing keys across builds" **still applies**, but the class is
  now `_TransactionsListState`. The caveat is unchanged: it assigns fields in
  `build` and calls no `setState`; don't "fix" it into a `ref.listen` without
  re-checking direction on the first tap after a data refresh.
- The old "no explicit `ClipRect` around the sliding card" note still holds — the
  scroll viewport provides the hard edge, now a `CustomScrollView`'s.
- Simulator automation needed **Accessibility permission** for the terminal app
  (System Settings → Privacy & Security → Accessibility) before `osascript`
  clicks would land; without it every click silently fails with `-25211`.
- Untouched and still dirty from before this session: `ios/Runner.xcodeproj/
  project.pbxproj`, `ios/Runner.xcworkspace/contents.xcworkspacedata`, plus an
  untracked `ios/Podfile.lock` and a stray file literally named `-`.

### Resolved (2026-08-03)
- ✅ **Judged on a physical device with a release build — the animation reads
  clean.** The simulator debug-mode caveat above was overstating the cost, as
  suspected. The `_TransactionTile` follow-up lever (`RepaintBoundary` per tile)
  is therefore **not needed** and was not pursued. Committed as `942182b`.

## Previous Milestone
**Month selector on the Transactions page (2026-07-30).** Analyzer clean,
**87/87 tests**, release APK built. Committed to `main`.
**Not verified on-device yet.**

The page showed *all* rows grouped by month with a summary card hardcoded to the
current month, so past months' spending/net-invested/category breakdown were
unreachable. It now shows **one month at a time** with ◀ / ▶ arrows, defaulting
to the current month.

### Context & Decisions
- **No backend change, and none was needed.** `fetchTransactions()` already GETs
  the entire sheet in one request and caches the raw body, so every month was
  already in memory. Month filtering is pure client-side work — `Code.gs` was not
  touched and needs no redeploy.
- The domain helper already took parameters: `TransactionAggregates.inMonth(year,
  month)`. The only thing hardcoding "now" was the provider. Nothing was added to
  the domain layer for this feature.
- **Arrows live outside the animated region** (`_MonthBar`, static, above the
  card). A control that slid away with the content it drives would be untappable
  mid-flight. This is why the month label moved out of the summary card and into
  the bar — the card's old `'This month'` / `'June 2026'` header row is gone.
- **Slide without a new dependency**: `AnimatedSwitcher` + a `transitionBuilder`
  that tests each child's key against the current month. This is the non-obvious
  bit — `AnimatedSwitcher` runs the *outgoing* child's animation in reverse, so a
  single tween sends both children the same way; the key test is what makes
  incoming enter from one side while outgoing leaves the other. Reproduces
  `SharedAxisTransition` without pulling in the `animations` package.
- **`PageView` was rejected**: it forces every page to the viewport height, which
  fights the card's variable height (0–5 category bars).
- Nav is **clamped to the data range** (oldest row month → current month), so the
  arrows can't walk forever into empty months.

### What shipped
- **Presentation** (`sheets_providers.dart`): `SelectedMonthNotifier` +
  `selectedMonthProvider` (a `DateTime` normalized to the 1st; `DateTime(y, m+n)`
  handles year rollover, so there is no manual month arithmetic anywhere).
  `monthBoundsProvider` (`MonthRange` record), `monthNavProvider` (the two arrow
  enabled-flags), `selectedMonthSummaryProvider`,
  `selectedMonthTransactionsProvider`.
  **Removed**: `currentMonthSummaryProvider`, `transactionsByMonthProvider`.
- **Presentation** (`sheet_view_page.dart`): new `_MonthBar`, `_MonthSection`
  (the animated part), `_MonthEmptyNotice`. `_MonthHeader` removed — redundant
  with one month on screen. `_SummaryHeader` lost its header row and gained a
  `super.key` (the `AnimatedSwitcher` needs to key it).
- **Presentation** (`add_transaction_sheet.dart`): on a successful append, also
  `selectedMonthProvider.notifier.select(tx.date)` — otherwise adding a
  today-dated row while viewing a past month looks like nothing happened.
- **Tests**: 9 new in `test/presentation/providers/sheets_providers_test.dart`
  (year-boundary shifts both ways, bounds, both arrow limits, gap month, past-month
  aggregates). The existing `_tx` helper gained optional `date`/`amount` params.

### The 'Gravel' (this session)
- **`groupByMonth()` + the `MonthGroup` entity are now dead code**
  (`transaction_summary.dart:53-71, 173-193`). Their only caller was the deleted
  `transactionsByMonthProvider`. Left in place deliberately — pure, tested
  (`transaction_summary_test.dart:54`), zero runtime cost — but nothing calls them.
  Delete them and their test if you want the domain layer tidy.
- **`_MonthSection` derives slide direction by comparing keys across builds**
  (`_lastKey`), not via `ref.listen`. Deliberate: it does not depend on Riverpod's
  notification ordering. It assigns fields in `build` but calls no `setState`, so
  it is safe — don't "fix" it into a listener without checking the direction is
  still right on the first tap after a data refresh.
- **No explicit `ClipRect` around the sliding card.** The `ListView` viewport
  provides the hard edge; clipping to the card's own bounds would chop its
  light-mode shadow (`blurRadius: 20`). The card *is* meant to overflow into the
  16px page margin during transit.
- `_kSlideExtent = 0.2` is a fraction of the card's width, not pixels. Tune there
  if the motion feels wrong on a real device.
- **Swipe gestures were not added** — arrows only, as specified. The sliding
  motion does rather invite a horizontal drag, so expect to want it.
- Pre-existing, untouched: the Gradle KGP deprecation warnings on every APK build
  (`shared_preferences_android`), and the two duplicate `_typeColor` functions
  noted in the previous milestone.

## Next Immediate Step
- Install the built APK (`build/app/outputs/flutter-apk/app-release.apk`) and
  check on-device: opens on the current month; ◀ slides the card in from the left
  and ▶ from the right, with the rows below cross-fading; both arrows grey out at
  their ends; a month with no rows shows "No transactions in …" **and keeps the
  arrows usable**; card height animates smoothly between months with different
  category counts; adding a row while viewing a past month jumps to that row's
  month.
- Still outstanding from the previous milestone (**not yet done**): confirm
  Deposit rows render green with a downward arrow and that the spending total is
  higher than it used to be. That code shipped in `27c8ce6`; only the on-device
  check is left.

## Previous Milestone
**Deposit rows no longer render as "Purchase" (2026-07-30).** Analyzer clean,
**78/78 tests**. **Committed as `27c8ce6`.**

### The bug
`TransactionTypeX.fromSheet` used `default: return purchase`, so *every*
unrecognized `Type` value became a Purchase. `Deposit` exists in the live sheet
but appeared nowhere in `lib/`, `docs/`, or `test/` — so Deposit rows showed the
red "Purchase" badge with a shopping-bag icon, and (worse, and not visible as a
label bug) `summarize()` ran `spend = -amount` on them, so a positive-Amount
Deposit **subtracted** from `totalSpending` and polluted the `Misc.` category
bucket. The summary header was understating spending.

### What shipped
- **Domain** (`transaction_type.dart`): two new members — `deposit` (read-only:
  cash in, entered in the sheet) and `unknown` (fallback). `fromSheet` now
  matches every known value **explicitly** (`expense`/`purchase` → `purchase`,
  plus `deposit`); the `default` branch returns `unknown`, not `purchase`.
  `userSelectable` is unchanged, so the add-transaction form still offers
  exactly four types. `unknown.sheetValue` **throws** `UnsupportedError` — it is
  never written, and a throw beats silently appending a bogus Type.
- **Domain** (`sheet_transaction.dart`): new `String? rawType` — the sheet's raw
  Type cell, populated by the model **only** when the type is `unknown`, so an
  unrecognized row can be badged with the sheet's own wording instead of a
  generic "Other". Null for every recognized type.
- **Domain** (`transaction_summary.dart`): `deposit`/`unknown` break out of
  `summarize()` — neither spending nor investing. **This is the total-fixing
  line**; expect the spending total to go *up* to its correct value.
- **Presentation** (`sheet_view_page.dart`): deposit → green
  (`AppColors.positive`) + `arrow_downward`; unknown → gray
  (`textTertiaryLight`) + `help_outline`. Badge is `tx.rawType ?? tx.type.label`.
- **Docs**: `docs/data/sheets.md` Type column + two new "Row types" bullets.

### The 'Gravel'
- ⚠️ **The title switch in `_TransactionTile` ends in a `_ =>` wildcard**
  (`sheet_view_page.dart:361`), so it does **not** fail to compile when a
  `TransactionType` member is added — new members silently fall into
  `ticker ?? label`. Every other type switch is exhaustive and *will* error, so
  the analyzer is a reliable checklist for all of them **except that one**.
- `flutter analyze` caught a switch the exploration pass missed:
  `add_transaction_sheet.dart:92` (`_save`'s tx-building switch). It now has a
  `deposit || unknown => throw UnsupportedError` arm — unreachable, since the
  form is driven by `userSelectable`.
- **Two duplicate `_typeColor` functions** (`sheet_view_page.dart:472` and
  `add_transaction_sheet.dart:456`) both had to be updated. They already
  disagree cosmetically: the form hardcodes `0xFFF59E0B` for `sell` where the
  page uses `AppColors.warning` (same value). Not merged — out of scope.
- One pre-existing test encoded the old behavior and was flipped:
  `{'type': 'wat'}` now expects `unknown`, not `purchase`.
- **Not verified on-device yet** — see Next Immediate Step.

### Next Steps (carried over — still not verified on-device)
- Install, open Transactions and confirm against the real
  sheet: Deposit rows are green **DEPOSIT** with a downward arrow and a positive
  amount; the summary header's spending total is now **higher** (Deposits stopped
  subtracting); Expense rows still read "Purchase"; the add form still shows four
  type chips.
- Watch for gray **help_outline** rows — each one is a Type string in the sheet
  the app doesn't know. The badge shows the sheet's own wording, so it names
  whatever needs adding to `fromSheet` next.

## Previous Milestone
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

### Follow-ups from that milestone (still open)
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
