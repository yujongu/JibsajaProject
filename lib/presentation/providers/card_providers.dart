import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/card_repository_impl.dart';
import '../../domain/entities/bank_card.dart';
import '../../domain/repositories/i_card_repository.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';

final cardRepositoryProvider = Provider<ICardRepository>((ref) {
  return CardRepositoryImpl(ref.watch(firestoreProvider));
});

final cardsStreamProvider = StreamProvider<List<BankCard>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(cardRepositoryProvider).watchCards(user.uid);
});

final totalCreditAvailableProvider = Provider<double>((ref) {
  final cards = ref.watch(cardsStreamProvider).valueOrNull ?? [];
  return cards.fold(0.0, (total, c) => total + c.balance.abs());
});
