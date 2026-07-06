import 'package:flutter/foundation.dart';

import '../../domain/entities/api_call_record.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/result.dart';
import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/i_sheets_repository.dart';
import '../datasources/audit_log_store.dart';
import '../models/sheet_transaction_model.dart';

/// Decorator over [ISheetsRepository] that records every sheet-**mutating**
/// call into the local [AuditLogStore]. Reads and cache lookups pass through
/// unlogged. Logging is strictly best-effort: a failing store must never
/// break the underlying call.
class LoggingSheetsRepository implements ISheetsRepository {
  const LoggingSheetsRepository({
    required this.delegate,
    required this.auditLog,
    required this.sheetName,
  });

  final ISheetsRepository delegate;
  final AuditLogStore auditLog;

  /// Display name of the active sheet profile at construction time
  /// ('Test' / 'Real') — stamped on every record.
  final String sheetName;

  // ── Reads: pass through, never logged ─────────────────────────────────────

  @override
  Future<Result<List<SheetTransaction>>> fetchTransactions() =>
      delegate.fetchTransactions();

  @override
  Future<Result<DashboardSummary>> fetchDashboard() =>
      delegate.fetchDashboard();

  @override
  List<SheetTransaction>? cachedTransactions() =>
      delegate.cachedTransactions();

  @override
  DashboardSummary? cachedDashboard() => delegate.cachedDashboard();

  @override
  DateTime? cachedTransactionsAt() => delegate.cachedTransactionsAt();

  @override
  DateTime? cachedDashboardAt() => delegate.cachedDashboardAt();

  // ── Mutations: delegate, then record ───────────────────────────────────────

  @override
  Future<Result<void>> appendTransaction(SheetTransaction tx) async {
    final result = await delegate.appendTransaction(tx);
    try {
      final detail = switch (result) {
        Success() => null,
        Failure(:final error) => error.toString(),
      };
      auditLog.add(ApiCallRecord(
        timestamp: DateTime.now(),
        operation: ApiOperation.append,
        sheetName: sheetName,
        rows: [
          for (final row in SheetTransactionModel.toRows(tx))
            List<Object?>.from(row),
        ],
        summary: summarize(tx),
        success: result.isSuccess,
        httpStatus: detail == null ? null : _parseHttpStatus(detail),
        detail: detail,
      ));
    } catch (e) {
      // Auditing must never break the append itself.
      debugPrint('LoggingSheetsRepository: failed to record append ($e)');
    }
    return result;
  }

  /// One-line human description of [tx] for the log list, e.g.
  /// "Buy AAPL ×10", "Expense 식비 −12.5", "Transfer Toss +300".
  @visibleForTesting
  static String summarize(SheetTransaction tx) {
    switch (tx.type) {
      case TransactionType.buy:
      case TransactionType.sell:
        final what = tx.ticker ?? tx.description;
        final qty = tx.quantity == null ? '' : ' ×${_num(tx.quantity!)}';
        return '${tx.type.label} $what$qty';
      case TransactionType.purchase:
        final cat = tx.category?.sheetValue;
        final label = cat == null || cat.isEmpty ? 'Expense' : 'Expense $cat';
        return '$label −${_num(tx.computedAmount)}';
      case TransactionType.transfer:
        final v = tx.amount;
        final amount = v == null ? '' : ' ${v < 0 ? '−' : '+'}${_num(v.abs())}';
        return 'Transfer ${tx.account}$amount';
    }
  }

  /// Compact number for a one-line summary: whole values print with no
  /// decimals ("27550"), fractional values are rounded to at most 4 places
  /// with trailing zeros stripped ("12.5"), so binary-float noise like
  /// 12.5000000001 or 27550.0 never leaks into the log.
  static String _num(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final fixed = v.toStringAsFixed(4);
    return fixed
        .replaceAll(RegExp(r'0+$'), '') // drop trailing zeros
        .replaceAll(RegExp(r'\.$'), ''); // and any dangling dot
  }

  /// The repository embeds the status in its failure message
  /// ("Sheet returned 500: ..."); recover it when present, else null.
  static int? _parseHttpStatus(String detail) {
    final m = RegExp(r'Sheet returned (\d{3})').firstMatch(detail);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}
