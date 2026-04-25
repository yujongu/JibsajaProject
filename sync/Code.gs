// =============================================================================
// Jibsaja — Google Sheets → Firestore Sync (one direction only)
// =============================================================================
// The script ONLY reads the sheet and writes to Firestore.
// It NEVER modifies, deletes, or overwrites any sheet data
// (except writing the hidden Firestore doc ID to column I/J so it can
//  recognise the same row on future edits — this is metadata, not user data).
//
// Allowed operations:
//   • Add/update an account row   → creates/updates the Firestore account doc
//   • Add/update a transaction row → creates/updates the Firestore transaction doc
//
// Sheet columns:
//   Accounts:     A=Name, B=Type, C=Institution, D=Currency,
//                 E=Include?, F=Starting Balance, G=Current Balance,
//                 H=Normal Sign, I=_id (managed by this script)
//
//   Transactions: A=Date, B=Account, C=Type, D=Category, E=Description,
//                 F=Symbol, G=Quantity, H=Price, I=Amount,
//                 J=_id (managed by this script)
// =============================================================================

const CFG = {
  projectId: 'jibsaja-4a970',
  uid: 'NCsCIfc3LoMp6x1WF6KN4wWb0272',
};

// =============================================================================
// AUTH — Service Account JWT → Access Token
// =============================================================================

let _cachedToken = null;

function getAccessToken_() {
  if (_cachedToken) return _cachedToken;

  const props = PropertiesService.getScriptProperties();
  const raw = props.getProperty('SERVICE_ACCOUNT_KEY');
  if (!raw) throw new Error('SERVICE_ACCOUNT_KEY not set in Script Properties.');
  const key = JSON.parse(raw);

  const now = Math.floor(Date.now() / 1000);
  const header = Utilities.base64EncodeWebSafe(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' })
  );
  const claim = Utilities.base64EncodeWebSafe(
    JSON.stringify({
      iss: key.client_email,
      scope: 'https://www.googleapis.com/auth/datastore',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    })
  );
  const toSign = `${header}.${claim}`;
  const sig = Utilities.base64EncodeWebSafe(
    Utilities.computeRsaSha256Signature(toSign, key.private_key)
  );

  const resp = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    payload: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${toSign}.${sig}`,
    muteHttpExceptions: true,
  });
  const result = JSON.parse(resp.getContentText());
  if (!result.access_token) throw new Error('Token error: ' + resp.getContentText());
  _cachedToken = result.access_token;
  return _cachedToken;
}

// =============================================================================
// FIRESTORE HELPERS
// =============================================================================

// Full Firestore resource name for a path under the user's root.
function fsDocName_(path) {
  return `projects/${CFG.projectId}/databases/(default)/documents/users/${CFG.uid}/${path}`;
}

// Sends a single batch commit request to Firestore.
// Supports { update: ... } and { delete: "docName" } write objects.
function fsBatchCommit_(writes) {
  if (!writes.length) return;
  const url = `https://firestore.googleapis.com/v1/projects/${CFG.projectId}/databases/(default)/documents:commit`;
  UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: `Bearer ${getAccessToken_()}` },
    payload: JSON.stringify({ writes }),
    muteHttpExceptions: true,
  });
}

// Splits writes into chunks of chunkSize and commits each with a 2s sleep between.
// Use this for bulk imports to avoid hitting bandwidth rate limits.
function batchCommitChunked_(writes, chunkSize) {
  if (!writes.length) return;
  for (let i = 0; i < writes.length; i += chunkSize) {
    fsBatchCommit_(writes.slice(i, i + chunkSize));
    Logger.log(`  committed ${Math.min(i + chunkSize, writes.length)} / ${writes.length}`);
    if (i + chunkSize < writes.length) Utilities.sleep(2000);
  }
}

function fsBase_() {
  return `https://firestore.googleapis.com/v1/projects/${CFG.projectId}/databases/(default)/documents/users/${CFG.uid}`;
}

function fsGet_(path) {
  const resp = UrlFetchApp.fetch(`${fsBase_()}/${path}`, {
    headers: { Authorization: `Bearer ${getAccessToken_()}` },
    muteHttpExceptions: true,
  });
  if (resp.getResponseCode() === 404) return null;
  return JSON.parse(resp.getContentText());
}

