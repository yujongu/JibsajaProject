import 'package:uuid/uuid.dart';

import '../entities/account.dart';
import '../entities/asset_type.dart';
import '../entities/transaction.dart';
import '../entities/transaction_category.dart';
import '../entities/transaction_type.dart';
import '../repositories/i_sheets_sync_repository.dart';
import '../repositories/i_transaction_repository.dart';

/// Creates or updates a Buy/Sell trade. When the investment account has a
/// linked cash account, also writes a companion transfer leg and syncs both
/// rows to the external sheet. The sheet sync is fire-and-forget.
class AddTrade {
  const AddTrade(this._repo, this._sheets);
  final ITransactionRepository _repo;
  final ISheetsSyncRepository _sheets;

  Future<void> call({
    required String uid,
    required TransactionType type,
    required Account investAccount,
    required String ticker,
    required String assetName,
    required AssetType assetType,
    required double quantity,
    required double pricePerUnit,
    required DateTime date,
    Account? linkedCashAccount,
    Transaction? existing,
  }) async {
    assert(type.isTrade, 'AddTrade only handles buy/sell');

    final amount = quantity * pricePerUnit;
    final now = DateTime.now();
    final isNew = existing == null;
    final txId = isNew ? const Uuid().v4() : existing.id;
    final title = '${type == TransactionType.buy ? 'Buy' : 'Sell'} $ticker';

    final mainTx = Transaction(
      id: txId,
      userId: uid,
      accountId: investAccount.id,
      title: title,
      amount: amount,
      type: type,
      category: TransactionCategory.investment,
      date: date,
      currency: investAccount.currency,
      ticker: ticker,
      assetName: assetName,
      assetType: assetType,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (linkedCashAccount != null && isNew) {
      final isBuy = type == TransactionType.buy;
      final transferId = const Uuid().v4();
      final transferTx = Transaction(
        id: transferId,
        userId: uid,
        accountId: linkedCashAccount.id,
        title: isBuy
            ? 'Transfer Out (Buy $ticker)'
            : 'Transfer In (Sell $ticker)',
        amount: amount,
        type: TransactionType.transfer,
        isDebit: isBuy,
        category: TransactionCategory.other,
        date: date,
        currency: linkedCashAccount.currency,
        createdAt: now,
        updatedAt: now,
      );

      await _repo.batchAddTransactions(uid, [mainTx, transferTx]);

      _sheets
          .appendTradeRows(
            date: date,
            investAccountName: investAccount.name,
            cashAccountName: linkedCashAccount.name,
            type: type,
            ticker: ticker,
            assetName: assetName,
            quantity: quantity,
            price: pricePerUnit,
            amount: amount,
            tradeTxId: txId,
            transferTxId: transferId,
          )
          .ignore();
    } else if (isNew) {
      await _repo.addTransaction(uid, mainTx);
    } else {
      await _repo.updateTransaction(uid, mainTx);
    }
  }
}
