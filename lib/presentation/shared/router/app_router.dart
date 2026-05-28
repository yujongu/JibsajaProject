import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../pages/accounts/accounts_page.dart';
import '../../pages/auth/login_page.dart';
import '../../pages/auth/register_page.dart';
import '../../pages/cards/cards_page.dart';
import '../../pages/dashboard/dashboard_page.dart';
import '../../pages/holdings/holdings_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../pages/transactions/transactions_page.dart';
import '../widgets/app_shell.dart';
import '../../providers/auth_providers.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/i_auth_repository.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(IAuthRepository repo) {
    _sub = repo.authStateChanges().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AppUser?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final notifier = _AuthChangeNotifier(authRepo);

  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuthenticated = authRepo.currentUser != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/dashboard';
      return null;
    },
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => const MaterialPage(
          child: SettingsPage(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterPage(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DashboardPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AccountsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/holdings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HoldingsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cards',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CardsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TransactionsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
