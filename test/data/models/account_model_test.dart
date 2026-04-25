import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/account_model.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';

void main() {
  final fixedDate = DateTime(2024, 6, 15, 12, 0, 0);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Account makeAccount({
    String id = 'acc-1',
    String userId = 'user-1',
    String name = 'My Checking',
    AccountType type = AccountType.checking,
    double balance = 1500.0,
    String currency = 'KRW',
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: type,
      balance: balance,
      currency: currency,
      createdAt: fixedDate,
      updatedAt: fixedDate,
    );
  }

  group('AccountModel.toMap', () {
    test('serializes all fields correctly', () {
      final map = AccountModel.fromEntity(makeAccount()).toMap();

      expect(map['id'], 'acc-1');
      expect(map['userId'], 'user-1');
      expect(map['name'], 'My Checking');
      expect(map['type'], 'checking');
      expect(map['balance'], 1500.0);
      expect(map['currency'], 'KRW');
      expect(map['createdAt'], fixedTs);
      expect(map['updatedAt'], fixedTs);
    });

    test('serializes every AccountType correctly', () {
      for (final type in AccountType.values) {
        final map = AccountModel.fromEntity(makeAccount(type: type)).toMap();
        expect(map['type'], type.name);
      }
    });
  });

  group('AccountModel.fromMap', () {
    test('deserializes all fields correctly', () {
      final map = <String, dynamic>{
        'id': 'acc-1',
        'userId': 'user-1',
        'name': 'My Checking',
        'type': 'checking',
        'balance': 1500.0,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };

      final account = AccountModel.fromMap(map).toEntity();
      expect(account.id, 'acc-1');
      expect(account.userId, 'user-1');
      expect(account.name, 'My Checking');
      expect(account.type, AccountType.checking);
      expect(account.balance, 1500.0);
      expect(account.currency, 'KRW');
      expect(account.createdAt, fixedDate);
    });

    test('defaults currency to KRW when missing', () {
      final map = <String, dynamic>{
        'id': 'acc-1',
        'userId': 'user-1',
        'name': 'Test',
        'type': 'savings',
        'balance': 0.0,
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(AccountModel.fromMap(map).currency, 'KRW');
    });

    test('unknown type defaults to other', () {
      final map = <String, dynamic>{
        'id': 'acc-1',
        'userId': 'user-1',
        'name': 'Test',
        'type': 'nonexistent_type',
        'balance': 0.0,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(AccountModel.fromMap(map).type, AccountType.other);
    });
  });

  group('AccountModel toMap/fromMap roundtrip', () {
    test('preserves all values through serialization', () {
      final original = makeAccount(
        id: 'round-1',
        name: 'Savings Account',
        type: AccountType.savings,
        balance: 9999.99,
        currency: 'USD',
      );
      final rt = AccountModel.fromMap(
        AccountModel.fromEntity(original).toMap(),
      ).toEntity();

      expect(rt.id, original.id);
      expect(rt.name, original.name);
      expect(rt.type, original.type);
      expect(rt.balance, original.balance);
      expect(rt.currency, original.currency);
      expect(rt.createdAt, original.createdAt);
    });
  });

  group('Account.copyWith', () {
    test('changes only specified fields', () {
      final original = makeAccount();
      final updated = original.copyWith(name: 'Updated', balance: 2000.0);

      expect(updated.name, 'Updated');
      expect(updated.balance, 2000.0);
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.type, original.type);
      expect(updated.currency, original.currency);
    });

    test('copyWith with no args is equivalent to original', () {
      final original = makeAccount();
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.balance, original.balance);
    });
  });
}
