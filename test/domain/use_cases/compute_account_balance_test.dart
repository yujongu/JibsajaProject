import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/account.dart';
import 'package:jibsaja/domain/entities/account_type.dart';
import 'package:jibsaja/domain/entities/transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/use_cases/compute_account_balance.dart';

Account makeAccount({String id = 'acc-1', double initialBalance = 0}) {
  final now = DateTime.now();
  return Account(
    id: id,
    userId: 'user-1',
    name: 'Test',
    type: AccountType.checking,
    balance: 0,
    initialBalance: initialBalance,
    createdAt: now,
    updatedAt: now,
  );
}

Transaction makeTx({
  String id = 'tx-1',
  String accountId = 'acc-1',
  double amount = 1000,
  TransactionType type = TransactionType.expense,
  bool? isDebit,
}) {
  final now = DateTime.now();
  return Transaction(
    id: id,
    userId: 'user-1',
    accountId: accountId,
    title: 'Test',
    amount: amount,
    type: type,
    category: TransactionCategory.other,
    date: now,
    isDebit: isDebit,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const compute = ComputeAccountBalance();
  final account = makeAccount(initialBalance: 100000);

  group('ComputeAccountBalance', () {
    test('returns initialBalance when no transactions', () {
      expect(compute(account: account, transactions: []), 100000);
    });

    test('income adds to balance', () {
      final result = compute(
        account: account,
        transactions: [
          makeTx(amount: 50000, type: TransactionType.income),
        ],
      );
      expect(result, 150000);
    });

    test('expense subtracts from balance', () {
      final result = compute(
        account: account,
        transactions: [
          makeTx(amount: 30000, type: TransactionType.expense),
        ],
      );
      expect(result, 70000);
    });

    test('transfer in (isDebit=false) adds to balance', () {
      final result = compute(
        account: account,
        transactions: [
          makeTx(amount: 20000, type: TransactionType.transfer, isDebit: false),
        ],
      );
      expect(result, 120000);
    });

    test('transfer out (isDebit=true) subtracts from balance', () {
      final result = compute(
        account: account,
        transactions: [
          makeTx(amount: 15000, type: TransactionType.transfer, isDebit: true),
        ],
      );
      expect(result, 85000);
    });

    test('buy and sell transactions do not affect balance', () {
      final result = compute(
        account: account,
        transactions: [
          makeTx(amount: 999, type: TransactionType.buy),
          makeTx(id: 'tx-2', amount: 888, type: TransactionType.sell),
        ],
      );
      expect(result, 100000);
    });

    test('only counts transactions matching account id', () {
      final result = compute(
        account: account,
        transactions: [
          makeTx(accountId: 'acc-1', amount: 10000, type: TransactionType.income),
          makeTx(id: 'tx-2', accountId: 'acc-other', amount: 99999,
              type: TransactionType.income),
        ],
      );
      expect(result, 110000);
    });

    test('accumulates multiple transactions correctly', () {
      final result = compute(
        account: makeAccount(initialBalance: 0),
        transactions: [
          makeTx(id: 'tx-1', amount: 5000, type: TransactionType.income),
          makeTx(id: 'tx-2', amount: 1000, type: TransactionType.expense),
          makeTx(id: 'tx-3', amount: 2000, type: TransactionType.transfer, isDebit: false),
          makeTx(id: 'tx-4', amount: 500, type: TransactionType.transfer, isDebit: true),
        ],
      );
      // 0 + 5000 - 1000 + 2000 - 500 = 5500
      expect(result, 5500);
    });
  });
}
