/// The kind of sheet mutation an [ApiCallRecord] describes. Only appends are
/// produced today; update/delete exist so the audit log schema won't churn
/// when those operations arrive.
enum ApiOperation { append, update, delete }

extension ApiOperationX on ApiOperation {
  String get label {
    switch (this) {
      case ApiOperation.append: return 'Append';
      case ApiOperation.update: return 'Update';
      case ApiOperation.delete: return 'Delete';
    }
  }
}

/// One sheet-mutating API call as recorded in the local audit log, so the
/// user can reconcile what the app sent against what the sheet shows.
/// Reads (GETs) are never recorded. Pure Dart — JSON serialization lives in
/// `ApiCallRecordModel` (data layer), matching the codebase's model style.
class ApiCallRecord {
  const ApiCallRecord({
    required this.timestamp,
    required this.operation,
    required this.sheetName,
    required this.rows,
    required this.summary,
    required this.success,
    this.httpStatus,
    this.detail,
  });

  /// When the call was made (local time).
  final DateTime timestamp;

  final ApiOperation operation;

  /// The active profile's display name at call time ('Test' / 'Real').
  final String sheetName;

  /// The exact value arrays sent to the sheet (one inner list per row).
  final List<List<Object?>> rows;

  /// One-line human description, e.g. "Buy AAPL ×10" or "Expense 식비 −12.5".
  final String summary;

  final bool success;

  /// HTTP status when it could be determined; null otherwise.
  final int? httpStatus;

  /// Failure message / response snippet on error; null on success.
  final String? detail;
}
