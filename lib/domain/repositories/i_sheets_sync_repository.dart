import '../entities/transaction_type.dart';

abstract class ISheetsSyncRepository {
  /// Appends a Buy/Sell trade row plus its companion Transfer row to the sheet.
  Future<void> appendTradeRows({
    required DateTime date,
    required String investAccountName,
    required String cashAccountName,
    required TransactionType type,
    required String ticker,
    required String assetName,
    required double quantity,
    required double price,
    required double amount,
    required String tradeTxId,
    required String transferTxId,
  });

  /// Appends two Transfer legs (debit + credit) for a standalone transfer.
  Future<void> appendTransferRows({
    required DateTime date,
    required String fromAccountName,
    required String toAccountName,
    required double amount,
    required String debitTxId,
    required String creditTxId,
  });
}
