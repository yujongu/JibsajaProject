# Google Sheet Schema & Backend Contract

The app's only backend is a **Google Apps Script web app** bound to a Google Sheet.
There is no Firebase. The app reads rows via `GET` and appends rows via `POST`.

Configure the endpoint in `lib/core/config/app_config.dart` (gitignored):

```dart
static const String sheetsWebAppUrl = 'https://script.google.com/.../exec';
static const String sheetsApiKey = ''; // optional shared secret
```

## Transactions tab — column layout

| Idx | Column      | Notes |
| :-- | :---------- | :---- |
| 0   | Date        | ISO-8601 string |
| 1   | Account     | Free text (e.g. "Robinhood", "BoA") |
| 2   | Type        | `Purchase` \| `Buy` \| `Sell` |
| 3   | Category    | Expense category (Purchase only), e.g. `food` |
| 4   | Description | Short note |
| 5   | Ticker      | Buy/Sell only |
| 6   | Quantity    | Buy/Sell only |
| 7   | Price       | Buy/Sell only |
| 8   | Amount      | Purchase: expense amount. Buy/Sell: quantity × price |

Column order is defined once in `SheetTransactionModel.columns`.

## Row types
- **Purchase** = a cash expense. Fields: date, account, category, description, amount.
- **Buy / Sell** = an asset trade. Fields: date, account, ticker, quantity, price.
  > ⚠️ Buy/Sell row composition is currently a **placeholder**
  > (`SheetTransactionModel._tradeRowsPlaceholder`). Replace it with the final
  > trade-row logic (e.g. companion cash-transfer leg) when decided.

## Apps Script contract

### GET (read)
Request: `GET {webAppUrl}?apiKey={key}`
Response (object-per-row keeps parsing resilient to column reordering):

```json
{
  "rows": [
    { "date": "2026-06-01T00:00:00.000", "account": "BoA", "type": "Purchase",
      "category": "food", "description": "Lunch", "ticker": "", "quantity": "",
      "price": "", "amount": 12.5 }
  ]
}
```

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
