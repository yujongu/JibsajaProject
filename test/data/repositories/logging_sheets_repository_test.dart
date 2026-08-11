import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/datasources/audit_log_store.dart';
import 'package:jibsaja/data/models/sheet_transaction_model.dart';
import 'package:jibsaja/data/repositories/logging_sheets_repository.dart';
import 'package:jibsaja/domain/entities/api_call_record.dart';
import 'package:jibsaja/domain/entities/dashboard_summary.dart';
import 'package:jibsaja/domain/entities/result.dart';
import 'package:jibsaja/domain/entities/sheet_account.dart';
import 'package:jibsaja/domain/entities/sheet_holding.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_sheets_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDelegate implements ISheetsRepository {
  _FakeDelegate({this.appendResult = const Success(null)});

  final Result<void> appendResult;
  int appendCalls = 0;

  @override
  Future<Result<void>> appendTransaction(SheetTransaction tx) async {
    appendCalls++;
    return appendResult;
  }

  @override
  Future<Result<List<SheetTransaction>>> fetchTransactions() async =>
      const Success([]);
  @override
  Future<Result<DashboardSummary>> fetchDashboard() async =>
      const Failure('unused');
  @override
  Future<Result<List<SheetAccount>>> fetchAccounts() async =>
      const Success([SheetAccount(name: 'Toss', currency: 'KRW')]);
  @override
  List<SheetTransaction>? cachedTransactions() => null;
  @override
  DashboardSummary? cachedDashboard() => null;
  @override
  List<SheetAccount>? cachedAccounts() => null;
  @override
  DateTime? cachedTransactionsAt() => null;
  @override
  DateTime? cachedDashboardAt() => null;
  @override
  DateTime? cachedAccountsAt() => null;
  @override
  Future<Result<List<SheetHolding>>> fetchHoldings() async =>
      const Success([SheetHolding(symbol: 'NVDA', currency: 'USD')]);
  @override
  List<SheetHolding>? cachedHoldings() => null;
  @override
  DateTime? cachedHoldingsAt() => null;
}

class _ThrowingStore extends AuditLogStore {
  const _ThrowingStore(super.prefs);
  @override
  void add(ApiCallRecord record) => throw StateError('disk on fire');
}

SheetTransaction _buyTx() => SheetTransaction(
      date: DateTime(2026, 7, 1),
      account: 'Toss',
      secondAccount: 'Broker',
      type: TransactionType.buy,
      ticker: 'AAPL',
      quantity: 10,
      price: 2.5,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuditLogStore> emptyStore() async {
    SharedPreferences.setMockInitialValues({});
    return AuditLogStore(await SharedPreferences.getInstance());
  }

  group('LoggingSheetsRepository', () {
    test('a successful append records a success entry with the exact rows',
        () async {
      final store = await emptyStore();
      final repo = LoggingSheetsRepository(
        delegate: _FakeDelegate(),
        auditLog: store,
        sheetName: 'Test',
      );
      final tx = _buyTx();

      final result = await repo.appendTransaction(tx);
      expect(result.isSuccess, isTrue);

      final all = store.records();
      expect(all, hasLength(1));
      final r = all.single;
      expect(r.operation, ApiOperation.append);
      expect(r.sheetName, 'Test');
      expect(r.success, isTrue);
      expect(r.httpStatus, isNull);
      expect(r.detail, isNull);
      expect(r.summary, 'Buy AAPL ×10');
      // The recorded payload is exactly what toRows() sends (two legs for
      // a Buy: cash Transfer + trade row).
      expect(r.rows, SheetTransactionModel.toRows(tx));
    });

    test('a failed append records a failure entry with detail and status',
        () async {
      final store = await emptyStore();
      final repo = LoggingSheetsRepository(
        delegate: _FakeDelegate(
            appendResult: const Failure('Sheet returned 500: boom')),
        auditLog: store,
        sheetName: 'Real',
      );

      final result = await repo.appendTransaction(_buyTx());
      expect(result.isFailure, isTrue);

      final r = store.records().single;
      expect(r.success, isFalse);
      expect(r.detail, 'Sheet returned 500: boom');
      expect(r.httpStatus, 500);
      expect(r.sheetName, 'Real');
    });

    test('a failure without an embedded status leaves httpStatus null',
        () async {
      final store = await emptyStore();
      final repo = LoggingSheetsRepository(
        delegate: _FakeDelegate(appendResult: const Failure('timeout')),
        auditLog: store,
        sheetName: 'Test',
      );

      await repo.appendTransaction(_buyTx());
      final r = store.records().single;
      expect(r.httpStatus, isNull);
      expect(r.detail, 'timeout');
    });

    test('reads are never logged', () async {
      final store = await emptyStore();
      final repo = LoggingSheetsRepository(
        delegate: _FakeDelegate(),
        auditLog: store,
        sheetName: 'Test',
      );

      await repo.fetchTransactions();
      await repo.fetchDashboard();
      await repo.fetchAccounts();
      await repo.fetchHoldings();
      repo.cachedTransactions();
      repo.cachedDashboard();
      repo.cachedAccounts();
      repo.cachedHoldings();
      repo.cachedTransactionsAt();
      repo.cachedDashboardAt();
      repo.cachedAccountsAt();
      repo.cachedHoldingsAt();

      expect(store.records(), isEmpty);
    });

    test('a throwing store never breaks the append', () async {
      SharedPreferences.setMockInitialValues({});
      final delegate = _FakeDelegate();
      final repo = LoggingSheetsRepository(
        delegate: delegate,
        auditLog: _ThrowingStore(await SharedPreferences.getInstance()),
        sheetName: 'Test',
      );

      final result = await repo.appendTransaction(_buyTx());
      expect(result.isSuccess, isTrue);
      expect(delegate.appendCalls, 1);
    });
  });

  group('summarize', () {
    test('expense with category', () {
      final tx = SheetTransaction(
        date: DateTime(2026, 7, 1),
        account: 'Toss',
        type: TransactionType.purchase,
        category: TransactionCategory.food,
        amount: 12.5,
      );
      expect(LoggingSheetsRepository.summarize(tx), 'Expense 식비 −12.5');
    });

    test('sell with whole quantity has no trailing .0', () {
      final tx = SheetTransaction(
        date: DateTime(2026, 7, 1),
        account: 'Toss',
        type: TransactionType.sell,
        ticker: 'TSLA',
        quantity: 3,
        price: 100,
      );
      expect(LoggingSheetsRepository.summarize(tx), 'Sell TSLA ×3');
    });

    test('transfer shows signed amount', () {
      final tx = SheetTransaction(
        date: DateTime(2026, 7, 1),
        account: 'Toss',
        type: TransactionType.transfer,
        amount: -300,
      );
      expect(LoggingSheetsRepository.summarize(tx), 'Transfer Toss −300');
    });

    test('a whole amount has no trailing .0', () {
      final tx = SheetTransaction(
        date: DateTime(2026, 7, 1),
        account: 'Toss',
        type: TransactionType.purchase,
        category: TransactionCategory.food,
        amount: 27550.0,
      );
      expect(LoggingSheetsRepository.summarize(tx), 'Expense 식비 −27550');
    });

    test('binary-float noise is rounded out of the summary', () {
      final tx = SheetTransaction(
        date: DateTime(2026, 7, 1),
        account: 'Toss',
        type: TransactionType.purchase,
        category: TransactionCategory.food,
        amount: 12.5000000001,
      );
      expect(LoggingSheetsRepository.summarize(tx), 'Expense 식비 −12.5');
    });
  });
}
