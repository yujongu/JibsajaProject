import '../entities/bank_card.dart';

abstract class ICardRepository {
  Stream<List<BankCard>> watchCards(String uid);
  Future<void> addCard(String uid, BankCard card);
  Future<void> updateCard(String uid, BankCard card);
  Future<void> deleteCard(String uid, String id);
}
