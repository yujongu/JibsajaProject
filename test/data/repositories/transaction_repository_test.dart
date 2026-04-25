import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/repositories/transaction_repository_impl.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late TransactionRepositoryImpl repo;
  const uid = 'user-test';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = TransactionRepositoryImpl(fakeFirestore);
  });

  Transaction makeTx({
    String id = 'tx-1',
    String title = 'Lunch',
    double amount = 15000,
    TransactionType type = TransactionType.expense,
    TransactionCategory category = TransactionCategory.food,
    String? accountId = 'acc-1',
    DateTime? date,
  }) {
    final now = DateTime.now();
    return Transaction(
      id: id,
      userId: uid,
      accountId: accountId,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date ?? now,
      currency: 'KRW',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TransactionRepositoryImpl.addTransaction', () {
    test('stores document at correct path', () async {
      final tx = makeTx();
      await repo.addTransaction(uid, tx);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(tx.id)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['title'], 'Lunch');
      expect(doc.data()!['amount'], 15000.0);
      expect(doc.data()!['type'], 'expense');
      expect(doc.data()!['category'], 'food');
    });

    test('stores null accountId when not provided', () async {
      final tx = makeTx(accountId: null);
      await repo.addTransaction(uid, tx);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(tx.id)
          .get();

      expect(doc.data()!['accountId'], isNull);
    });
  });

  group('TransactionRepositoryImpl.watchTransactions', () {
    test('emits empty list when no transactions exist', () async {
      final txs = await repo.watchTransactions(uid).first;
      expect(txs, isEmpty);
    });

    test('emits all transactions for user', () async {
      await repo.addTransaction(uid, makeTx(id: 'tx-1', title: 'Lunch'));
      await repo.addTransaction(uid, makeTx(id: 'tx-2', title: 'Salary',
          type: TransactionType.income, category: TransactionCategory.salary));

      final txs = await repo.watchTransactions(uid).first;
      expect(txs.length, 2);
      expect(txs.map((t) => t.title), containsAll(['Lunch', 'Salary']));
    });

    test('isolates data per user', () async {
      await repo.addTransaction('other-user', makeTx());
      final txs = await repo.watchTransactions(uid).first;
      expect(txs, isEmpty);
    });
  });

  group('TransactionRepositoryImpl.watchRecentTransactions', () {
    test('limits results to specified count', () async {
      for (var i = 1; i <= 8; i++) {
        await repo.addTransaction(uid, makeTx(id: 'tx-$i', title: 'Tx $i'));
      }
      final recent = await repo.watchRecentTransactions(uid, limit: 5).first;
      expect(recent.length, 5);
    });

    test('defaults limit to 5', () async {
      for (var i = 1; i <= 7; i++) {
        await repo.addTransaction(uid, makeTx(id: 'tx-$i', title: 'Tx $i'));
      }
      final recent = await repo.watchRecentTransactions(uid).first;
      expect(recent.length, 5);
    });
  });

  group('TransactionRepositoryImpl.updateTransaction', () {
    test('updates existing document fields', () async {
      final tx = makeTx();
      await repo.addTransaction(uid, tx);

      final updated = tx.copyWith(title: 'Dinner', amount: 35000.0);
      await repo.updateTransaction(uid, updated);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(tx.id)
          .get();

      expect(doc.data()!['title'], 'Dinner');
      expect(doc.data()!['amount'], 35000.0);
    });
  });

  group('TransactionRepositoryImpl.deleteTransaction', () {
    test('removes document from Firestore', () async {
      final tx = makeTx();
      await repo.addTransaction(uid, tx);
      await repo.deleteTransaction(uid, tx.id);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(tx.id)
          .get();

      expect(doc.exists, false);
    });

    test('does not affect other transactions', () async {
      await repo.addTransaction(uid, makeTx(id: 'tx-1', title: 'Delete Me'));
      await repo.addTransaction(uid, makeTx(id: 'tx-2', title: 'Keep Me'));

      await repo.deleteTransaction(uid, 'tx-1');

      final txs = await repo.watchTransactions(uid).first;
      expect(txs.length, 1);
      expect(txs.first.title, 'Keep Me');
    });
  });
}
