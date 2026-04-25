import '../entities/account.dart';
import '../entities/asset_type.dart';
import '../entities/holding.dart';
import '../entities/holding_type.dart';
import '../entities/transaction.dart';
import '../entities/transaction_type.dart';

/// Derives per-account holdings from buy/sell transactions using the
/// average-cost method. Pure — no I/O, no live prices (overlay those
/// separately in the presentation layer).
class ComputeHoldings {
  const ComputeHoldings();

  List<Holding> call({
    required Iterable<Transaction> transactions,
    required Iterable<Account> accounts,
  }) {
    final accountMap = {for (final a in accounts) a.id: a};

    final trades = transactions
        .where((tx) =>
            tx.type.isTrade &&
            tx.ticker != null &&
            tx.accountId != null &&
            tx.quantity != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final positions = <String, _Position>{};
    for (final tx in trades) {
      final key = '${tx.accountId}:${tx.ticker}';
      final account = accountMap[tx.accountId];
      final pos = positions.putIfAbsent(
        key,
        () => _Position(
          accountId: tx.accountId!,
          ticker: tx.ticker!,
          userId: tx.userId,
          currency: account?.currency ?? tx.currency,
          assetName: tx.assetName ?? tx.ticker!,
          assetType: tx.assetType ?? AssetType.stock,
        ),
      );

      final qty = tx.quantity!;
      final unitPrice = tx.pricePerUnit ?? (qty > 0 ? tx.amount / qty : 0.0);

      if (tx.type == TransactionType.buy) {
        final newQty = pos.quantity + qty;
        pos.avgCostPrice = newQty > 0
            ? (pos.quantity * pos.avgCostPrice + qty * unitPrice) / newQty
            : unitPrice;
        pos.quantity = newQty;
        pos.createdAt ??= tx.date;
        pos.updatedAt = tx.date;
        if (tx.assetName != null) pos.assetName = tx.assetName!;
        if (tx.assetType != null) pos.assetType = tx.assetType!;
      } else {
        pos.quantity = (pos.quantity - qty).clamp(0.0, double.infinity);
        pos.updatedAt = tx.date;
      }
    }

    return positions.values
        .where((p) => p.quantity > 0.000001)
        .map((p) => Holding(
              id: '${p.accountId}:${p.ticker}',
              userId: p.userId,
              name: p.assetName,
              ticker: p.ticker,
              type: _toHoldingType(p.assetType),
              quantity: p.quantity,
              avgCostPrice: p.avgCostPrice,
              currentPrice: p.avgCostPrice,
              currency: p.currency,
              accountId: p.accountId,
              createdAt: p.createdAt ?? DateTime.now(),
              updatedAt: p.updatedAt ?? DateTime.now(),
            ))
        .toList();
  }

  HoldingType _toHoldingType(AssetType t) {
    switch (t) {
      case AssetType.stock:
        return HoldingType.stock;
      case AssetType.etf:
        return HoldingType.etf;
      case AssetType.crypto:
        return HoldingType.crypto;
      case AssetType.bond:
        return HoldingType.bond;
      case AssetType.other:
        return HoldingType.other;
    }
  }
}

class _Position {
  _Position({
    required this.accountId,
    required this.ticker,
    required this.userId,
    required this.currency,
    required this.assetName,
    required this.assetType,
  });
  final String accountId;
  final String ticker;
  final String userId;
  final String currency;
  String assetName;
  AssetType assetType;
  double quantity = 0;
  double avgCostPrice = 0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