// Fetches an entire collection in one request and returns { docId: fields }.
// Use this instead of calling fsGet_ in a loop.
function fsGetCollection_(collection) {
  const token = getAccessToken_();
  const docs  = {};
  let pageToken = null;
  do {
    let url = `${fsBase_()}/${collection}?pageSize=300`;
    if (pageToken) url += `&pageToken=${encodeURIComponent(pageToken)}`;
    const resp = UrlFetchApp.fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      muteHttpExceptions: true,
    });
    const body = JSON.parse(resp.getContentText());
    (body.documents || []).forEach(doc => {
      const id = doc.name.split('/').pop();
      docs[id] = doc.fields;
    });
    pageToken = body.nextPageToken || null;
  } while (pageToken);
  return docs;
}

function fsPatch_(path, fields) {
  UrlFetchApp.fetch(`${fsBase_()}/${path}`, {
    method: 'patch',
    contentType: 'application/json',
    headers: { Authorization: `Bearer ${getAccessToken_()}` },
    payload: JSON.stringify({ fields: toFsFields_(fields) }),
    muteHttpExceptions: true,
  });
}

// Patches only the specified fields on an existing document (uses updateMask).
function fsPatchPartial_(path, fields) {
  const mask = Object.keys(fields).map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  UrlFetchApp.fetch(`${fsBase_()}/${path}?${mask}`, {
    method: 'patch',
    contentType: 'application/json',
    headers: { Authorization: `Bearer ${getAccessToken_()}` },
    payload: JSON.stringify({ fields: toFsFields_(fields) }),
    muteHttpExceptions: true,
  });
}

function toFsFields_(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === null || v === undefined) {
      out[k] = { nullValue: null };
    } else if (typeof v === 'boolean') {
      out[k] = { booleanValue: v };
    } else if (typeof v === 'number') {
      out[k] = { doubleValue: v };
    } else if (v instanceof Date) {
      out[k] = { timestampValue: v.toISOString() };
    } else if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(v)) {
      out[k] = { timestampValue: v };
    } else {
      out[k] = { stringValue: String(v) };
    }
  }
  return out;
}

// =============================================================================
// UTILITIES
// =============================================================================

function parseNum_(val) {
  if (typeof val === 'number') return val;
  if (!val) return 0;
  return parseFloat(String(val).replace(/[^0-9.\-]/g, '')) || 0;
}

// Writes the Firestore doc ID to the sheet only if the cell is empty.
// This is the only write to the sheet — it's metadata, not user data.
function ensureId_(sheet, row, col) {
  const existing = sheet.getRange(row, col).getValue();
  if (existing) return String(existing);
  const newId = Utilities.getUuid();
  sheet.getRange(row, col).setValue(newId);
  return newId;
}

function now_() {
  return new Date().toISOString();
}

// =============================================================================
// ASSET TYPE DETECTION
// =============================================================================

const CRYPTO_SYMBOLS = new Set([
  'BTC','ETH','BNB','SOL','XRP','ADA','DOGE','MATIC','POL','DOT',
  'SHIB','AVAX','LINK','LTC','UNI','ATOM','XLM','ALGO','VET','ICP',
  'FIL','TRX','ETC','NEAR','APT','ARB','OP','SUI','SEI','INJ',
  'PEPE','WIF','BONK','TON','FLOKI','SAND','MANA','AXS','CRO','FTM',
  'AAVE','CAKE','GRT','MKR','SNX','LDO','STX','IMX','RUNE','EGLD',
]);

function guessAssetType_(symbol) {
  if (!symbol) return 'stock';
  return CRYPTO_SYMBOLS.has(symbol.toUpperCase()) ? 'crypto' : 'stock';
}

// =============================================================================
// ACCOUNT NAME → {id, currency} MAP  (reads sheet, does not modify it)
// =============================================================================

function buildAccountMap_(ss) {
  const sheet = ss.getSheetByName('Accounts');
  if (!sheet) return {};
  const rows = sheet.getDataRange().getValues();
  const map = {};
  for (let i = 1; i < rows.length; i++) {
    const name     = String(rows[i][0]).trim();
    const currency = String(rows[i][3]).trim() || 'KRW';
    const id       = String(rows[i][8]).trim(); // column I — Firestore ID
    if (name && id) map[name] = { id, currency };
  }
  return map;
}

// =============================================================================
// CATEGORY MAPPING
// =============================================================================

