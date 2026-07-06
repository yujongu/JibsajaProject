import '../entities/api_call_record.dart';

/// Read side of the local API audit log, as the presentation layer needs it.
/// Presentation depends on this interface, not the concrete datasource.
///
/// The write path (recording appends) is internal to the data layer — see
/// `LoggingSheetsRepository` — and is intentionally not exposed here.
abstract class IAuditLog {
  /// Every recorded sheet-mutating call, newest first.
  List<ApiCallRecord> records();

  /// Removes all recorded calls (does not touch the sheet).
  void clear();

  /// The whole log as pretty-printed JSON, for the clipboard export.
  String exportJson();
}
