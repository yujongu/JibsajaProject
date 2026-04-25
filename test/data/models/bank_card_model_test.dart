import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/bank_card_model.dart';
import 'package:jibsaja/domain/entities/bank_card.dart';
import 'package:jibsaja/domain/entities/card_network.dart';
import 'package:jibsaja/domain/entities/card_type.dart';

void main() {
  final fixedDate = DateTime(2024, 4, 1, 0, 0, 0);
  final fixedTs = Timestamp.fromDate(fixedDate);

  BankCard makeCard({
    String id = 'card-1',
    String userId = 'user-1',
    String name = 'Kakao Bank Visa',
    String last4Digits = '1234',
    CardType type = CardType.credit,
    CardNetwork network = CardNetwork.visa,
    double balance = 200000.0,
    double? creditLimit = 3000000.0,
    String currency = 'KRW',
  }) {
    return BankCard(
      id: id,
      userId: userId,
      name: name,
      last4Digits: last4Digits,
      type: type,
      network: network,
      balance: balance,
      creditLimit: creditLimit,
      currency: currency,
      createdAt: fixedDate,
      updatedAt: fixedDate,
    );
  }

  group('BankCardModel.toMap', () {
    test('serializes all fields correctly', () {
      final map = BankCardModel.fromEntity(makeCard()).toMap();

      expect(map['id'], 'card-1');
      expect(map['userId'], 'user-1');
      expect(map['name'], 'Kakao Bank Visa');
      expect(map['last4Digits'], '1234');
      expect(map['type'], 'credit');
      expect(map['network'], 'visa');
      expect(map['balance'], 200000.0);
      expect(map['creditLimit'], 3000000.0);
      expect(map['currency'], 'KRW');
      expect(map['createdAt'], fixedTs);
    });

    test('serializes null creditLimit as null', () {
      final map = BankCardModel.fromEntity(makeCard(creditLimit: null)).toMap();
      expect(map['creditLimit'], isNull);
    });

    test('serializes every CardType correctly', () {
      for (final type in CardType.values) {
        final map = BankCardModel.fromEntity(makeCard(type: type)).toMap();
        expect(map['type'], type.name);
      }
    });

    test('serializes every CardNetwork correctly', () {
      for (final network in CardNetwork.values) {
        final map = BankCardModel.fromEntity(makeCard(network: network)).toMap();
        expect(map['network'], network.name);
      }
    });
  });

  group('BankCardModel.fromMap', () {
    test('deserializes all fields correctly', () {
      final map = <String, dynamic>{
        'id': 'card-1',
        'userId': 'user-1',
        'name': 'Kakao Bank Visa',
        'last4Digits': '1234',
        'type': 'credit',
        'network': 'visa',
        'balance': 200000.0,
        'creditLimit': 3000000.0,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      final card = BankCardModel.fromMap(map).toEntity();

      expect(card.name, 'Kakao Bank Visa');
      expect(card.last4Digits, '1234');
      expect(card.type, CardType.credit);
      expect(card.network, CardNetwork.visa);
      expect(card.balance, 200000.0);
      expect(card.creditLimit, 3000000.0);
    });

    test('deserializes null creditLimit', () {
      final map = <String, dynamic>{
        'id': 'card-1',
        'userId': 'user-1',
        'name': 'Debit',
        'last4Digits': '5678',
        'type': 'debit',
        'network': 'visa',
        'balance': 500000.0,
        'creditLimit': null,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(BankCardModel.fromMap(map).creditLimit, isNull);
    });

    test('defaults currency to KRW when missing', () {
      final map = <String, dynamic>{
        'id': 'card-1',
        'userId': 'user-1',
        'name': 'Card',
        'last4Digits': '0000',
        'type': 'debit',
        'network': 'other',
        'balance': 0.0,
        'creditLimit': null,
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(BankCardModel.fromMap(map).currency, 'KRW');
    });

    test('unknown type defaults to debit', () {
      final map = <String, dynamic>{
        'id': 'c1',
        'userId': 'u1',
        'name': 'X',
        'last4Digits': '0000',
        'type': 'unknown',
        'network': 'visa',
        'balance': 0.0,
        'creditLimit': null,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(BankCardModel.fromMap(map).type, CardType.debit);
    });
  });

  group('BankCardModel toMap/fromMap roundtrip', () {
    test('preserves all values', () {
      final original = makeCard();
      final rt = BankCardModel.fromMap(
        BankCardModel.fromEntity(original).toMap(),
      ).toEntity();

      expect(rt.id, original.id);
      expect(rt.name, original.name);
      expect(rt.last4Digits, original.last4Digits);
      expect(rt.type, original.type);
      expect(rt.network, original.network);
      expect(rt.balance, original.balance);
      expect(rt.creditLimit, original.creditLimit);
      expect(rt.currency, original.currency);
    });
  });

  group('BankCard.availableCredit', () {
    test('returns creditLimit minus balance for credit cards', () {
      final card = makeCard(balance: 500000, creditLimit: 3000000);
      expect(card.availableCredit, 2500000.0);
    });

    test('returns null when creditLimit is null', () {
      final card = makeCard(creditLimit: null);
      expect(card.availableCredit, isNull);
    });
  });

  group('BankCard.copyWith', () {
    test('changes only specified fields', () {
      final original = makeCard();
      final updated = original.copyWith(balance: 999.0, name: 'New Name');

      expect(updated.balance, 999.0);
      expect(updated.name, 'New Name');
      expect(updated.id, original.id);
      expect(updated.last4Digits, original.last4Digits);
    });
  });
}