const SHEET_TO_APP_CATEGORY = {
  '식비': 'food',
  '교통': 'transport',
  '의류': 'shopping',
  '생필품': 'shopping',
  'Misc.': 'other',
  'Monthly': 'utilities',
  '웨딩': 'other',
  '경조사': 'other',
  'Fun': 'entertainment',
  'Work': 'salary',
};

// =============================================================================
// SHEET → FIRESTORE  (triggered on edit — never writes back to sheet)
// =============================================================================

function onSheetEdit(e) {
  const sheet = e.range.getSheet();
  const name  = sheet.getName();
  const row   = e.range.getRow();
  if (row <= 1) return; // skip header

  const ss = SpreadsheetApp.getActiveSpreadsheet();

  if (name === 'Accounts') {
    syncAccountRow_(sheet, row);
  } else if (name === 'Transactions') {
    syncTransactionRow_(sheet, row, buildAccountMap_(ss));
  }
}

// ── Account row → Firestore ───────────────────────────────────────────────────

function syncAccountRow_(sheet, row) {
  const write = buildAccountWrite_(sheet, row);
  if (write) fsPatch_(write.path, write.fields);
}

function buildAccountWrite_(sheet, row) {
  const vals = sheet.getRange(row, 1, 1, 9).getValues()[0];
  const [name, type, , currency, , startingBal, currentBal, , existingId] = vals;
  if (!name) return null;

  const id             = existingId ? String(existingId) : ensureId_(sheet, row, 9);
  const initialBalance = parseNum_(startingBal);
  const balance        = parseNum_(currentBal);
  const ts             = now_();

  if (String(type) === 'Credit') {
    return {
      path: `cards/${id}`,
      fields: {
        id, userId: CFG.uid,
        name: String(name),
        last4Digits: '0000',
        type: 'credit',
        network: 'local',
        balance: Math.abs(balance),
        currency: String(currency) || 'KRW',
        createdAt: ts, updatedAt: ts,
      },
    };
  } else {
    const appType = (['Brokerage', 'Crypto'].includes(String(type))) ? 'investment' : 'checking';
    const isLiquid = appType !== 'investment';
    return {
      path: `accounts/${id}`,
      fields: {
        id, userId: CFG.uid,
        name: String(name),
        type: appType,
        balance: isLiquid ? 0 : balance,
        initialBalance: isLiquid ? initialBalance : 0,
        currency: String(currency) || 'KRW',
        createdAt: ts, updatedAt: ts,
      },
    };
  }
}

// ── Transaction row → Firestore ───────────────────────────────────────────────

function syncTransactionRow_(sheet, row, accountMap) {
  const vals = sheet.getRange(row, 1, 1, 10).getValues()[0];
  const [date, accountName, type, category, description,
         symbol, qty, price, amount, existingId] = vals;

  if (!date || !type) return;

  const sheetType = String(type).trim();
  const id  = existingId ? String(existingId) : ensureId_(sheet, row, 10);
  const ts  = now_();
  const txDate = (date instanceof Date ? date : new Date(date)).toISOString();

  if (sheetType === 'Buy' || sheetType === 'Sell') {
    syncTradeRow_(id, txDate, accountName, sheetType,
                  description, symbol, qty, price, amount, accountMap, ts);
  } else if (sheetType === 'Expense' || sheetType === 'Deposit') {
    syncRegularRow_(id, txDate, sheetType, category, description, amount, accountName, accountMap, ts);
  } else if (sheetType === 'Transfer') {
    syncTransferRow_(id, txDate, accountName, amount, accountMap, ts);
  }
  // Any other type (e.g. formulas, blank) is silently ignored.
}

function syncTradeRow_(id, txDate, accountName, sheetType, description,
                       symbol, qty, price, amount, accountMap, ts) {
  const sym = String(symbol || '').trim().toUpperCase();
  if (!sym) return;

  const qtyVal   = parseNum_(qty);
  const priceVal = parseNum_(price);
  const amtVal   = parseNum_(amount) || Math.abs(qtyVal * priceVal);

  const acc       = accountMap[String(accountName).trim()] || {};
  const accountId = acc.id   || null;
  const currency  = acc.currency || 'KRW';

  fsPatch_(`transactions/${id}`, {
    id,
    userId: CFG.uid,
    accountId,
    title: `${sheetType} ${sym}`,
    amount: Math.abs(amtVal),
    type: sheetType === 'Buy' ? 'buy' : 'sell',
    category: 'investment',
    date: txDate,
    note: null,
    currency,
    ticker: sym,
    assetName: String(description || sym).trim(),
    assetType: guessAssetType_(sym),
    quantity: Math.abs(qtyVal),
    pricePerUnit: priceVal,
    createdAt: ts,
    updatedAt: ts,
  });
}

