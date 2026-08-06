import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/theme_mode_store.dart';
import 'preferences_providers.dart';

/// Persistence for the appearance setting.
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => ThemeModeStore(ref.watch(sharedPreferencesProvider)),
);

/// The app's appearance mode. Seeded from the store, so the first frame
/// already renders in the pinned theme — no flash of the other one.
/// Mutations persist first, then update in-memory state.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(themeModeStoreProvider).read();

  void set(ThemeMode mode) {
    if (mode == state) return;
    ref.read(themeModeStoreProvider).write(mode);
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
