import '../../domain/entities/api_call_record.dart';

/// Maps an [ApiCallRecord] to/from the JSON shape persisted by
/// `AuditLogStore` — models own JSON, entities stay pure.
abstract final class ApiCallRecordModel {
  static Map<String, dynamic> toJson(ApiCallRecord r) => {
        'timestamp': r.timestamp.toIso8601String(),
        'operation': r.operation.name,
        'sheetName': r.sheetName,
        'rows': r.rows,
        'summary': r.summary,
        'success': r.success,
        if (r.httpStatus != null) 'httpStatus': r.httpStatus,
        if (r.detail != null) 'detail': r.detail,
      };

  static ApiCallRecord fromJson(Map<String, dynamic> json) {
    return ApiCallRecord(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      operation: ApiOperation.values.firstWhere(
        (o) => o.name == json['operation'],
        orElse: () => ApiOperation.append,
      ),
      sheetName: (json['sheetName'] ?? '').toString(),
      rows: [
        if (json['rows'] case final List rows)
          for (final row in rows)
            if (row is List) List<Object?>.from(row),
      ],
      summary: (json['summary'] ?? '').toString(),
      success: json['success'] == true,
      httpStatus: json['httpStatus'] is int ? json['httpStatus'] as int : null,
      detail: json['detail']?.toString(),
    );
  }
}
