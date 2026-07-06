import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialized in `main()` before `runApp` and injected via override, so
/// cached sheet data is readable synchronously from the first frame.
///
/// Lives in its own file (rather than `sheets_providers.dart`) so the
/// profile/audit providers can depend on it without an import cycle.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in main()'),
);
