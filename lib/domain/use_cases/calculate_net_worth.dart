import '../entities/account.dart';
import '../entities/account_type.dart';
import '../entities/bank_card.dart';
import '../entities/holding.dart';

/// Computes total net worth in KRW:
///   Σ (non-investment account balances) + Σ (holding market values) − Σ (card balances)
/// USD values are converted using the supplied USD→KRW rate. Pure — no I/O.
class CalculateNetWorth {
  const CalculateNetWorth();

  double call({
    required Iterable<Account> accounts,
    required Iterable<Holding> holdings,
    required Iterable<BankCard> cards,
    required double usdToKrwRate,
  }) {
    final accountTotal = accounts
        .where((a) => a.type != AccountType.investment)
        .fold(0.0, (sum, a) => sum + _toKrw(a.balance, a.currency, usdToKrwRate));
    final holdingTotal = holdings.fold(
        0.0, (sum, h) => sum + _toKrw(h.totalValue, h.currency, usdToKrwRate));
    final cardTotal = cards.fold(
        0.0, (sum, c) => sum + _toKrw(c.balance.abs(), c.currency, usdToKrwRate));

    return accountTotal + holdingTotal - cardTotal;
  }

  double _toKrw(double amount, String currency, double rate) =>
      currency == 'USD' ? amount * rate : amount;
}
