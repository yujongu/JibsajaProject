import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/repositories/card_repository_impl.dart';
import 'package:jibsaja/domain/entities/bank_card.dart';
import 'package:jibsaja/domain/entities/card_network.dart';
import 'package:jibsaja/domain/entities/card_type.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late CardRepositoryImpl repo;
  const uid = 'user-test';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = CardRepositoryImpl(fakeFirestore);
  });

  BankCard makeCard({
    String id = 'card-1',
    String name = 'Kakao Visa',
    String last4 = '1234',
    CardType type = CardType.credit,
    CardNetwork network = CardNetwork.visa,
    double balance = 200000,
    double? creditLimit = 3000000,
  }) {
    final now = DateTime.now();
    return BankCard(
      id: id,
      userId: uid,
      name: name,
      last4Digits: last4,
      type: type,
      network: network,
      balance: balance,
      creditLimit: creditLimit,
      currency: 'KRW',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('CardRepositoryImpl.addCard', () {
    test('stores document at correct path', () async {
      final card = makeCard();
      await repo.addCard(uid, card);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc(card.id)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Kakao Visa');
      expect(doc.data()!['last4Digits'], '1234');
      expect(doc.data()!['type'], 'credit');
      expect(doc.data()!['network'], 'visa');
    });

    test('stores null creditLimit for debit cards', () async {
      final card = makeCard(type: CardType.debit, creditLimit: null);
      await repo.addCard(uid, card);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc(card.id)
          .get();

      expect(doc.data()!['creditLimit'], isNull);
    });
  });

  group('CardRepositoryImpl.watchCards', () {
    test('emits empty list when no cards exist', () async {
      final cards = await repo.watchCards(uid).first;
      expect(cards, isEmpty);
    });

    test('emits all cards for user', () async {
      await repo.addCard(uid, makeCard(id: 'c1', name: 'Visa Card'));
      await repo.addCard(uid, makeCard(id: 'c2', name: 'Mastercard'));

      final cards = await repo.watchCards(uid).first;
      expect(cards.length, 2);
      expect(cards.map((c) => c.name), containsAll(['Visa Card', 'Mastercard']));
    });

    test('isolates data per user', () async {
      await repo.addCard('other-user', makeCard());
      final cards = await repo.watchCards(uid).first;
      expect(cards, isEmpty);
    });
  });

  group('CardRepositoryImpl.updateCard', () {
    test('updates balance and name', () async {
      final card = makeCard();
      await repo.addCard(uid, card);

      final updated = card.copyWith(balance: 500000.0, name: 'Renamed');
      await repo.updateCard(uid, updated);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc(card.id)
          .get();

      expect(doc.data()!['balance'], 500000.0);
      expect(doc.data()!['name'], 'Renamed');
    });
  });

  group('CardRepositoryImpl.deleteCard', () {
    test('removes document from Firestore', () async {
      final card = makeCard();
      await repo.addCard(uid, card);
      await repo.deleteCard(uid, card.id);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc(card.id)
          .get();

      expect(doc.exists, false);
    });

    test('does not affect other cards', () async {
      await repo.addCard(uid, makeCard(id: 'c1', name: 'Delete Me'));
      await repo.addCard(uid, makeCard(id: 'c2', name: 'Keep Me'));

      await repo.deleteCard(uid, 'c1');

      final cards = await repo.watchCards(uid).first;
      expect(cards.length, 1);
      expect(cards.first.name, 'Keep Me');
    });
  });
}
