import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/audit_log_store.dart';
import '../../domain/entities/api_call_record.dart';
import '../../domain/repositories/i_audit_log.dart';
import 'preferences_providers.dart';

/// Concrete persistence for the audit log. The write path
/// (`LoggingSheetsRepository`) needs the concrete `add`; presentation only
/// ever sees it through [auditLogProvider] as an [IAuditLog].
final auditLogStoreProvider = Provider<AuditLogStore>(
  (ref) => AuditLogStore(ref.watch(sharedPreferencesProvider)),
);

/// The audit log as the read-side domain interface — presentation depends on
/// this, not the datasource. Use it for `clear()` / `exportJson()`.
final auditLogProvider = Provider<IAuditLog>(
  (ref) => ref.watch(auditLogStoreProvider),
);

/// The recorded API calls, newest first. `autoDispose` so each visit to the
/// History page re-reads from storage (appends made since the last visit
/// show up); refresh explicitly with `ref.invalidate(auditLogRecordsProvider)`
/// after a Clear.
final auditLogRecordsProvider = Provider.autoDispose<List<ApiCallRecord>>(
  (ref) => ref.watch(auditLogProvider).records(),
);
