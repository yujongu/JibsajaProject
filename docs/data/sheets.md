# Google Sheet Schema & Backend Contract

The app's only backend is a **Google Apps Script web app** bound to a Google Sheet.
There is no Firebase. The app reads rows via `GET` and appends rows via `POST`.

Configure the endpoint in `lib/core/config/app_config.dart` (gitignored — copy
`app_config.template.dart` and fill in real values; never commit secrets):

```dart
static const String sheetsWebAppUrl = 'https://script.google.com/.../exec';
static const String sheetsApiKey = ''; // optional shared secret
```

The script source is checked in at [`../apps_script/Code.gs`](../apps_script/Code.gs);
its header documents how to deploy/redeploy. The shared secret is currently
**enabled** (`API_KEY` in the script must equal `sheetsApiKey` in the app).

> **Deploy gotchas that surface as "could not load data":** always use the
> `/exec` URL (not `/dev` — `/dev` requires you to be logged into Google, so the
> unauthenticated app gets a login page); set *Who has access* to **Anyone**;
> and after editing the script you must publish a **New version**
> (Manage deployments → Edit), or `/exec` keeps serving the old code. A missing
> `doGet` makes Apps Script return an HTML error page with HTTP 200 — the
> repository now detects HTML and returns a clear `Failure` instead of crashing.

## Transactions tab — column layout

| Idx | Column      | Notes |
| :-- | :---------- | :---- |
| 0   | Date        | ISO-8601 string |
| 1   | Account     | Free text (e.g. "Robinhood", "BoA") |
| 2   | Type        | `Expense` \| `Buy` \| `Sell` \| `Transfer` \| `Deposit` (the app labels the Expense flow "Purchase"; `Deposit` is **read-only** — displayed, never written). Any other value reads back as "Other" |
| 3   | Category    | Expense rows only. One of: `Monthly`, `교통`, `식비`, `생필품`, `의류`, `Fun`, `배달음식`, `Misc.`, `Work`, `경조사`, `웨딩`, `여행` |
| 4   | Description | Short note |
| 5   | Symbol      | Ticker symbol, Buy/Sell only |
| 6   | Quantity    | Buy/Sell only. **Signed** — Sell rows store a negative quantity |
| 7   | Price       | Buy/Sell: always positive. Blank otherwise (legacy direct-Transfer rows written before 2026-07-04 hold their value here — reading still supports them) |
| 8   | Amount      | **Signed.** Expense: **−amount** (cash out). Buy/Sell: quantity × price (Sell negative via its quantity). Trade-leg Transfer: − = cash out, + = cash in. Direct Transfer: the value **as entered** |

`SheetTransactionModel.columns` documents this POST value-array order (informational). The POST builder (`toRows`) writes positions directly; the GET parser reads object keys case-insensitively and does not use `columns`.

## Row types
- **Purchase** (stored Type: `Expense`) = a cash expense. **One row.** Fields:
  date, account, category, description, amount — Amount is written
  **negative** (cash out). Reading is lenient: both `Expense` and the legacy
  `Purchase` parse back to the app's Purchase type.
- **Deposit** = cash in, entered **directly in the sheet** — the app displays it
  (green badge, own label) but the add-transaction form never writes it. Amount
  is read as stored; Deposit rows are excluded from the spending total and the
  category breakdown.
- **Anything else** in the Type column reads back as the app's `unknown` type:
  the row is shown neutrally, badged with the sheet's own wording, and left out
  of every total. Before 2026-07-30 any unrecognized value — `Deposit`
  included — silently became a Purchase, which subtracted from the spending
  total; `TransactionTypeX.fromSheet` now matches every known value explicitly.
- **Buy / Sell** = an asset trade. The user enters date, brokerage cash
  account, brokerage account, description, symbol, quantity, price — and the
  app appends **two rows** (double-entry: each account's balance is the sum of
  its signed Amounts). Composed by `SheetTransactionModel._tradeRows`:

  | Row | Account | Type | Quantity | Amount (Buy) | Amount (Sell) |
  | :-- | :-- | :-- | :-- | :-- | :-- |
  | 1 (cash leg) | brokerage cash account | `Transfer` | *(blank)* | −qty × price | +qty × price |
  | 2 (trade leg) | brokerage account | `Buy` / `Sell` | Buy: +qty, Sell: **−qty** | +qty × price | −qty × price |

  The Sell quantity is written negative, so the trade leg's Amount is always
  plain Quantity × Price. Both rows share the same Date and Description and go
  in a single POST, so the append is all-or-nothing.
