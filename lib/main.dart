import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/pages/sheet/sheet_view_page.dart';
import 'presentation/shared/theme/app_colors.dart';
import 'presentation/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: JibsajaApp()));
}

class JibsajaApp extends StatelessWidget {
  const JibsajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jibsaja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

/// Two-tab shell: Transactions and Dashboard. Uses an [IndexedStack] so each
/// tab keeps its scroll position and provider state when switching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [SheetViewPage(), DashboardPage()];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _BottomNav(
        index: _index,
        isDark: isDark,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Minimal custom bottom bar — the theme intentionally leaves NavigationBar
/// transparent so the app owns this styling.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  final int index;
  final bool isDark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surfaceCard,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Transactions',
                selected: index == 0,
                isDark: isDark,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.pie_chart_rounded,
                label: 'Dashboard',
                selected: index == 1,
                isDark: isDark,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppColors.primary;
    final unselectedColor =
        isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;
    final color = selected ? selectedColor : unselectedColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
