import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_sheets_sync_repository.dart';
import 'package:jibsaja/domain/repositories/i_transaction_repository.dart';
import 'package:jibsaja/domain/use_cases/add_transfer.dart';

class _FakeTxRepo implements ITransactionRepository {
  List<List<Transaction>> batches = [];

  @override
  Future<void> batchAddTransactions(String uid, List<Transaction> txs) async =>
      batches.add(txs);

  @override
  Future<void> addTransaction(String uid, Transaction tx) async {}

  @override
  Future<void> updateTransaction(String uid, Transaction tx) async {}

  @override
  Future<void> deleteTransaction(String uid, String id) async {}

  @override
  Stream<List<Transaction>> watchTransactions(String uid) => const Stream.empty();

  @override
  Stream<List<Transaction>> watchRecentTransactions(String uid, {int limit = 5}) =>
      const Stream.empty();
}

class _FakeSheetsRepo implements ISheetsSyncRepository {
  int transferAppends = 0;

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
  }) async {}
}

Account makeAccount({required String id, required String name, String currency = 'KRW'}) {
  final now = DateTime.now();
  return Account(
    id: id,
    userId: 'user-1',
    name: name,
    type: AccountType.checking,
    balance: 0,
    currency: currency,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _FakeTxRepo repo;
  late _FakeSheetsRepo sheets;
  late AddTransfer useCase;
  const uid = 'user-1';
  final date = DateTime(2025, 4, 1);
  final checking = makeAccount(id: 'acc-1', name: 'Checking');
  final savings = makeAccount(id: 'acc-2', name: 'Savings');

  setUp(() {
    repo = _FakeTxRepo();
    sheets = _FakeSheetsRepo();
    useCase = AddTransfer(repo, sheets);
  });

  group('AddTransfer — same account', () {
    test('throws ArgumentError when from == to', () async {
      expect(
        () => useCase.call(
          uid: uid,
          fromAccount: checking,
          toAccount: checking,
          amount: 1000,
          date: date,
        ),
        throwsArgumentError,
      );
    });
  });

  group('AddTransfer — different accounts', () {
    test('batches exactly two transactions', () async {
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: savings,
        amount: 50000,
        date: date,
      );

      expect(repo.batches, hasLength(1));
      expect(repo.batches.first, hasLength(2));
    });

    test('debit leg belongs to fromAccount with isDebit=true', () async {
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: savings,
        amount: 50000,
        date: date,
      );

      final batch = repo.batches.first;
      final debit = batch.firstWhere((tx) => tx.isDebit == true);
      expect(debit.accountId, checking.id);
      expect(debit.amount, 50000);
      expect(debit.type, TransactionType.transfer);
    });

    test('credit leg belongs to toAccount with isDebit=false', () async {
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: savings,
        amount: 50000,
        date: date,
      );

      final batch = repo.batches.first;
      final credit = batch.firstWhere((tx) => tx.isDebit == false);
      expect(credit.accountId, savings.id);
      expect(credit.amount, 50000);
    });

    test('debit title mentions toAccount name', () async {
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: savings,
        amount: 50000,
        date: date,
      );

      final debit = repo.batches.first.firstWhere((tx) => tx.isDebit == true);
      expect(debit.title, contains('Savings'));
    });

    test('credit title mentions fromAccount name', () async {
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: savings,
        amount: 50000,
        date: date,
      );

      final credit = repo.batches.first.firstWhere((tx) => tx.isDebit == false);
      expect(credit.title, contains('Checking'));
    });

    test('each leg has a unique id', () async {
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: savings,
        amount: 100,
        date: date,
      );

      final batch = repo.batches.first;
      expect(batch[0].id, isNot(equals(batch[1].id)));
    });

    test('legs inherit currency from their respective accounts', () async {
      final usdAccount = makeAccount(id: 'acc-usd', name: 'USD', currency: 'USD');
      await useCase.call(
        uid: uid,
        fromAccount: checking,
        toAccount: usdAccount,
        amount: 100,
        date: date,
      );

      final batch = repo.batches.first;
      final debit = batch.firstWhere((tx) => tx.isDebit == true);
      final credit = batch.firstWhere((tx) => tx.isDebit == false);
      expect(debit.currency, 'KRW');
      expect(credit.currency, 'USD');
    });
  });
}
