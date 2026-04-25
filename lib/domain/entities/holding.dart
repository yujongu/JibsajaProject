import 'holding_type.dart';

class Holding {
  const Holding({
    required this.id,
    required this.userId,
    required this.name,
    required this.ticker,
    required this.type,
    required this.quantity,
    required this.avgCostPrice,
    required this.currentPrice,
    this.currency = 'USD',
    this.accountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String ticker;
  final HoldingType type;
  final double quantity;
  final double avgCostPrice;
  final double currentPrice;
  final String currency;
  final String? accountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalValue => quantity * currentPrice;
  double get totalCost  => quantity * avgCostPrice;
  double get gainLoss   => totalValue - totalCost;
  double get gainLossPercent =>
      totalCost == 0 ? 0 : (gainLoss / totalCost) * 100;

  Holding copyWith({
    String? name,
    String? ticker,
    HoldingType? type,
    double? quantity,
    double? avgCostPrice,
    double? currentPrice,
    String? currency,
    String? accountId,
  }) {
    return Holding(
      id: id,
      userId: userId,
      name: name ?? this.name,
      ticker: ticker ?? this.ticker,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      avgCostPrice: avgCostPrice ?? this.avgCostPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