function syncRegularRow_(id, txDate, sheetType, category, description, amount, accountName, accountMap, ts) {
  const amountVal = parseNum_(amount);
  const acc = (accountMap && accountName)
    ? (accountMap[String(accountName).trim()] || {})
    : {};
  fsPatch_(`transactions/${id}`, {
    id,
    userId: CFG.uid,
    accountId: acc.id || null,
    title: String(description || category || sheetType).trim() || 'Transaction',
    amount: Math.abs(amountVal),
    type: sheetType === 'Deposit' ? 'income' : 'expense',
    category: SHEET_TO_APP_CATEGORY[String(category)] || 'other',
    date: txDate,
    note: '',
    currency: acc.currency || 'KRW',
    ticker: null,
    assetName: null,
    assetType: null,
    quantity: null,
    pricePerUnit: null,
    createdAt: ts,
    updatedAt: ts,
  });
}

// Stores a Transfer row as a transaction record (positive = credit in, negative = debit out).
function syncTransferRow_(id, txDate, accountName, amount, accountMap, ts) {
  const acc = accountMap[String(accountName).trim()];
  if (!acc || !acc.id) {
    Logger.log(`Transfer: account "${accountName}" not found in map`);
    return;
  }
  const amtVal = parseNum_(amount);
  const isDebit = amtVal < 0;
  fsPatch_(`transactions/${id}`, {
    id,
    userId: CFG.uid,
    accountId: acc.id,
    type: 'transfer',
    isDebit,
    title: isDebit ? 'Transfer Out' : 'Transfer In',
    amount: Math.abs(amtVal),
    category: 'other',
    date: txDate,
    note: null,
    currency: acc.currency || 'KRW',
    ticker: null, assetName: null, assetType: null,
    quantity: null, pricePerUnit: null,
    createdAt: ts, updatedAt: ts,
  });
}

// =============================================================================
// IMPORT ALL TRANSFERS — one-time bulk sync of existing Transfer rows
// =============================================================================

// Imports all Transfer rows as transaction records in Firestore.
// Each row becomes one transfer transaction (positive = credit, negative = debit).
function importAllTransfers() {
  const ss      = SpreadsheetApp.getActiveSpreadsheet();
  const txSheet = ss.getSheetByName('Transactions');
  if (!txSheet) { Logger.log('Transactions sheet not found'); return; }

  const accountMap = buildAccountMap_(ss);
  const rows       = txSheet.getDataRange().getValues();
  const writes     = [];
  let processed = 0, skipped = 0;

  for (let i = 1; i < rows.length; i++) {
    const [date, accountName, type, , , , , , amount, existingId] = rows[i];
    if (String(type).trim() !== 'Transfer') { skipped++; continue; }
    if (!accountName || amount === '' || amount === 0) { skipped++; continue; }

    const acc = accountMap[String(accountName).trim()];
    if (!acc || !acc.id) { Logger.log(`Transfer: account "${accountName}" not found`); skipped++; continue; }

    const id     = existingId ? String(existingId) : Utilities.getUuid();
    if (!existingId) txSheet.getRange(i + 1, 10).setValue(id);

    const amtVal  = parseNum_(amount);
    const isDebit = amtVal < 0;
    const ts      = now_();
    const txDate  = (date instanceof Date ? date : new Date(date)).toISOString();

    writes.push({
      update: {
        name: fsDocName_(`transactions/${id}`),
        fields: toFsFields_({
          id, userId: CFG.uid, accountId: acc.id,
          type: 'transfer',
          isDebit,
          title: isDebit ? 'Transfer Out' : 'Transfer In',
          amount: Math.abs(amtVal),
          category: 'other',
          date: txDate, note: null,
          currency: acc.currency || 'KRW',
          ticker: null, assetName: null, assetType: null,
          quantity: null, pricePerUnit: null,
          createdAt: ts, updatedAt: ts,
        }),
      },
    });
    processed++;
  }

  batchCommitChunked_(writes, 50);
  SpreadsheetApp.getUi().alert(`Done! ${processed} Transfer rows imported as transactions (${skipped} skipped).`);
}

