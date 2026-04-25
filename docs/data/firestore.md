# Firestore Schema Definition

## Collections

### 👥 users (Root Collection)
| Field | Type | Description |
| :--- | :--- | :--- |
| uid | String (ID) | Firebase Auth UID |
| email | String | User's primary email |
| created_at | Timestamp | Account creation date |

#### Example Document Path : /users/\{uid\}

### 💳 accounts (Subcollection under users/\{uid\})
| Field | Type | Description |
| :--- | :--- | :--- |
| id | String (ID) | Unique ID for this specific account (document ID) |
| name | String | User inputted name for the account (e.g., "Robinhood acc", "My BoA Account") |
| type | String | Type of account (e.g., "Bank", "Brokerage", "Crypto", "Credit") |
| institution | String | Bank institution name (e.g., "Robinhood", "BoA", "Chase") |
| currency | String | Currency code (e.g., "USD", "KRW") |
| initialBalance | Number | The balance when the account was first created |
| createdAt | Timestamp | Timestamp when the account was created |
| updatedAt | Timestamp | Last timestamp the account was modified |
| userId | String | Reference to the parent user's UID |

#### Example Document Path : /users/\{uid\}/accounts/\{accountId\}



### 💸 transactions (Subcollection under users/\{uid\})
| Field | Type | Description |
| :--- | :--- | :--- |
| id | String (ID) | Unique ID for this specific transaction (document ID) |
| date | Timestamp | Date the transaction occurred |
| account_id | String (Ref) | FK to the accounts subcollection where this transaction belongs |
| type | String | Type of transaction (e.g., "Deposit", "Expense", "Transfer", "Buy", "Sell") |
| category | String | Transaction category when Type is Expense (e.g., "Monthly", "Transportation", "Food", "Essentials", "Clothes", "Fun", "Misc") |
| description | String | Short description of the transaction |
| ticker | String | Ticker symbol when Type is Buy or Sell |
| quantity | Number | Quantity of stock/crypto purchased when Type is Buy or Sell |
| price | Number | Price of the purchased stock when Type is Buy or Sell |
| created_at | Timestamp | Timestamp when the transaction record was created |
| updated_at | Timestamp | Last timestamp the transaction record was modified |
#### Example Document Path : /users/\{uid\}/transactions/\{transactionId\}


## 🔗 Relationships
- **User -> Accounts**: 1:N relationship. Each user can have multiple accounts.
- **User -> Transactions**: 1:N relationship. Each user can have multiple transactions.
- **Account -> Transactions**: 1:N relationship. Each account can have multiple transactions.

