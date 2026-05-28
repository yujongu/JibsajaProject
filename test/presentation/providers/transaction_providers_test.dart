import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/repositories/transaction_repository_impl.dart';
import 'package:jibsaja/domain/entities/app_user.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/presentation/providers/auth_providers.dart';
import 'package:jibsaja/presentation/providers/firebase_providers.dart';
import 'package:jibsaja/presentation/providers/transaction_providers.dart';

const _uid = 'test-user';
const _user = AppUser(uid: _uid);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Container wired to FakeFirestore + a fake auth state that emits [_user].
ProviderContainer _firestoreContainer(FakeFirebaseFirestore firestore) {
  return ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((_) => Stream.value(_user)),
    ],
  );
}

/// Container with [transactionsStreamProvider] pre-seeded with [txs].
/// Awaits the first stream emission so derived providers have data on return.
Future<ProviderContainer> _seedContainer(
  List<Transaction> txs, {
  DateTime? month,
}) async {
  final c = ProviderContainer(
    overrides: [
      transactionsStreamProvider.overrideWith((_) => Stream.value(txs)),
    ],
  );
  if (month != null) {
    c.read(selectedMonthProvider.notifier).state = month;
  }
  await c.read(transactionsStreamProvider.future);
  return c;
}

/// Waits for [provider] to emit its first [AsyncData] value.
Future<T> _awaitData<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final completer = Completer<T>();
  final sub = container.listen<AsyncValue<T>>(
    provider,
    (_, next) {
      if (next is AsyncData<T> && !completer.isCompleted) {
        completer.complete(next.value);
      } else if (next is AsyncError && !completer.isCompleted) {
        completer.completeError(next.error!, next.stackTrace);
      }
    },
    fireImmediately: true,
  );
  final result =
      await completer.future.timeout(const Duration(seconds: 10));
  sub.close();
  return result;
}

Transaction _makeTx({
  required String id,
  required String title,
  required double amount,
  required TransactionType type,
  TransactionCategory category = TransactionCategory.food,
  required DateTime date,
}) {
  final now = DateTime.now();
  return Transaction(
    id: id,
    userId: _uid,
    title: title,
    amount: amount,
    type: type,
    category: category,
    date: date,
    createdAt: now,
    updatedAt: now,
  );
}

// ── transactionsStreamProvider ────────────────────────────────────────────────