// =============================================================================
// IMPORT ALL TRADES — one-time bulk import of existing Buy/Sell rows
// =============================================================================

function importAllTrades() {
  const ss      = SpreadsheetApp.getActiveSpreadsheet();
  const txSheet = ss.getSheetByName('Transactions');
  if (!txSheet) { Logger.log('Transactions sheet not found'); return; }

  const accountMap = buildAccountMap_(ss);
  const rows       = txSheet.getDataRange().getValues();
  const writes     = [];
  let skipped      = 0;

  for (let i = 1; i < rows.length; i++) {
    const [date, accountName, type, , description, symbol, qty, price, amount, existingId] = rows[i];
    const sheetType = String(type || '').trim();

    if (sheetType !== 'Buy' && sheetType !== 'Sell') { skipped++; continue; }
    if (!symbol && !description)                      { skipped++; continue; }

    const id     = existingId ? String(existingId) : Utilities.getUuid();
    const ts     = now_();
    const txDate = (date instanceof Date ? date : new Date(date)).toISOString();

    if (!existingId) txSheet.getRange(i + 1, 10).setValue(id);

    const sym      = String(symbol || '').trim().toUpperCase();
    const qtyVal   = parseNum_(qty);
    const priceVal = parseNum_(price);
    const amtVal   = parseNum_(amount) || Math.abs(qtyVal * priceVal);
    const acc      = accountMap[String(accountName).trim()] || {};

    writes.push({
      update: {
        name: fsDocName_(`transactions/${id}`),
        fields: toFsFields_({
          id, userId: CFG.uid, accountId: acc.id || null,
          title: `${sheetType} ${sym}`, amount: Math.abs(amtVal),
          type: sheetType === 'Buy' ? 'buy' : 'sell',
          category: 'investment', date: txDate, note: null,
          currency: acc.currency || 'KRW', ticker: sym,
          assetName: String(description || sym).trim(),
          assetType: guessAssetType_(sym),
          quantity: Math.abs(qtyVal), pricePerUnit: priceVal,
          createdAt: ts, updatedAt: ts,
        }),
      },
    });
  }

  batchCommitChunked_(writes, 50);
  Logger.log(`importAllTrades: ${writes.length} imported, ${skipped} skipped`);
  SpreadsheetApp.getUi().alert(`Done! ${writes.length} trades imported into Firestore.`);
}

// =============================================================================
// INITIAL SYNC — seeds Firestore from sheet (run once)
// =============================================================================

function initialSync() {
  const ss            = SpreadsheetApp.getActiveSpreadsheet();
  const accountsSheet = ss.getSheetByName('Accounts');

  // Read ALL account rows in one Sheets API call
  const allRows = accountsSheet.getDataRange().getValues();
  const writes  = [];

  for (let i = 1; i < allRows.length; i++) {
    const [name, type, , currency, , startingBal, currentBal, , existingId] = allRows[i];
    if (!name) continue;

    const id             = existingId ? String(existingId) : ensureId_(accountsSheet, i + 1, 9);
    const initialBalance = parseNum_(startingBal);
    const balance        = parseNum_(currentBal);
    const ts             = now_();
    let path, fields;

    if (String(type) === 'Credit') {
      path   = `cards/${id}`;
      fields = {
        id, userId: CFG.uid, name: String(name),
        last4Digits: '0000', type: 'credit', network: 'local',
        balance: Math.abs(balance), currency: String(currency) || 'KRW',
        createdAt: ts, updatedAt: ts,
      };
    } else {
      const appType  = (['Brokerage', 'Crypto'].includes(String(type))) ? 'investment' : 'checking';
      const isLiquid = appType !== 'investment';
      path   = `accounts/${id}`;
      fields = {
        id, userId: CFG.uid, name: String(name),
        type: appType,
        balance: isLiquid ? 0 : balance,
        initialBalance: isLiquid ? initialBalance : 0,
        currency: String(currency) || 'KRW',
        createdAt: ts, updatedAt: ts,
      };
    }
    writes.push({ update: { name: fsDocName_(path), fields: toFsFields_(fields) } });
  }

  batchCommitChunked_(writes, 50);
  Logger.log(`Committed ${writes.length} account/card rows`);

  fsPatch_('settings/sync', { enabled: true, lastSyncedAt: now_() });
  Logger.log('Accounts synced — run initialSyncTransactions(2) to sync transactions');
}

