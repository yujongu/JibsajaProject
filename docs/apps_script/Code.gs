/**
 * Jibsaja — Google Apps Script web app backing the transactions sheet.
 *
 * Implements the contract in docs/data/sheets.md:
 *   GET  {webAppUrl}?apiKey=...               -> { "rows": [ {object-per-row}, ... ] }
 *   GET  {webAppUrl}?apiKey=...&sheet=Dashboard -> { "grid": [[row0col0, ...], ...] }
 *   POST {webAppUrl}  body:                   { "apiKey": "...", "rows": [ [v0..v8], ... ] }
 *
 * Column order (index 0..8):
 *   0 Date | 1 Account | 2 Type | 3 Category | 4 Description
 *   5 Ticker | 6 Quantity | 7 Price | 8 Amount
 *
 * DEPLOY: Extensions > Apps Script. Paste this as the ONLY code file (the
 *   project must contain exactly one doGet and one doPost), then Deploy >
 *   New deployment > Web app, "Execute as: Me", "Who has access: Anyone".
 *   Copy the URL that ends in /exec into AppConfig.sheetsWebAppUrl in
 *   lib/core/config/app_config.dart.
 *
 * REDEPLOY after editing: Deploy > Manage deployments > Edit (pencil) >
 *   Version: "New version" > Deploy. Editing the code alone does NOT update
 *   /exec — you must publish a new version.
 *
 * GOTCHAS (these cause "could not load data" in the app):
 *   - Use the /exec URL, NOT /dev. /dev is the test endpoint and requires you
 *     to be logged into Google, so the app (unauthenticated) gets a login page.
 *   - "Who has access" MUST be "Anyone", or the app gets a login page.
 *   - A missing/old doGet makes Google serve an HTML error page with HTTP 200;
 *     the app guards against this but the real fix is redeploying a new version.
 */

// ---- Config -----------------------------------------------------------------

// Tab name that holds the transactions. CHANGE THIS to match your sheet's tab
// (the link you shared points at gid=73810955 — set the tab's name here).
var SHEET_NAME = 'Transactions';

// Optional shared secret. Leave '' to disable the check. If set, it MUST match
// AppConfig.sheetsApiKey in the Flutter app.
var API_KEY = 'jibsaja-secret-2024-xk9m';

// Number of header rows to skip when reading (1 = a single header row).
var HEADER_ROWS = 1;

// Canonical keys, in column order. Used to build GET row objects.
var COLUMNS = [
  'date', 'account', 'type', 'category', 'description',
  'ticker', 'quantity', 'price', 'amount',
];

// ---- Entry points -----------------------------------------------------------

function doGet(e) {
  try {
    var params = (e && e.parameter) ? e.parameter : {};
    if (!authorized(params.apiKey)) {
      return json({ error: 'unauthorized' });
    }
    // ?sheet=<name> reads the named tab as a raw 2-D grid (used for Dashboard).
    if (params.sheet) {
      return json({ grid: readGrid(params.sheet) });
    }
    return json({ rows: readRows() });
  } catch (err) {
    return json({ error: String(err) });
  }
}

function doPost(e) {
  try {
    var body = {};
    if (e && e.postData && e.postData.contents) {
      body = JSON.parse(e.postData.contents);
    }
    if (!authorized(body.apiKey)) {
      return json({ error: 'unauthorized' });
    }

    var rows = body.rows || [];
    if (!Array.isArray(rows) || rows.length === 0) {
      return json({ error: 'no rows' });
    }

    var sheet = getSheet();
    // Append each value-array as a new row, normalising length to 9 columns.
    var normalized = rows.map(function (r) {
      var out = [];
      for (var i = 0; i < COLUMNS.length; i++) {
        out.push(i < r.length && r[i] !== undefined && r[i] !== null ? r[i] : '');
      }
      return out;
    });
    var startRow = sheet.getLastRow() + 1;
    sheet
      .getRange(startRow, 1, normalized.length, COLUMNS.length)
      .setValues(normalized);

    return json({ ok: true, appended: normalized.length });
  } catch (err) {
    return json({ error: String(err) });
  }
}

// ---- Helpers ----------------------------------------------------------------

/**
 * Reads every cell in [sheetName]'s used range and returns a 2-D array.
 * Row and column indices are 0-based. Empty cells are "".
 * Dates are serialised as ISO-8601 strings.
 */
function readGrid(sheetName) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) throw new Error('Sheet tab "' + sheetName + '" not found.');
  var range = sheet.getDataRange();
  var values = range.getValues();
  return values.map(function (row) {
    return row.map(function (v) { return cell(v); });
  });
}

function authorized(provided) {
  if (!API_KEY) return true; // check disabled
  return provided === API_KEY;
}

function getSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    throw new Error('Sheet tab "' + SHEET_NAME + '" not found.');
  }
  return sheet;
}

function readRows() {
  var sheet = getSheet();
  var lastRow = sheet.getLastRow();
  var firstDataRow = HEADER_ROWS + 1;
  if (lastRow < firstDataRow) return []; // no data rows

  var numRows = lastRow - HEADER_ROWS;
  var values = sheet
    .getRange(firstDataRow, 1, numRows, COLUMNS.length)
    .getValues();

  var rows = [];
  for (var i = 0; i < values.length; i++) {
    var row = values[i];
    // Skip fully blank rows.
    if (row.join('').toString().trim() === '') continue;

    var obj = {};
    for (var c = 0; c < COLUMNS.length; c++) {
      obj[COLUMNS[c]] = cell(row[c]);
    }
    rows.push(obj);
  }
  return rows;
}

// Normalise a cell value for JSON: Dates -> ISO-8601 string, others as-is.
function cell(v) {
  if (v instanceof Date) return v.toISOString();
  return v;
}

function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
