import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/sheet_profile_store.dart';
import '../../data/datasources/sheets_local_cache.dart';
import '../../domain/entities/sheet_profile.dart';
import 'preferences_providers.dart';

/// Persistence for the two fixed sheet endpoint slots.
final sheetProfileStoreProvider = Provider<SheetProfileStore>(
  (ref) => SheetProfileStore(ref.watch(sharedPreferencesProvider)),
);

/// Immutable snapshot of both slots plus which one is active.
class SheetProfilesState {
  const SheetProfilesState({
    required this.test,
    required this.real,
    required this.activeId,
  });

  final SheetProfile test;
  final SheetProfile real;

  /// [SheetProfile.testId] or [SheetProfile.realId].
  final String activeId;

  SheetProfile get activeProfile =>
      activeId == SheetProfile.realId ? real : test;

  /// The two slots in display order.
  List<SheetProfile> get all => [test, real];

  SheetProfilesState copyWith({
    SheetProfile? test,
    SheetProfile? real,
    String? activeId,
  }) {
    return SheetProfilesState(
      test: test ?? this.test,
      real: real ?? this.real,
      activeId: activeId ?? this.activeId,
    );
  }
}

/// Loads both slots from the store and exposes switching/editing. Every
/// mutation persists first, then updates in-memory state — the store is the
/// source of truth across restarts.
class SheetProfilesNotifier extends Notifier<SheetProfilesState> {
  @override
  SheetProfilesState build() {
    final store = ref.watch(sheetProfileStoreProvider);
    return SheetProfilesState(
      test: store.read(SheetProfile.testId),
      real: store.read(SheetProfile.realId),
      activeId: store.activeId(),
    );
  }

  /// Makes [id] the active sheet. Everything watching
  /// [activeSheetProfileProvider] (repository, data streams) rebuilds and
  /// refetches automatically.
  void switchTo(String id) {
    if (id == state.activeId) return;
    ref.read(sheetProfileStoreProvider).setActive(id);
    state = state.copyWith(activeId: id);
  }

  /// Persists an edited slot (URL / API key). When the slot is re-pointed at
  /// a *different* sheet URL, its cache (keyed by slot id) is evicted first —
  /// otherwise the previous sheet's transactions/dashboard would flash on the
  /// next load before the live refetch against the new URL lands.
  void updateProfile(SheetProfile profile) {
    final previous =
        profile.id == SheetProfile.realId ? state.real : state.test;
    if (previous.webAppUrl != profile.webAppUrl) {
      SheetsLocalCache(ref.read(sharedPreferencesProvider),
              profileId: profile.id)
          .evict();
    }
    ref.read(sheetProfileStoreProvider).writeProfile(profile);
    state = profile.id == SheetProfile.realId
        ? state.copyWith(real: profile)
        : state.copyWith(test: profile);
  }
}

final sheetProfilesProvider =
    NotifierProvider<SheetProfilesNotifier, SheetProfilesState>(
        SheetProfilesNotifier.new);

/// The endpoint the app is currently talking to. Watching this is what makes
/// a profile switch propagate: `sheetsRepositoryProvider` rebuilds, and the
/// stream providers watching it refetch against the new sheet.
final activeSheetProfileProvider = Provider<SheetProfile>(
  (ref) => ref.watch(sheetProfilesProvider).activeProfile,
);