// Reads ALL transaction rows at once and commits in small chunks.
// Transfer rows handled separately (require read-before-write).
function initialSyncTransactions(startRow) {
  const ss         = SpreadsheetApp.getActiveSpreadsheet();
  const txSheet    = ss.getSheetByName('Transactions');
  const accountMap = buildAccountMap_(ss);

  if (!startRow) startRow = 2;
  const lastRow = txSheet.getLastRow();
  if (startRow > lastRow) { Logger.log('No rows to process.'); return; }

  // Read ALL rows in one Sheets API call
  const allVals = txSheet.getRange(startRow, 1, lastRow - startRow + 1, 10).getValues();
  const writes  = [];

  for (let i = 0; i < allVals.length; i++) {
    const [date, accountName, type, category, description,
           symbol, qty, price, amount, existingId] = allVals[i];
    if (!date || !type) continue;

    const sheetType = String(type).trim();
    const id        = existingId ? String(existingId) : ensureId_(txSheet, startRow + i, 10);
    const ts        = now_();
    const txDate    = (date instanceof Date ? date : new Date(date)).toISOString();

    let fields;

    if (sheetType === 'Buy' || sheetType === 'Sell') {
      const sym      = String(symbol || '').trim().toUpperCase();
      if (!sym) continue;
      const qtyVal   = parseNum_(qty);
      const priceVal = parseNum_(price);
      const amtVal   = parseNum_(amount) || Math.abs(qtyVal * priceVal);
      const acc      = accountMap[String(accountName).trim()] || {};
      fields = {
        id, userId: CFG.uid, accountId: acc.id || null,
        title: `${sheetType} ${sym}`, amount: Math.abs(amtVal),
        type: sheetType === 'Buy' ? 'buy' : 'sell',
        category: 'investment', date: txDate, note: null,
        currency: acc.currency || 'KRW', ticker: sym,
        assetName: String(description || sym).trim(),
        assetType: guessAssetType_(sym),
        quantity: Math.abs(qtyVal), pricePerUnit: priceVal,
        createdAt: ts, updatedAt: ts,
      };
    } else if (sheetType === 'Expense' || sheetType === 'Deposit') {
      const amountVal = parseNum_(amount);
      const acc = accountMap[String(accountName).trim()] || {};
      fields = {
        id, userId: CFG.uid, accountId: acc.id || null,
        title: String(description || category || sheetType).trim() || 'Transaction',
        amount: Math.abs(amountVal),
        type: sheetType === 'Deposit' ? 'income' : 'expense',
        category: SHEET_TO_APP_CATEGORY[String(category)] || 'other',
        date: txDate, note: '', currency: acc.currency || 'KRW',
        ticker: null, assetName: null, assetType: null,
        quantity: null, pricePerUnit: null,
        createdAt: ts, updatedAt: ts,
      };
    } else if (sheetType === 'Transfer') {
      // Store each Transfer row as a transaction record (not a balance mutation).
      const amtVal  = parseNum_(amount);
      if (!amtVal) continue;
      const acc     = accountMap[String(accountName).trim()] || {};
      const isDebit = amtVal < 0;
      fields = {
        id, userId: CFG.uid, accountId: acc.id || null,
        type: 'transfer',
        isDebit,
        title: isDebit ? 'Transfer Out' : 'Transfer In',
        amount: Math.abs(amtVal),
        category: 'other',
        date: txDate, note: null,
        currency: acc.currency || 'KRW',
        ticker: null, assetName: null, assetType: null,
        quantity: null, pricePerUnit: null,
        createdAt: ts, updatedAt: ts,
      };
    } else {
      continue;
    }

    writes.push({ update: { name: fsDocName_(`transactions/${id}`), fields: toFsFields_(fields) } });
  }

  batchCommitChunked_(writes, 50);
  Logger.log(`✓ Committed ${writes.length} transactions (including transfers)`);
}

// =============================================================================
// ONE-TIME CLEANUP — delete all docs in a collection (run manually, then remove)
// =============================================================================

function fsDelete_(path) {
  UrlFetchApp.fetch(`${fsBase_()}/${path}`, {
    method: 'delete',
    headers: { Authorization: `Bearer ${getAccessToken_()}` },
    muteHttpExceptions: true,
  });
}