- **Transfer** = a cash movement. Two shapes:
  - *Trade cash leg* — generated automatically by a Buy/Sell (see above);
    value in the signed **Amount** column.
  - *Directly entered* (user spec revised 2026-07-04, later same day) —
    **one row** from the app's Transfer form: date, account, `Transfer`,
    description, and the value in the **Amount** column, written as entered.
    Category, Symbol, Quantity and Price stay blank. (Rows written by the
    earlier same-day spec hold the value in **Price** instead;
    `SheetTransaction.computedAmount` falls back to Price so they still read
    correctly.)

## Apps Script contract

### GET (read)
Request: `GET {webAppUrl}?apiKey={key}`
Response (object-per-row keeps parsing resilient to column reordering). The live
sheet returns **capitalized** header keys and names the ticker column `Symbol`:

> The endpoint reports its own failures as `{"error": "..."}` with HTTP 200
> (e.g. a wrong/missing `apiKey` returns `{"error":"unauthorized"}`). The
> transactions parser treats a missing `rows` as empty; the dashboard parser
> surfaces the `error` as a `Failure`.

```json
{
  "rows": [
    { "Date": "2026-01-31T15:00:00.000Z", "Account": "토스증권 국내 주식",
      "Type": "Buy", "Category": "", "Description": "", "Symbol": "190510",
      "Quantity": 1, "Price": 27550, "Amount": 27550 }
  ]
}
```

The parser (`SheetTransactionModel.fromJson`) resolves keys
**case-insensitively**, so capitalized or lowercase keys both work. The ticker
field is read from `Symbol` first and falls back to `ticker`.

Two read-side normalizations keep the app consistent with the sheet:
- **Dates are UTC on the wire** — Apps Script serializes a KST `2026-02-01`
  cell as `"2026-01-31T15:00:00.000Z"`. The parser converts to device-local
  time, so the displayed day and month grouping match the sheet's calendar.
- **Row order is preserved as a tiebreaker** — the app sorts newest-first by
  date, and rows with identical timestamps (same-day entries, the two legs of
  a trade) fall back to their sheet position (later rows first) instead of
  shuffling arbitrarily.

A bare top-level JSON array is also accepted.

### POST (append)
Request: `POST {webAppUrl}` with body:

```json
{ "apiKey": "…", "rows": [ ["2026-06-01T...", "BoA", "Expense", "식비", "Lunch", "", "", "", -12.5] ] }
```

Each entry in `rows` is a value array in the column order above. Respond `200` on success.

### GET a raw tab grid (`?sheet=`)
Request: `GET {webAppUrl}?apiKey={key}&sheet={tabName}`
Response: the tab's full used range as a raw 2-D array (`Date` cells become
ISO-8601 strings, blanks become `""`):

```json
{ "grid": [ ["환율", 1551.425, "", ...], ["Date", "Close", "", ...], ... ] }
```

## Dashboard tab — `DashboardDB1`

The Dashboard page reads **`DashboardDB1`** via `?sheet=DashboardDB1`. Every KPI
is **pre-computed by the spreadsheet** — the app only displays it, so the numbers
always match the sheet's own dashboard (the ⭐Dashboard tab's KPI cards are
Scorecard chart overlays and are *not* readable via the grid; `DashboardDB1` is
the readable mirror of those values).

`DashboardSummaryModel.fromGrid` locates values by **anchoring on the Korean
label text** (find the label cell, read the cell to its right) rather than fixed
coordinates, so inserting rows/columns in the sheet does not break parsing.

| Label (anchor) | Field | Unit | Offset from label |
| :-- | :-- | :-- | :-- |
| `환율` | `exchangeRate` | USD→KRW | +1 |
| `보유 USD 현금` | `usdCash` | USD | +1 |
| `보유 KRW 현금` | `krwCash` | KRW | +1 |
| `보유 미국 주식` | `usStocksUsd` | USD | +1 |
| `보유 한국 주식` | `krStocksKrw` | KRW | +1 |
| `총 보유 현금` | `totalCashUsd` / `totalCashKrw` | USD / KRW | +1 / +2 |
| `총 보유 주식` * | `totalStocksUsd` / `totalStocksKrw` | USD / KRW | +1 / +2 |
| `총 자산` | `totalAssetsUsd` / `totalAssetsKrw` | USD / KRW | +1 / +2 |
| `USD 투자 금액` | `usdInvested` | USD | +1 |
| `KRW 투자 금액` | `krwInvested` | KRW | +1 |
| `총 투자 금액 (in USD)` | `totalInvestedUsd` | USD | +1 |
| `총 투자 금액 (in KRW)` | `totalInvestedKrw` | KRW | +1 |
| `총 수익률` | `returnRate` | fraction (0.2865 = +28.65%) | +1 |

