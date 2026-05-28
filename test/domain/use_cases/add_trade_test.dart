import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';
import 'package:jibsaja/domain/entities/asset_type.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_sheets_sync_repository.dart';
import 'package:jibsaja/domain/repositories/i_transaction_repository.dart';
import 'package:jibsaja/domain/use_cases/add_trade.dart';

class _FakeTxRepo implements ITransactionRepository {
  final List<Transaction> added = [];
  final List<List<Transaction>> batches = [];
  final List<Transaction> updated = [];

  @override
  Future<void> addTransaction(String uid, Transaction tx) async => added.add(tx);

  @override
  Future<void> batchAddTransactions(String uid, List<Transaction> txs) async =>
      batches.add(txs);

  @override
  Future<void> updateTransaction(String uid, Transaction tx) async =>
      updated.add(tx);

  @override
  Future<void> deleteTransaction(String uid, String id) async {}

  @override
  Stream<List<Transaction>> watchTransactions(String uid) => const Stream.empty();

  @override
  Stream<List<Transaction>> watchRecentTransactions(String uid, {int limit = 5}) =>
      const Stream.empty();
}

class _FakeSheetsRepo implements ISheetsSyncRepository {
  int tradeAppends = 0;
  int transferAppends = 0;

  @override
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
  }) async {
    tradeAppends++;
  }

  @override
  Future<void> appendTransferRows({
    required DateTime date,
    required String fromAccountName,
    required String toAccountName,
    required double amount,
    required String debitTxId,
    required String creditTxId,
  }) async {
    transferAppends++;
  }
}

Account makeAccount({
  String id = 'invest-1',
  String name = 'Investment',
  AccountType type = AccountType.investment,
  String currency = 'USD',
}) {
  final now = DateTime.now();
  return Account(
    id: id,
    userId: 'user-1',
    name: name,
    type: type,
    balance: 0,
    currency: currency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _FakeTxRepo repo;
  late _FakeSheetsRepo sheets;
  late AddTrade useCase;
  const uid = 'user-1';
  final date = DateTime(2025, 3, 10);
  final investAccount = makeAccount();
  final cashAccount = makeAccount(
    id: 'cash-1',
    name: 'Cash',
    type: AccountType.checking,
    currency: 'USD',
  );

  setUp(() {
    repo = _FakeTxRepo();
    sheets = _FakeSheetsRepo();
    useCase = AddTrade(repo, sheets);
  });

  group('AddTrade — new buy without linked cash account', () {
    test('adds one trade transaction with correct amount', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.buy,
        investAccount: investAccount,
        ticker: 'AAPL',
        assetName: 'Apple',
        assetType: AssetType.stock,
        quantity: 10,
        pricePerUnit: 150,
        date: date,
      );

      expect(repo.added, hasLength(1));
      expect(repo.batches, isEmpty);
      final tx = repo.added.first;
      expect(tx.amount, 1500.0);
      expect(tx.ticker, 'AAPL');
      expect(tx.quantity, 10);
      expect(tx.pricePerUnit, 150);
      expect(tx.type, TransactionType.buy);
      expect(tx.title, 'Buy AAPL');
      expect(tx.accountId, investAccount.id);
    });
  });

  group('AddTrade — new buy with linked cash account', () {
    test('batches trade + transfer leg, does not call addTransaction', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.buy,
        investAccount: investAccount,
        ticker: 'TSLA',
        assetName: 'Tesla',
        assetType: AssetType.stock,
        quantity: 5,
        pricePerUnit: 200,
        date: date,
        linkedCashAccount: cashAccount,
      );

      expect(repo.added, isEmpty);
      expect(repo.batches, hasLength(1));
      final batch = repo.batches.first;
      expect(batch, hasLength(2));

      final trade = batch.firstWhere((tx) => tx.type == TransactionType.buy);
      expect(trade.amount, 1000.0);
      expect(trade.accountId, investAccount.id);

      final transfer =
          batch.firstWhere((tx) => tx.type == TransactionType.transfer);
      expect(transfer.accountId, cashAccount.id);
      expect(transfer.isDebit, true);
      expect(transfer.amount, 1000.0);
    });

    test('sell with linked cash creates credit transfer leg', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.sell,
        investAccount: investAccount,
        ticker: 'TSLA',
        assetName: 'Tesla',
        assetType: AssetType.stock,
        quantity: 5,
        pricePerUnit: 200,
        date: date,
        linkedCashAccount: cashAccount,
      );

      final transfer = repo.batches.first
          .firstWhere((tx) => tx.type == TransactionType.transfer);
      expect(transfer.isDebit, false);
    });
  });

  group('AddTrade — new sell without linked cash account', () {
    test('adds one sell transaction', () async {
      await useCase.call(
        uid: uid,
        type: TransactionType.sell,
        investAccount: investAccount,
        ticker: 'AAPL',
        assetName: 'Apple',
        assetType: AssetType.stock,
        quantity: 3,
        pricePerUnit: 160,
        date: date,
      );

      expect(repo.added, hasLength(1));
      expect(repo.added.first.type, TransactionType.sell);
      expect(repo.added.first.title, 'Sell AAPL');
    });
  });

  group('AddTrade — update existing', () {
    test('calls updateTransaction and does not add or batch', () async {
      final now = DateTime.now();
      final existing = Transaction(
        id: 'tx-old',
        userId: uid,
        accountId: investAccount.id,
        title: 'Buy AAPL',
        amount: 1500,
        type: TransactionType.buy,
        category: TransactionCategory.investment,
        date: date,
        ticker: 'AAPL',
        assetName: 'Apple',
        assetType: AssetType.stock,
        quantity: 10,
        pricePerUnit: 150,
        createdAt: now,
        updatedAt: now,
      );

      await useCase.call(
        uid: uid,
        type: TransactionType.buy,
        investAccount: investAccount,
        ticker: 'AAPL',
        assetName: 'Apple Inc',
        assetType: AssetType.stock,
        quantity: 12,
        pricePerUnit: 155,
        date: date,
        existing: existing,
      );

      expect(repo.updated, hasLength(1));
      expect(repo.added, isEmpty);
      expect(repo.batches, isEmpty);
      final tx = repo.updated.first;
      expect(tx.id, 'tx-old');
      expect(tx.quantity, 12);
      expect(tx.pricePerUnit, 155);
      expect(tx.amount, closeTo(12 * 155, 0.01));
    });
  });

  group('AddTrade — assertion', () {
    test('throws AssertionError for income type', () {
      expect(
        () => useCase.call(
          uid: uid,
          type: TransactionType.income,
          investAccount: investAccount,
          ticker: 'AAPL',
          assetName: 'Apple',
          assetType: AssetType.stock,
          quantity: 1,
          pricePerUnit: 100,
          date: date,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