void main() {
  group('transactionsStreamProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late TransactionRepositoryImpl txRepo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      txRepo = TransactionRepositoryImpl(firestore);
      container = _firestoreContainer(firestore);
    });

    tearDown(() => container.dispose());

    test('emits empty list when no transactions exist', () async {
      final txs = await _awaitData(container, transactionsStreamProvider);
      expect(txs, isEmpty);
    });

    test('emits transaction after it is written to Firestore', () async {
      final tx = _makeTx(
        id: 'tx-1',
        title: 'Lunch',
        amount: 12000,
        type: TransactionType.expense,
        date: DateTime(2025, 5, 1),
      );
      await txRepo.addTransaction(_uid, tx);

      final txs = await _awaitData(container, transactionsStreamProvider);
      expect(txs, hasLength(1));
      expect(txs.first.title, 'Lunch');
      expect(txs.first.amount, 12000);
    });

    test('does not include transactions from another user', () async {
      final tx = _makeTx(
        id: 'tx-other',
        title: 'Other',
        amount: 5000,
        type: TransactionType.expense,
        date: DateTime(2025, 5, 1),
      );
      await txRepo.addTransaction('other-user', tx);

      final txs = await _awaitData(container, transactionsStreamProvider);
      expect(txs, isEmpty);
    });
  });

  // ── monthlyTransactionsProvider ─────────────────────────────────────────────

  group('monthlyTransactionsProvider', () {
    final may = DateTime(2025, 5);
    final txs = [
      _makeTx(id: 'may-1', title: 'Coffee', amount: 5000, type: TransactionType.expense, date: DateTime(2025, 5, 3)),
      _makeTx(id: 'may-2', title: 'Salary', amount: 3000000, type: TransactionType.income, date: DateTime(2025, 5, 25)),
      _makeTx(id: 'apr-1', title: 'Old Rent', amount: 800000, type: TransactionType.expense, date: DateTime(2025, 4, 1)),
    ];

    late ProviderContainer container;
    setUp(() async => container = await _seedContainer(txs, month: may));
    tearDown(() => container.dispose());

    test('returns only transactions in the selected month', () {
      final monthly = container.read(monthlyTransactionsProvider);
      expect(monthly, hasLength(2));
      expect(monthly.every((tx) => tx.date.month == 5), isTrue);
    });

    test('excludes transactions from other months', () {
      final monthly = container.read(monthlyTransactionsProvider);
      expect(monthly.any((tx) => tx.title == 'Old Rent'), isFalse);
    });

    test('switches filtered list when selectedMonth changes', () {
      container.read(selectedMonthProvider.notifier).state = DateTime(2025, 4);
      final april = container.read(monthlyTransactionsProvider);
      expect(april, hasLength(1));
      expect(april.first.title, 'Old Rent');
    });
  });

  // ── monthlyIncomeProvider & monthlyExpensesProvider ──────────────────────────

  group('monthlyIncomeProvider and monthlyExpensesProvider', () {
    test('sums income and expenses correctly', () async {
      final c = await _seedContainer([
        _makeTx(id: 'i1', title: 'Salary', amount: 3000000, type: TransactionType.income, date: DateTime(2025, 5, 25)),
        _makeTx(id: 'i2', title: 'Bonus', amount: 500000, type: TransactionType.income, date: DateTime(2025, 5, 28)),
        _makeTx(id: 'e1', title: 'Rent', amount: 800000, type: TransactionType.expense, date: DateTime(2025, 5, 1)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(monthlyIncomeProvider), 3500000);
      expect(c.read(monthlyExpensesProvider), 800000);
    });

    test('returns zero when there are no transactions', () async {
      final c = await _seedContainer([], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(monthlyIncomeProvider), 0.0);
      expect(c.read(monthlyExpensesProvider), 0.0);
    });

    test('does not count income toward expenses or vice versa', () async {
      final c = await _seedContainer([
        _makeTx(id: 'i1', title: 'Salary', amount: 1000000, type: TransactionType.income, date: DateTime(2025, 5, 1)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(monthlyExpensesProvider), 0.0);
    });
  });

  // ── categoryExpensesProvider ──────────────────────────────────────────────────

  group('categoryExpensesProvider', () {
    test('groups and sums expenses by category', () async {
      final c = await _seedContainer([
        _makeTx(id: 'f1', title: 'Lunch', amount: 12000, type: TransactionType.expense, category: TransactionCategory.food, date: DateTime(2025, 5, 1)),
        _makeTx(id: 'f2', title: 'Dinner', amount: 20000, type: TransactionType.expense, category: TransactionCategory.food, date: DateTime(2025, 5, 2)),
        _makeTx(id: 't1', title: 'Bus', amount: 1500, type: TransactionType.expense, category: TransactionCategory.transport, date: DateTime(2025, 5, 3)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      final breakdown = c.read(categoryExpensesProvider);
      expect(breakdown[TransactionCategory.food], 32000);
      expect(breakdown[TransactionCategory.transport], 1500);
    });

    test('sorts categories descending by total amount', () async {
      final c = await _seedContainer([
        _makeTx(id: 't1', title: 'Bus', amount: 1500, type: TransactionType.expense, category: TransactionCategory.transport, date: DateTime(2025, 5, 3)),
        _makeTx(id: 'f1', title: 'Lunch', amount: 50000, type: TransactionType.expense, category: TransactionCategory.food, date: DateTime(2025, 5, 1)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      final keys = c.read(categoryExpensesProvider).keys.toList();
      expect(keys.first, TransactionCategory.food);
      expect(keys.last, TransactionCategory.transport);
    });

    test('excludes income transactions', () async {
      final c = await _seedContainer([
        _makeTx(id: 'i1', title: 'Salary', amount: 3000000, type: TransactionType.income, date: DateTime(2025, 5, 25)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(categoryExpensesProvider), isEmpty);
    });

    test('returns empty map when there are no transactions', () async {
      final c = await _seedContainer([], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(categoryExpensesProvider), isEmpty);
    });
  });

  // ── dailyExpensesProvider ─────────────────────────────────────────────────────

  group('dailyExpensesProvider', () {
    test('aggregates expense amounts by day of month', () async {
      final c = await _seedContainer([
        _makeTx(id: 'e1', title: 'Coffee', amount: 5000, type: TransactionType.expense, date: DateTime(2025, 5, 3)),
        _makeTx(id: 'e2', title: 'Lunch', amount: 12000, type: TransactionType.expense, date: DateTime(2025, 5, 3)),
        _makeTx(id: 'e3', title: 'Dinner', amount: 25000, type: TransactionType.expense, date: DateTime(2025, 5, 10)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      final daily = c.read(dailyExpensesProvider);
      expect(daily[3], 17000); // 5000 + 12000
      expect(daily[10], 25000);
      expect(daily.length, 2);
    });

    test('excludes income from daily totals', () async {
      final c = await _seedContainer([
        _makeTx(id: 'i1', title: 'Salary', amount: 3000000, type: TransactionType.income, date: DateTime(2025, 5, 25)),
      ], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(dailyExpensesProvider), isEmpty);
    });

    test('returns empty map when there are no transactions', () async {
      final c = await _seedContainer([], month: DateTime(2025, 5));
      addTearDown(c.dispose);

      expect(c.read(dailyExpensesProvider), isEmpty);
    });
  });
}
