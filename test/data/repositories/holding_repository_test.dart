import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/repositories/holding_repository_impl.dart';
import 'package:jibsaja/domain/entities/holding.dart';
import 'package:jibsaja/domain/entities/holding_type.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late HoldingRepositoryImpl repo;
  const uid = 'user-test';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = HoldingRepositoryImpl(fakeFirestore);
  });

  Holding makeHolding({
    String id = 'hold-1',
    String name = 'Apple Inc',
    String ticker = 'AAPL',
    HoldingType type = HoldingType.stock,
    double qty = 10,
    double avgCost = 150,
    double price = 175,
  }) {
    final now = DateTime.now();
    return Holding(
      id: id,
      userId: uid,
      name: name,
      ticker: ticker,
      type: type,
      quantity: qty,
      avgCostPrice: avgCost,
      currentPrice: price,
      currency: 'USD',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('HoldingRepositoryImpl.addHolding', () {
    test('stores document at correct path', () async {
      final holding = makeHolding();
      await repo.addHolding(uid, holding);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('holdings')
          .doc(holding.id)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Apple Inc');
      expect(doc.data()!['ticker'], 'AAPL');
      expect(doc.data()!['quantity'], 10.0);
    });

    test('does not write to wrong uid', () async {
      await repo.addHolding(uid, makeHolding());
      final doc = await fakeFirestore
          .collection('users')
          .doc('other-user')
          .collection('holdings')
          .doc('hold-1')
          .get();
      expect(doc.exists, false);
    });
  });

  group('HoldingRepositoryImpl.watchHoldings', () {
    test('emits empty list when no holdings exist', () async {
      final holdings = await repo.watchHoldings(uid).first;
      expect(holdings, isEmpty);
    });

    test('emits all holdings for user', () async {
      await repo.addHolding(uid, makeHolding(id: 'h1', ticker: 'AAPL'));
      await repo.addHolding(uid, makeHolding(id: 'h2', ticker: 'MSFT'));

      final holdings = await repo.watchHoldings(uid).first;
      expect(holdings.length, 2);
      expect(holdings.map((h) => h.ticker), containsAll(['AAPL', 'MSFT']));
    });

    test('isolates data per user', () async {
      await repo.addHolding('other-user', makeHolding());
      final holdings = await repo.watchHoldings(uid).first;
      expect(holdings, isEmpty);
    });
  });

  group('HoldingRepositoryImpl.updateHolding', () {
    test('updates existing document fields', () async {
      final holding = makeHolding();
      await repo.addHolding(uid, holding);

      final updated = holding.copyWith(currentPrice: 220.0, quantity: 15.0);
      await repo.updateHolding(uid, updated);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('holdings')
          .doc(holding.id)
          .get();

      expect(doc.data()!['currentPrice'], 220.0);
      expect(doc.data()!['quantity'], 15.0);
    });
  });

  group('HoldingRepositoryImpl.deleteHolding', () {
    test('removes document from Firestore', () async {
      final holding = makeHolding();
      await repo.addHolding(uid, holding);
      await repo.deleteHolding(uid, holding.id);

      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('holdings')
          .doc(holding.id)
          .get();

      expect(doc.exists, false);
    });

    test('does not affect other holdings', () async {
      await repo.addHolding(uid, makeHolding(id: 'h1', ticker: 'DELETE_ME'));
      await repo.addHolding(uid, makeHolding(id: 'h2', ticker: 'KEEP_ME'));

      await repo.deleteHolding(uid, 'h1');

      final holdings = await repo.watchHoldings(uid).first;
      expect(holdings.length, 1);
      expect(holdings.first.ticker, 'KEEP_ME');
    });
  });
}
