import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/models/holding_model.dart';
import 'package:jibsaja/domain/entities/holding.dart';
import 'package:jibsaja/domain/entities/holding_type.dart';

void main() {
  final fixedDate = DateTime(2024, 3, 10, 9, 0, 0);
  final fixedTs = Timestamp.fromDate(fixedDate);

  Holding makeHolding({
    String id = 'hold-1',
    String userId = 'user-1',
    String name = 'Apple Inc',
    String ticker = 'AAPL',
    HoldingType type = HoldingType.stock,
    double quantity = 10.0,
    double avgCostPrice = 150.0,
    double currentPrice = 175.0,
    String currency = 'USD',
  }) {
    return Holding(
      id: id,
      userId: userId,
      name: name,
      ticker: ticker,
      type: type,
      quantity: quantity,
      avgCostPrice: avgCostPrice,
      currentPrice: currentPrice,
      currency: currency,
      createdAt: fixedDate,
      updatedAt: fixedDate,
    );
  }

  group('HoldingModel.toMap', () {
    test('serializes all fields correctly', () {
      final map = HoldingModel.fromEntity(makeHolding()).toMap();

      expect(map['id'], 'hold-1');
      expect(map['userId'], 'user-1');
      expect(map['name'], 'Apple Inc');
      expect(map['ticker'], 'AAPL');
      expect(map['type'], 'stock');
      expect(map['quantity'], 10.0);
      expect(map['avgCostPrice'], 150.0);
      expect(map['currentPrice'], 175.0);
      expect(map['currency'], 'USD');
      expect(map['createdAt'], fixedTs);
    });

    test('serializes every HoldingType correctly', () {
      for (final type in HoldingType.values) {
        final map = HoldingModel.fromEntity(makeHolding(type: type)).toMap();
        expect(map['type'], type.name);
      }
    });
  });

  group('HoldingModel.fromMap', () {
    test('deserializes all fields correctly', () {
      final map = <String, dynamic>{
        'id': 'hold-1',
        'userId': 'user-1',
        'name': 'Apple Inc',
        'ticker': 'AAPL',
        'type': 'stock',
        'quantity': 10.0,
        'avgCostPrice': 150.0,
        'currentPrice': 175.0,
        'currency': 'USD',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      final holding = HoldingModel.fromMap(map).toEntity();

      expect(holding.name, 'Apple Inc');
      expect(holding.ticker, 'AAPL');
      expect(holding.type, HoldingType.stock);
      expect(holding.quantity, 10.0);
      expect(holding.avgCostPrice, 150.0);
      expect(holding.currentPrice, 175.0);
    });

    test('defaults currency to USD when missing', () {
      final map = <String, dynamic>{
        'id': 'h1',
        'userId': 'u1',
        'name': 'BTC',
        'ticker': 'BTC',
        'type': 'crypto',
        'quantity': 0.5,
        'avgCostPrice': 40000.0,
        'currentPrice': 60000.0,
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(HoldingModel.fromMap(map).currency, 'USD');
    });

    test('unknown type defaults to other', () {
      final map = <String, dynamic>{
        'id': 'h1',
        'userId': 'u1',
        'name': 'X',
        'ticker': 'X',
        'type': 'unknown_type',
        'quantity': 1.0,
        'avgCostPrice': 10.0,
        'currentPrice': 10.0,
        'currency': 'USD',
        'createdAt': fixedTs,
        'updatedAt': fixedTs,
      };
      expect(HoldingModel.fromMap(map).type, HoldingType.other);
    });
  });

  group('HoldingModel toMap/fromMap roundtrip', () {
    test('preserves all values', () {
      final original = makeHolding(
        id: 'rt-1',
        ticker: 'MSFT',
        type: HoldingType.etf,
        quantity: 25.5,
        avgCostPrice: 310.0,
        currentPrice: 420.0,
        currency: 'USD',
      );
      final rt = HoldingModel.fromMap(
        HoldingModel.fromEntity(original).toMap(),
      ).toEntity();

      expect(rt.id, original.id);
      expect(rt.ticker, original.ticker);
      expect(rt.type, original.type);
      expect(rt.quantity, original.quantity);
      expect(rt.avgCostPrice, original.avgCostPrice);
      expect(rt.currentPrice, original.currentPrice);
    });
  });

  group('Holding computed properties', () {
    test('totalValue = quantity * currentPrice', () {
      final h = makeHolding(quantity: 10, currentPrice: 175);
      expect(h.totalValue, 1750.0);
    });

    test('totalCost = quantity * avgCostPrice', () {
      final h = makeHolding(quantity: 10, avgCostPrice: 150);
      expect(h.totalCost, 1500.0);
    });

    test('gainLoss = totalValue - totalCost', () {
      final h = makeHolding(quantity: 10, avgCostPrice: 150, currentPrice: 175);
      expect(h.gainLoss, 250.0);
    });

    test('gainLossPercent is correct', () {
      final h = makeHolding(quantity: 10, avgCostPrice: 100, currentPrice: 120);
      expect(h.gainLossPercent, closeTo(20.0, 0.001));
    });

    test('gainLossPercent is 0 when totalCost is 0', () {
      final h = makeHolding(quantity: 10, avgCostPrice: 0, currentPrice: 50);
      expect(h.gainLossPercent, 0.0);
    });

    test('negative gainLoss when price dropped', () {
      final h = makeHolding(quantity: 10, avgCostPrice: 200, currentPrice: 150);
      expect(h.gainLoss, -500.0);
      expect(h.gainLossPercent, closeTo(-25.0, 0.001));
    });
  });

  group('Holding.copyWith', () {
    test('changes only specified fields', () {
      final original = makeHolding();
      final updated = original.copyWith(currentPrice: 200.0, quantity: 20.0);

      expect(updated.currentPrice, 200.0);
      expect(updated.quantity, 20.0);
      expect(updated.id, original.id);
      expect(updated.ticker, original.ticker);
      expect(updated.avgCostPrice, original.avgCostPrice);
    });
  });
}
