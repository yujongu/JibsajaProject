import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthChangeNotifier();

String? _redirect(BuildContext context, GoRouterState state) {
  final user = FirebaseAuth.instance.currentUser;
  final isAuthenticated = user != null;
  final loc = state.matchedLocation;
  final isAuthRoute = loc == '/login' || loc == '/register';

  if (!isAuthenticated && !isAuthRoute) return '/login';
  if (isAuthenticated && isAuthRoute) return '/dashboard';
  return null;
}

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  refreshListenable: _authNotifier,
  redirect: _redirect,
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
