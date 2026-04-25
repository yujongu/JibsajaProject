import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/account_repository_impl.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/account_type.dart';
import '../../domain/repositories/i_account_repository.dart';
import '../../domain/use_cases/compute_account_balance.dart';
import 'auth_providers.dart';
import 'exchange_rate_provider.dart';
import 'transaction_providers.dart';

final accountRepositoryProvider = Provider<IAccountRepository>((ref) {
  return AccountRepositoryImpl(FirebaseFirestore.instance);
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAccounts(user.uid);
});

final _computeBalanceProvider = Provider<ComputeAccountBalance>((ref) {
  return const ComputeAccountBalance();
});

final computedAccountBalanceProvider =
    Provider.family<double, String>((ref, accountId) {
  final account = ref.watch(accountByIdProvider)[accountId];
  if (account == null) return 0.0;
  final txs = ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
  return ref.watch(_computeBalanceProvider)(
    account: account,
    transactions: txs,
  );
});

final totalBalanceProvider = Provider<double>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  final rate = usdToKrw(ref.watch(exchangeRateProvider));
  return accounts.where((a) => a.type.isLiquid).fold(0.0, (total, a) {
    final balance = ref.watch(computedAccountBalanceProvider(a.id));
    final inKrw = a.currency == 'USD' ? balance * rate : balance;
    return total + inKrw;
  });
});

final linkedCashAccountIdsProvider = Provider<Set<String>>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  return accounts
      .where((a) => a.linkedCashAccountId != null)
      .map((a) => a.linkedCashAccountId!)
      .toSet();
});

final accountByIdProvider = Provider<Map<String, Account>>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  return {for (final a in accounts) a.id: a};
});
