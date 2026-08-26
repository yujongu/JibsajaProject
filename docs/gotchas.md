# Jibsaja — Gotchas

Non-obvious traps that have each cost real time at least once. Everything here was verified
against the working tree, not carried forward on faith. If an entry stops being true, delete it.

Companions: [`data/sheets.md`](data/sheets.md) (the backend contract),
[`handover-archive.md`](handover-archive.md) (why past decisions were made).

## Silent filter drops — the app's most dangerous failure mode

Three places filter sheet rows by a literal string. In every one, **a blank, misspelled or
renamed cell makes the row disappear with no trace** — no "other" section, no footer count, no
error. A user reporting "my position is missing" is almost always looking at this.

| Filter | Where | Matches |
|---|---|---|
| Holdings currency | `sheets_providers.dart:231` — `_kHoldingsCurrencies` | `'KRW'`, `'USD'` |
| Account type | `accounts_page.dart:16-17` — `_kCreditType` / `_kBankType` | `'Credit'`, `'Bank'` |

- **Check the sheet cell before touching the app.** The fix is nearly always in the spreadsheet.
- **`_kHoldingsCurrencies` is a hard-coded pair.** A third currency needs a code change — one line
  in `sheets_providers.dart`, but there is no setting for it.
- Matching normalizes with `trim().toUpperCase()`, the same rule `groupByCurrency` and
  `SheetAccountList.ofType` use. Arguments are expected pre-uppercased.

## Money formatting

- **`money()` puts the minus after the symbol**: `₩-512,300`, not `−₩512,300`. Pre-existing and
  shipped everywhere. `money_test.dart` pins it, so changing it is one line plus one test — but a
  wall of negative card balances is where it looks worst.
- **USD renders to 2 decimals** (`$45.30`, not `$45.3`). Only amounts explicitly labelled USD move;
  `plainNumber` and the bare-number arm are untouched. It reaches the Transactions list, the
  summary card, category drill-downs and any USD account balance. Nothing ₩ is affected.

## Testing

- **`UpdatedAtLabel` cannot be pumped with a non-null time.** It watches a **non-autoDispose**
  one-minute `Stream.periodic`, so `pumpAndSettle` never settles and the timer is still pending at
  teardown even after unmounting. Disposing the `ProviderScope` does not cancel it, and making the
  ticker `autoDispose` does not either (tried and reverted). Cover the value at the **provider**
  level. If a test ever needs the rendered "3m ago", the lever is injecting the ticker.
- **`find.byType(UpdatedAtLabel)` needs `skipOffstage: false`** — with a null time it builds
  `SizedBox.shrink()`, and the default finder skips a zero-size widget even though it is mounted.
- **Several widget tests disambiguate by size, not identity** — `fontSize == 28` for a section
  total, `size == 20` for a tile icon (the summary card draws the same `IconData` at 14px). Change
  the type scale and these fail with "expected 1 element" rather than anything descriptive.
- **Some assertions depend on two strings merely being distinct.** `find.text('Market value')`
  findsNothing works only because `'KRW · Market value'` is a different string;
  `find.text('Net')` findsNothing works only because the caption is `'Net flow'`. **Renaming
  either caption silently inverts the assertion** rather than failing it.
- **The color-distinctness test compares exact `Color` values**, not perceived difference. Two
  categories one hex apart would pass. It catches literal duplicates, not subtle clones.

## UI & layout

- **The summary card's height is what the `AnimatedSize` month transition sizes against.** Any
  change to the card's content changes that animation. With the category cap removed its worst
  case is 12 bars. If the transition reads badly, the lever is the `AnimatedSize` duration/curve,
  **not** re-adding the cap.
- **`accountIdentityColor` has only 6 hues**, so a section with 7+ positions repeats colors in the
  stacked bar. It is shared with the account monograms — widening `_identityColors` changes those
  too.
- **The Holdings stacked bar is ordered by the current sort, not by size.** Sorting by Symbol gives
  an alphabetical bar — honest, since it matches the rows, but not the "biggest slice first" shape
  an allocation chart usually implies.
- **Tap targets are under the 44px guideline** in two places: the category bars (~35px) and the
  Holdings sort header (10px type, with `GAIN` and `GAIN %` adjacent). `HitTestBehavior.opaque`
  makes the full row tappable, but mis-taps are possible.
- **`ThemeMode.system` looks identical to whichever of Light/Dark the OS is currently on.** The
  segment highlight is the only cue; there is no "System (Dark)" hint. The one genuinely ambiguous
  state on the Settings page.
- **The status bar follows the theme, the Android navigation bar does not** — it has never been
  styled by this app.
- **The app has no explicit `Semantics` anywhere.** Screen-reader users hear the theme segments as
  three unrelated buttons. Consistent with the rest of the app, not a new gap.

## Known dead code — pre-existing, deliberately untouched

Recorded so it is findable in one place. None of it is a bug; do not delete it as drive-by work.

- `groupByMonth()` + `MonthGroup` in `transaction_summary.dart` — one reference, its own definition
- `lib/presentation/shared/utils/currency_formatter.dart` — zero references
- `_typeColor` defined twice: `transaction_tile.dart:157` and `add_transaction_sheet.dart:463`
- `_SectionLabel` defined three times: `settings_page.dart:278`, `dashboard_page.dart:649`,
  `accounts_page.dart:170`
- `add_transaction_sheet.dart:467` uses a literal `Color(0xFFF59E0B)` that duplicates
  `AppColors.warning` (`app_colors.dart:43`)
- Secondary/cyan literals at `app_theme.dart:19-22` never made it into `AppColors`
- `_NetCaption` renders a zero net flow as `+0`
- `AppColors.negative` is unreachable for purchase rows but must stay in `_typeColor`'s switch,
  which has to remain exhaustive over `TransactionType`. The analyzer does not flag it.

## Build

- Gradle KGP deprecation warnings appear on every APK build. Expected noise, not a regression.