function fsListIds_(collection) {
  const token = getAccessToken_();
  const ids = [];
  let pageToken = null;

  do {
    let url = `${fsBase_()}/${collection}?pageSize=300&mask.fieldPaths=__name__`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const resp = UrlFetchApp.fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      muteHttpExceptions: true,
    });
    const body = JSON.parse(resp.getContentText());
    if (body.documents) {
      body.documents.forEach(doc => {
        ids.push(doc.name.split('/').pop());
      });
    }
    pageToken = body.nextPageToken || null;
  } while (pageToken);

  return ids;
}

function clearCollection_(collection) {
  const ids = fsListIds_(collection);
  if (!ids.length) return 0;
  const writes = ids.map(id => ({ delete: fsDocName_(`${collection}/${id}`) }));
  batchCommitChunked_(writes, 50);
  Logger.log(`Cleared ${ids.length} docs from ${collection}`);
  return ids.length;
}

// Run this once to wipe transactions, then re-run importAllTrades.
// Remove or comment out after use.
function clearTransactions() {
  const ui = SpreadsheetApp.getUi();
  const confirm = ui.alert(
    'Confirm Delete',
    'This will permanently delete ALL transaction documents from Firestore. Continue?',
    ui.ButtonSet.YES_NO
  );
  if (confirm !== ui.Button.YES) { Logger.log('Cancelled.'); return; }

  const n = clearCollection_('transactions');
  ui.alert(`Done. ${n} transaction documents deleted.`);
}

// Optionally also clear accounts and cards:
function clearAll() {
  const ui = SpreadsheetApp.getUi();
  const confirm = ui.alert(
    'Confirm Delete ALL',
    'This will permanently delete ALL accounts, cards, and transactions from Firestore. Continue?',
    ui.ButtonSet.YES_NO
  );
  if (confirm !== ui.Button.YES) { Logger.log('Cancelled.'); return; }

  const tx  = clearCollection_('transactions');
  const ac  = clearCollection_('accounts');
  const cd  = clearCollection_('cards');
  const hd  = clearCollection_('holdings');
  ui.alert(`Done.\nTransactions: ${tx}\nAccounts: ${ac}\nCards: ${cd}\nHoldings: ${hd}`);
}

// =============================================================================
// WEB APP — receives POST requests from the Flutter app to append rows
// =============================================================================
//
// Deploy this script as a web app:
//   1. Apps Script → Deploy → New Deployment → Web App
//   2. Execute as: Me  |  Who has access: Anyone
//   3. Copy the URL into SheetsApiService.webAppUrl in the Flutter app
//   4. Add Script Property JIBSAJA_API_KEY with a secret string
//   5. Set the same string in SheetsApiService.apiKey in the Flutter app
//
// Expected POST body (JSON):
//   { "apiKey": "...", "rows": [[col_A, col_B, ..., col_J], ...] }
// =============================================================================

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);

    // API key guard
    const expectedKey = PropertiesService.getScriptProperties().getProperty('JIBSAJA_API_KEY');
    if (expectedKey && payload.apiKey !== expectedKey) {
      return jsonResponse_({ error: 'Unauthorized' });
    }

    const ss      = SpreadsheetApp.getActiveSpreadsheet();
    const txSheet = ss.getSheetByName('Transactions');
    if (!txSheet) return jsonResponse_({ error: 'Transactions sheet not found' });

    let count = 0;
    for (const row of (payload.rows || [])) {
      // Convert ISO date string in column 0 back to a Date so Sheets formats it correctly
      const rowData = row.map((v, idx) => {
        if (idx === 0 && typeof v === 'string' && v.includes('T')) return new Date(v);
        return v;
      });
      txSheet.appendRow(rowData);
      count++;
    }

    return jsonResponse_({ success: true, appended: count });
  } catch (err) {
    return jsonResponse_({ error: err.toString() });
  }
}

function jsonResponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// =============================================================================
// TRIGGER SETUP — run once
// =============================================================================

function setupTriggers() {
  ScriptApp.getProjectTriggers().forEach(t => ScriptApp.deleteTrigger(t));

  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // onEdit: Sheet → Firestore only (no time-based pull trigger needed)
  ScriptApp.newTrigger('onSheetEdit')
    .forSpreadsheet(ss)
    .onEdit()
    .create();

  Logger.log('Trigger installed: onSheetEdit (Sheet → Firestore only).');
}
