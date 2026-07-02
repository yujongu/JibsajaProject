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
| 2   | Type        | `Expense` \| `Buy` \| `Sell` \| `Transfer` (the app labels the Expense flow "Purchase") |
| 3   | Category    | Expense rows only. One of: `Monthly`, `교통`, `식비`, `생필품`, `의류`, `Fun`, `배달음식`, `Misc.`, `Work`, `경조사`, `웨딩`, `여행` |
| 4   | Description | Short note |
| 5   | Symbol      | Ticker symbol, Buy/Sell only |
| 6   | Quantity    | Buy/Sell only. **Signed** — Sell rows store a negative quantity |
| 7   | Price       | Buy/Sell only, always positive |
| 8   | Amount      | **Signed.** Expense: **−amount** (cash out). Buy/Sell: quantity × price (Sell negative via its quantity). Transfer: − = cash out, + = cash in |

`SheetTransactionModel.columns` documents this POST value-array order (informational). The POST builder (`toRows`) writes positions directly; the GET parser reads object keys case-insensitively and does not use `columns`.

## Row types
- **Purchase** (stored Type: `Expense`) = a cash expense. **One row.** Fields:
  date, account, category, description, amount — Amount is written
  **negative** (cash out). Reading is lenient: both `Expense` and the legacy
  `Purchase` parse back to the app's Purchase type.
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
- **Transfer** = a cash movement between accounts. Never entered directly in
  the app — only generated as the cash leg above.

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
> `DashboardDB1`'s totals. To include them later, read `?sheet=Accounts`
> (columns: `Account Name | Type | Institution | Currency | Include? | Starting
> Balance | Current Balance | Normal Sign`) and sum `Current Balance` by `Type`.

## Account names
The add-row form's account dropdown is **derived from the sheet** — distinct values
in the Account column (`accountNamesProvider`). Free-text entry is allowed for new accounts.
