import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_transaction_repository.dart';
import 'package:jibsaja/domain/use_cases/add_income_or_expense.dart';

class _FakeTxRepo implements ITransactionRepository {
  final List<Transaction> added = [];
  final List<Transaction> updated = [];

  @override
  Future<void> addTransaction(String uid, Transaction tx) async => added.add(tx);

  @override
  Future<void> updateTransaction(String uid, Transaction tx) async =>
      updated.add(tx);

  @override
  Future<void> batchAddTransactions(String uid, List<Transaction> txs) async =>
      added.addAll(txs);

  @override
  Future<void> deleteTransaction(String uid, String id) async {}

  @override
  Stream<List<Transaction>> watchTransactions(String uid) => const Stream.empty();

  @override
  Stream<List<Transaction>> watchRecentTransactions(String uid, {int limit = 5}) =>
      const Stream.empty();
}

void main() {
  late _FakeTxRepo repo;
  late AddIncomeOrExpense useCase;
  const uid = 'user-1';
  final date = DateTime(2025, 1, 15);

  setUp(() {
    repo = _FakeTxRepo();
    useCase = AddIncomeOrExpense(repo);
  });

  group('AddIncomeOrExpense — new transaction', () {
    test('calls addTransaction with correct fields for expense', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.expense,
        title: 'Lunch',
        amount: 12000,
        category: TransactionCategory.food,
        date: date,
        accountId: 'acc-1',
        note: 'ramen',
        currency: 'KRW',
      );

      expect(repo.added, hasLength(1));
      final tx = repo.added.first;
      expect(tx.userId, uid);
      expect(tx.title, 'Lunch');
      expect(tx.amount, 12000);
      expect(tx.type, TransactionType.expense);
      expect(tx.category, TransactionCategory.food);
      expect(tx.accountId, 'acc-1');
      expect(tx.note, 'ramen');
      expect(tx.currency, 'KRW');
      expect(tx.date, date);
      expect(tx.id, isNotEmpty);
    });

    test('calls addTransaction with correct fields for income', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.income,
        title: 'Salary',
        amount: 3000000,
        category: TransactionCategory.salary,
        date: date,
      );

      expect(repo.added, hasLength(1));
      expect(repo.added.first.type, TransactionType.income);
      expect(repo.updated, isEmpty);
    });

    test('does not call updateTransaction for new transaction', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.expense,
        title: 'Coffee',
        amount: 5000,
        category: TransactionCategory.food,
        date: date,
      );
      expect(repo.updated, isEmpty);
    });
  });

  group('AddIncomeOrExpense — update existing', () {
    test('calls updateTransaction with merged fields', () async {
      final now = DateTime.now();
      final existing = Transaction(
        id: 'tx-existing',
        userId: uid,
        title: 'Old Title',
        amount: 1000,
        type: TransactionType.expense,
        category: TransactionCategory.other,
        date: date,
        currency: 'KRW',
        createdAt: now,
        updatedAt: now,
      );

      await useCase.call(
        uid: uid,
        type: TransactionType.expense,
        title: 'New Title',
        amount: 9999,
        category: TransactionCategory.shopping,
        date: date,
        existing: existing,
      );

      expect(repo.added, isEmpty);
      expect(repo.updated, hasLength(1));
      final tx = repo.updated.first;
      expect(tx.id, 'tx-existing');
      expect(tx.title, 'New Title');
      expect(tx.amount, 9999);
      expect(tx.category, TransactionCategory.shopping);
    });
  });

  group('AddIncomeOrExpense — assertion', () {
    test('throws AssertionError for buy type', () async {
      expect(
        () => useCase.call(
          uid: uid,
          type: TransactionType.buy,
          title: 'Buy AAPL',
          amount: 100,
          category: TransactionCategory.investment,
          date: date,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError for sell type', () async {
      expect(
        () => useCase.call(
          uid: uid,
          type: TransactionType.sell,
          title: 'Sell AAPL',
          amount: 100,
          category: TransactionCategory.investment,
          date: date,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