\* The live cell is `"총 보유 주식 "` (trailing space) — the finder compares
trimmed text.

**FX history:** the `Date` / `Close` columns hold a daily USD/KRW series. The
parser anchors on the `Close` header and reads down; the date is one column to
the left. Non-numeric `Close` cells are skipped — this drops blank rows and one
cell the sheet serialises as a bogus `1904-...` date string.

> **Net-worth scope:** `총 자산` = `총 보유 현금` + `총 보유 주식` only. Crypto
> (업비트/빗썸) and card debt live in the **`Accounts`** tab and are *not* in
> `DashboardDB1`'s totals. The **Accounts page** now lists the card and bank
> balances from that tab (see below), but it does not fold them into any
> net-worth figure — no total anywhere in the app combines the two tabs.

## Accounts tab — `Accounts`

Read via `?sheet=Accounts` and parsed by `SheetAccountModel.fromGrid`. **Read
only** — the app never appends to or edits this tab.

| Column | Read by the app? | Notes |
| :-- | :-- | :-- |
| `Account Name` | ✅ | Joined against a transaction row's Account column |
| `Type` | ✅ | `Credit` \| `Bank` \| `Brokerage` \| `Crypto`; matched case- and whitespace-insensitively by `SheetAccountList.ofType` |
| `Institution` | — | |
| `Currency` | ✅ | ISO code (`KRW`, `USD`); read upper-cased |
| `Include?` | — | |
| `Starting Balance` | — | |
| `Current Balance` | ✅ | Card debt / bank cash, listed by the Accounts page. Blank or unparseable reads as **null**, never 0 |
| `Normal Sign` | — | **Not read.** The app applies no sign convention of its own — see below |

The parser **anchors on the header text**, not on column letters: it finds the
`Account Name` cell, then the others in that same header row, so inserting a
column does not shift the mapping.

`Account Name` and `Currency` **gate** the parse — if either header is missing it
yields an empty list rather than an error, since the tab must never break the
Transactions page. `Type` and `Current Balance` are **optional**: a tab without
those headers still yields accounts (with a blank type and a null balance), so
adding them could not regress the currency labels that predate them.

**Currency display.** The Transactions list prefixes each row's amount with its
account's currency — `₩12,500` (no decimals) or `$1,234.56`. An unrecognized
code is prefixed literally (`EUR 12.5`). When the account is **absent from this
tab** or its `Currency` cell is **blank**, the amount renders as a bare,
unlabelled number — the same as before this tab was read at all. An unmarked row
is therefore a visible hint that the account is missing here. The formatter is
`money()` in `presentation/shared/utils/money.dart`, shared by the Transactions
list and the Accounts page so both label an amount identically.

The sheet mixes currencies in one `Amount` column, so the summary card's
Spending / Net invested totals still add KRW and USD together. Per-currency
totals are deliberately not implemented.

## Accounts page

Lists the `Accounts` tab's `Current Balance` for rows whose `Type` is **`Credit`**
(card debt) or **`Bank`** (cash on hand), grouped under two headings. `Brokerage`
and `Crypto` rows are omitted — brokerage holdings are already on the Dashboard.
A type the sheet spells any other way simply does not appear.

Costs **no extra network call**: `accountsProvider` is already fetched for the
currency labels above, and the page reads two more columns out of the same
cached grid. Read-only, like the rest of that tab.

> **Balances render exactly as the sheet stores them, sign included.** If column
> G holds a card balance as `-512300`, the app shows `₩-512,300`. There is no
> `abs()` and no sign flipping, so the `Normal Sign` column is not consulted —
> the same "don't guess" rule that makes an unknown currency render bare.

A blank `Current Balance` cell renders as an em dash, not `₩0` — 0 is a real
balance (a paid-off card) and must stay distinguishable from "the sheet
didn't say". There are no section totals: the page is a per-account list only.

## Account names
The add-row form's account picker is **derived from the Transactions tab** —
distinct values in the Account column, most-recently-used first
(`accountOptionsProvider`). The `Accounts` tab is *not* its source; it only
supplies currencies.
