import '../entities/holding.dart';

abstract class IHoldingRepository {
  Stream<List<Holding>> watchHoldings(String uid);
  Future<void> addHolding(String uid, Holding holding);
  Future<void> updateHolding(String uid, Holding holding);
  Future<void> deleteHolding(String uid, String id);
}
