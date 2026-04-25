import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/repositories/account_repository_impl.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late AccountRepositoryImpl repo;
  const uid = 'user-test';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = AccountRepositoryImpl(fakeFirestore);
  });

  Account makeAccount({
    String id = 'acc-1',
    String name = 'My Checking',
    AccountType type = AccountType.checking,
    double balance = 1000.0,
  }) {
    final now = DateTime.now();
    return Account(
      id: id,
      userId: uid,
      name: name,
      type: type,
      balance: balance,
      currency: 'KRW',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('AccountRepositoryImpl.addAccount', () {
    test('stores document at correct path', () async {
      final account = makeAccount();
      await repo.addAccount(uid, account);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc(account.id)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['name'], 'My Checking');
      expect(doc.data()!['type'], 'checking');
      expect(doc.data()!['balance'], 1000.0);
    });

    test('does not write to wrong uid path', () async {
      final account = makeAccount();
      await repo.addAccount(uid, account);

      final doc = await fakeFirestore
          .collection('users')
          .doc('other-user')
          .collection('accounts')
          .doc(account.id)
          .get();

      expect(doc.exists, false);
    });
  });

  group('AccountRepositoryImpl.watchAccounts', () {
    test('emits empty list when no accounts exist', () async {
      final accounts = await repo.watchAccounts(uid).first;
      expect(accounts, isEmpty);
    });

    test('emits list with added accounts', () async {
      final a1 = makeAccount(id: 'acc-1', name: 'Checking');
      final a2 = makeAccount(id: 'acc-2', name: 'Savings', type: AccountType.savings);
      await repo.addAccount(uid, a1);
      await repo.addAccount(uid, a2);

      final accounts = await repo.watchAccounts(uid).first;
      expect(accounts.length, 2);
      final names = accounts.map((a) => a.name).toSet();
      expect(names, containsAll(['Checking', 'Savings']));
    });

    test('does not emit other users accounts', () async {
      final account = makeAccount();
      await repo.addAccount('other-user', account);

      final accounts = await repo.watchAccounts(uid).first;
      expect(accounts, isEmpty);
    });
  });

  group('AccountRepositoryImpl.updateAccount', () {
    test('updates existing document fields', () async {
      final account = makeAccount();
      await repo.addAccount(uid, account);

      final updated = account.copyWith(name: 'Renamed', balance: 5000.0);
      await repo.updateAccount(uid, updated);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc(account.id)
          .get();

      expect(doc.data()!['name'], 'Renamed');
      expect(doc.data()!['balance'], 5000.0);
    });
  });

  group('AccountRepositoryImpl.deleteAccount', () {
    test('removes document from Firestore', () async {
      final account = makeAccount();
      await repo.addAccount(uid, account);

      await repo.deleteAccount(uid, account.id);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc(account.id)
          .get();

      expect(doc.exists, false);
    });

    test('does not affect other accounts', () async {
      final a1 = makeAccount(id: 'acc-1');
      final a2 = makeAccount(id: 'acc-2', name: 'Keeper');
      await repo.addAccount(uid, a1);
      await repo.addAccount(uid, a2);

      await repo.deleteAccount(uid, 'acc-1');

      final accounts = await repo.watchAccounts(uid).first;
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Keeper');
    });
  });
}
