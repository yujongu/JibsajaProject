# Jibsaja — Gotchas

Non-obvious traps that have each cost real time at least once. Everything here was verified
against the working tree, not carried forward on faith. If an entry stops being true, delete it.

Companions: [`data/sheets.md`](data/sheets.md) (the backend contract),
[`handover-archive.md`](handover-archive.md) (why past decisions were made).

## A blank Category cell is null, not Misc.

`TransactionCategoryX.fromSheet` falls back to `misc`, but `SheetTransactionModel.fromJson:58`
never calls it for a blank cell — it maps empty/missing straight to `null`. So an expense with no
Category arrives at the UI with `category == null`, and every consumer has to apply its own
fallback. `TransactionTile` falls back to Misc. for hue, label **and** icon; before 2026-08-27 the
icon alone did not, so those rows read as slate "MISC." with a shopping-bag glyph. Two rows in the
real sheet (May 2026) hit this, which is how it was found.

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
- **A module-level memo makes widget tests read each other's numbers.** `transaction_tile.dart`
  caches its block measurement globally; two `_pump` calls in one test both hit it, so a
  before/after comparison holds however the width was derived. `transaction_tile_test.dart` calls
  `resetBlockWidthCache()` in `setUp` and between paired pumps.
- **`didExceedMaxLines` does not detect a horizontally ellipsized label.** A single unbreakable
  word (`TRANSFER`) fits on one line and gets clipped, so maxLines is never exceeded. Compare
  `RenderParagraph.size.width` against `getMaxIntrinsicWidth(double.infinity)` instead.
- **`Color.computeLuminance()` makes contrast assertable in a widget test** — read the rendered
  `Text.style.color` and the `ColoredBox.color` behind it and compare. Used in
  `transaction_tile_test.dart`; cheaper than a golden and it says *why* it failed.
- **A widget test lays out against the *view*, not `MediaQuery.size`.** Passing a
  `MediaQueryData(size: Size(360, 800))` changes what the widget *reads* but leaves the tree
  laid out at the 800x600 test view, so nothing ever runs out of horizontal room and an
  overflow test silently passes. Use `tester.binding.setSurfaceSize(...)` (with a teardown
  resetting it to null) — see `transaction_tile_test.dart`.
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
- **A label drawn in the same hue as the surface behind it loses most of its contrast.** The
  transaction row's block label started at 1.73:1 (Sell, light) to 4.2:1 across all 17 labels —
  worse than the old badge, which sat on a plain card (식비 dark went 7.45 → 3.53). It is now
  mixed 45% toward the theme's text colour (`_labelInkMix`), which lands every label above 4:1 in
  both themes; the icon keeps the pure hue. `transaction_tile_test.dart` asserts the ratio for
  every label — twelve categories **and** the type labels, which are the binding cases (Sell
  4.20 light, Transfer 4.60 dark) — in both themes, finding the block by
  `ValueKey('block-ground')`. An earlier version found it by `ColoredBox` index and measured the
  *body* wash instead, which passes even with the block painted in the raw hue.
- **The transaction row's identity block has no fixed width.** `transaction_tile.dart` measures
  the widest of the 16 labels it can ever hold (12 categories + Deposit/Buy/Sell/Transfer) at the
  current `TextScaler` and uses that for every row, so the blocks stay aligned and the block
  follows the platform text-size setting. Two consequences: an **unrecognized** `Type` is
  deliberately excluded from the measured set — it shows the sheet's own wording, which could be
  any length, and ellipsizes rather than widening every row of the month; and the result is
  memoized in **module-level** `_widthCacheKey`/`_widthCacheValue`, keyed on scaled font size plus
  family, so it is shared across every tile and across tests in one process.
- **Non-flex Row children starve the `Expanded` one at accessibility text scales.** The
  transaction row's amount is not flexible, so at ~3x it took its full intrinsic width
  (`₩-10,688,000` is very wide) and squeezed the description to zero — a `RenderFlex overflowed
  by 285 pixels`. It is now bounded by `_amountMaxShare` and ellipsizes. The same shape exists
  elsewhere in the app and has not been audited.
- **The summary card and the bottom nav bar overflow at accessibility text scales.**
  `_SummaryHeader` overflows right, and `main.dart`'s `_BottomNav` has a fixed
  `SizedBox(height: 60)` that overflows by ~112px with the labels wrapping. Both pre-date the
  row redesign; both were visible on an iOS simulator at
  `accessibility-extra-extra-extra-large` on 2026-08-27.
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
- `_typeColor` defined twice, and the copies have **diverged**: `transaction_tile.dart:304` takes
  `isDark` and returns light/dark pairs, `add_transaction_sheet.dart:463` still returns one
  constant per type. The form's copy is only ever drawn on a sheet, so it has not been touched —
  but they are no longer interchangeable
- `_SectionLabel` defined three times: `settings_page.dart:278`, `dashboard_page.dart:649`,
  `accounts_page.dart:170`
- `add_transaction_sheet.dart:467` uses a literal `Color(0xFFF59E0B)` that duplicates
  `AppColors.warning` (`app_colors.dart:43`)
- Secondary/cyan literals at `app_theme.dart:19-22` never made it into `AppColors`
- `_NetCaption` renders a zero net flow as `+0`
- `AppColors.negative` is unreachable for purchase rows but must stay in `_typeColor`'s switch,
  which has to remain exhaustive over `TransactionType`. The analyzer does not flag it.
  `_typeIcon`'s purchase arm is unreachable for the same reason and stays for the same reason.

## Dart / imports

- **`package:intl/intl.dart` exports its own `TextDirection`**, which shadows the one from
  `dart:ui` that `material.dart` re-exports. Any file importing both and constructing a
  `TextPainter` fails with *"The getter 'ltr' isn't defined for the type 'TextDirection'"*.
  `transaction_tile.dart` imports intl as `hide TextDirection`; only `DateFormat` is needed there.

## Build

- Gradle KGP deprecation warnings appear on every APK build. Expected noise, not a regression.
