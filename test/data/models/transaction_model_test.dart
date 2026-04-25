import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/transaction_model.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';

void main() {
  final fixedDate = DateTime(2024, 4, 15, 18, 30, 0);
  final fixedTs = Timestamp.fromDate(fixedDate);
  final txDate = DateTime(2024, 4, 15);
  final txDateTs = Timestamp.fromDate(txDate);

  Transaction makeTransaction({
    String id = 'tx-1',
    String userId = 'user-1',
    String? accountId = 'acc-1',
    String title = 'Lunch',
    double amount = 15000.0,
    TransactionType type = TransactionType.expense,
    TransactionCategory category = TransactionCategory.food,
    String? note,
    String currency = 'KRW',
  }) {
    return Transaction(
      id: id,
      userId: userId,
      accountId: accountId,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: txDate,
      note: note,
      currency: currency,
      createdAt: fixedDate,
      updatedAt: fixedDate,
    );
  }

  group('TransactionModel.toMap', () {
    test('serializes all fields correctly', () {
      final map = TransactionModel.fromEntity(
        makeTransaction(note: 'With friends'),
      ).toMap();

      expect(map['id'], 'tx-1');
      expect(map['userId'], 'user-1');
      expect(map['accountId'], 'acc-1');
      expect(map['title'], 'Lunch');
      expect(map['amount'], 15000.0);
      expect(map['type'], 'expense');
      expect(map['category'], 'food');
      expect(map['date'], txDateTs);
      expect(map['note'], 'With friends');
      expect(map['currency'], 'KRW');
    });

    test('serializes null accountId and note as null', () {
      final map = TransactionModel.fromEntity(
        makeTransaction(accountId: null, note: null),
      ).toMap();
      expect(map['accountId'], isNull);
      expect(map['note'], isNull);
    });

    test('serializes every TransactionType correctly', () {
      for (final type in TransactionType.values) {
        final map =
            TransactionModel.fromEntity(makeTransaction(type: type)).toMap();
        expect(map['type'], type.name);
      }
    });

    test('serializes every TransactionCategory correctly', () {
      for (final cat in TransactionCategory.values) {
        final map = TransactionModel.fromEntity(
          makeTransaction(category: cat),
        ).toMap();
        expect(map['category'], cat.name);
      }
    });
  });

  group('TransactionModel.fromMap', () {
    test('deserializes all fields correctly', () {
      final map = <String, dynamic>{
        'id': 'tx-1',
        'userId': 'user-1',
        'accountId': 'acc-1',
        'title': 'Lunch',
        'amount': 15000.0,
        'type': 'expense',
        'category': 'food',
        'date': txDateTs,
        'note': 'With friends',
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      final tx = TransactionModel.fromMap(map).toEntity();

      expect(tx.title, 'Lunch');
      expect(tx.amount, 15000.0);
      expect(tx.type, TransactionType.expense);
      expect(tx.category, TransactionCategory.food);
      expect(tx.accountId, 'acc-1');
      expect(tx.note, 'With friends');
    });

    test('handles null accountId and note', () {
      final map = <String, dynamic>{
        'id': 'tx-1',
        'userId': 'user-1',
        'accountId': null,
        'title': 'Salary',
        'amount': 3000000.0,
        'type': 'income',
        'category': 'salary',
        'date': txDateTs,
        'note': null,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      final tx = TransactionModel.fromMap(map).toEntity();
      expect(tx.accountId, isNull);
      expect(tx.note, isNull);
    });

    test('defaults currency to KRW when missing', () {
      final map = <String, dynamic>{
        'id': 'tx-1',
        'userId': 'u1',
        'accountId': null,
        'title': 'X',
        'amount': 1.0,
        'type': 'expense',
        'category': 'other',
        'date': txDateTs,
        'note': null,
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(TransactionModel.fromMap(map).currency, 'KRW');
    });

    test('unknown category defaults to other', () {
      final map = <String, dynamic>{
        'id': 'tx-1',
        'userId': 'u1',
        'accountId': null,
        'title': 'X',
        'amount': 1.0,
        'type': 'expense',
        'category': 'unknown_cat',
        'date': txDateTs,
        'note': null,
        'currency': 'KRW',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(TransactionModel.fromMap(map).category, TransactionCategory.other);
    });
  });

  group('TransactionModel toMap/fromMap roundtrip', () {
    test('preserves all values', () {
      final original = makeTransaction(note: 'Test note');
      final rt = TransactionModel.fromMap(
        TransactionModel.fromEntity(original).toMap(),
      ).toEntity();

      expect(rt.id, original.id);
      expect(rt.title, original.title);
      expect(rt.amount, original.amount);
      expect(rt.type, original.type);
      expect(rt.category, original.category);
      expect(rt.accountId, original.accountId);
      expect(rt.note, original.note);
      expect(rt.date, original.date);
    });
  });

  group('Transaction.copyWith', () {
    test('changes only specified fields', () {
      final original = makeTransaction();
      final updated = original.copyWith(title: 'Dinner', amount: 30000.0);

      expect(updated.title, 'Dinner');
      expect(updated.amount, 30000.0);
      expect(updated.id, original.id);
      expect(updated.category, original.category);
      expect(updated.accountId, original.accountId);
    });
  });

  group('TransactionCategoryX.forType', () {
    test('income returns income categories', () {
      final cats = TransactionCategoryX.forType(TransactionType.income);
      expect(cats, contains(TransactionCategory.salary));
      expect(cats, contains(TransactionCategory.freelance));
      expect(cats, isNot(contains(TransactionCategory.food)));
    });

    test('expense returns expense categories', () {
      final cats = TransactionCategoryX.forType(TransactionType.expense);
      expect(cats, contains(TransactionCategory.food));
      expect(cats, contains(TransactionCategory.transport));
      expect(cats, isNot(contains(TransactionCategory.salary)));
    });
  });
}
