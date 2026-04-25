import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Wraps the app shell with the correct background.
/// Light mode: flat surface color (#f8f9fb).
/// Dark mode: subtle dark gradient.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return ColoredBox(
        color: AppColors.background,
        child: child,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
          colors: [
            AppColors.darkGradientStart,
            AppColors.darkGradientMid,
            AppColors.darkGradientEnd,
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Use this as the Scaffold for each feature page.
/// Sets transparent background so the app shell background shows through.
class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.leading,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
              leading: leading,
              backgroundColor: Colors.transparent,
            )
          : null,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: SafeArea(
        top: true,
        bottom: false,
        child: body,
      ),
    );
  }
}
