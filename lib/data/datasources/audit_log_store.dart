import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/api_call_record.dart';
import '../../domain/repositories/i_audit_log.dart';
import '../models/api_call_record_model.dart';

/// Local audit log of every sheet-mutating API call (appends today), so the
/// user can reconcile app actions against the sheet when they mismatch.
/// Stored newest-first as one JSON array under [_key], capped at
/// [maxEntries] — the oldest entries are pruned.
///
/// Implements [IAuditLog] (the read side presentation depends on); [add] is
/// the write side, used only by `LoggingSheetsRepository` in the data layer.
class AuditLogStore implements IAuditLog {
  const AuditLogStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'audit.log.v1';
  static const maxEntries = 500;

  /// Records [record] at the head of the log, pruning beyond [maxEntries].
  void add(ApiCallRecord record) {
    final list = _readRawList()
      ..insert(0, ApiCallRecordModel.toJson(record));
    if (list.length > maxEntries) {
      list.removeRange(maxEntries, list.length);
    }
    _prefs.setString(_key, jsonEncode(list));
  }

  /// All recorded calls, newest first. Corrupt/unparseable stored JSON
  /// degrades to an empty list — the log must never crash the app.
  @override
  List<ApiCallRecord> records() {
    return [
      for (final e in _readRawList())
        if (e is Map) ApiCallRecordModel.fromJson(_stringKeyed(e)),
    ];
  }

  @override
  void clear() {
    _prefs.remove(_key);
  }

  /// The whole log as pretty-printed JSON (newest first), for the clipboard
  /// export on the History page.
  @override
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_readRawList());

  List<dynamic> _readRawList() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : [];
    } catch (e) {
      debugPrint('AuditLogStore: corrupt log discarded ($e)');
      return [];
    }
  }

  static Map<String, dynamic> _stringKeyed(Map m) =>
      m.map((k, v) => MapEntry(k.toString(), v));
}
