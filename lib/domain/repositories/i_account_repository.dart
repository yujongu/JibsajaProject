import '../entities/account.dart';

abstract class IAccountRepository {
  Stream<List<Account>> watchAccounts(String uid);
  Future<void> addAccount(String uid, Account account);
  Future<void> updateAccount(String uid, Account account);
  Future<void> deleteAccount(String uid, String id);
}
