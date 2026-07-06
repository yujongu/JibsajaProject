import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/datasources/audit_log_store.dart';
import 'package:jibsaja/domain/entities/api_call_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiCallRecord _record(int n, {bool success = true}) => ApiCallRecord(
      timestamp: DateTime(2026, 7, 1).add(Duration(minutes: n)),
      operation: ApiOperation.append,
      sheetName: 'Test',
      rows: [
        ['2026-07-01', 'Toss', 'Expense', '식비', 'row $n', '', '', '', -n],
      ],
      summary: 'Expense 식비 −$n',
      success: success,
      httpStatus: success ? null : 500,
      detail: success ? null : 'Sheet returned 500: boom',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuditLogStore> emptyStore() async {
    SharedPreferences.setMockInitialValues({});
    return AuditLogStore(await SharedPreferences.getInstance());
  }

  group('AuditLogStore', () {
    test('round-trips a record with all fields intact', () async {
      final store = await emptyStore();
      store.add(_record(1, success: false));

      final all = store.records();
      expect(all, hasLength(1));
      final r = all.single;
      expect(r.timestamp, DateTime(2026, 7, 1, 0, 1));
      expect(r.operation, ApiOperation.append);
      expect(r.sheetName, 'Test');
      expect(r.rows, hasLength(1));
      expect(r.rows.single, hasLength(9));
      expect(r.rows.single[3], '식비');
      expect(r.rows.single[8], -1);
      expect(r.summary, 'Expense 식비 −1');
      expect(r.success, isFalse);
      expect(r.httpStatus, 500);
      expect(r.detail, 'Sheet returned 500: boom');
    });

    test('records() returns newest first', () async {
      final store = await emptyStore();
      store.add(_record(1));
      store.add(_record(2));
      store.add(_record(3));

      expect(store.records().map((r) => r.summary).toList(), [
        'Expense 식비 −3',
        'Expense 식비 −2',
        'Expense 식비 −1',
      ]);
    });

    test('prunes to the most recent 500 when 600 are added', () async {
      final store = await emptyStore();
      for (var n = 1; n <= 600; n++) {
        store.add(_record(n));
      }

      final all = store.records();
      expect(all, hasLength(500));
      // Newest kept at the head, oldest 100 pruned.
      expect(all.first.summary, 'Expense 식비 −600');
      expect(all.last.summary, 'Expense 식비 −101');
    });

    test('corrupt stored JSON degrades to an empty log, and stays writable',
        () async {
      SharedPreferences.setMockInitialValues({'audit.log.v1': '{not json'});
      final store = AuditLogStore(await SharedPreferences.getInstance());
      expect(store.records(), isEmpty);

      // Adding over a corrupt log replaces it cleanly.
      store.add(_record(7));
      expect(store.records(), hasLength(1));
    });

    test('a stored non-list JSON value degrades to empty', () async {
      SharedPreferences.setMockInitialValues({'audit.log.v1': '{"a": 1}'});
      final store = AuditLogStore(await SharedPreferences.getInstance());
      expect(store.records(), isEmpty);
    });

    test('clear empties the log', () async {
      final store = await emptyStore();
      store.add(_record(1));
      store.clear();
      expect(store.records(), isEmpty);
    });

    test('exportJson contains the recorded entries', () async {
      final store = await emptyStore();
      store.add(_record(42));
      final json = store.exportJson();
      expect(json, contains('Expense 식비 −42'));
      expect(json, contains('"operation": "append"'));
    });
  });
}
