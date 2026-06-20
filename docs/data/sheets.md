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
| 2   | Type        | `Purchase` \| `Buy` \| `Sell` |
| 3   | Category    | Expense category (Purchase only), e.g. `food` |
| 4   | Description | Short note |
| 5   | Symbol      | Ticker symbol, Buy/Sell only |
| 6   | Quantity    | Buy/Sell only |
| 7   | Price       | Buy/Sell only |
| 8   | Amount      | Purchase: expense amount. Buy/Sell: quantity × price |

`SheetTransactionModel.columns` documents this POST value-array order (informational). The POST builder (`toRows`) writes positions directly; the GET parser reads object keys case-insensitively and does not use `columns`.

## Row types
- **Purchase** = a cash expense. Fields: date, account, category, description, amount.
- **Buy / Sell** = an asset trade. Fields: date, account, symbol, quantity, price.
  > ⚠️ Buy/Sell row composition is currently a **placeholder**
  > (`SheetTransactionModel._tradeRowsPlaceholder`). Replace it with the final
  > trade-row logic (e.g. companion cash-transfer leg) when decided.

## Apps Script contract

### GET (read)
Request: `GET {webAppUrl}?apiKey={key}`
Response (object-per-row keeps parsing resilient to column reordering). The live
sheet returns **capitalized** header keys and names the ticker column `Symbol`:

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

A bare top-level JSON array is also accepted.

### POST (append)
Request: `POST {webAppUrl}` with body:

```json
{ "apiKey": "…", "rows": [ ["2026-06-01T...", "BoA", "Purchase", "food", "Lunch", "", "", "", 12.5] ] }
```

Each entry in `rows` is a value array in the column order above. Respond `200` on success.

## Account names
The add-row form's account dropdown is **derived from the sheet** — distinct values
in the Account column (`accountNamesProvider`). Free-text entry is allowed for new accounts.
