import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// Shown whenever a Firestore stream or future returns an error.
/// Renders a friendlier message for [permission-denied] so the
/// developer / user knows exactly what to fix.
class FirestoreErrorCard extends StatelessWidget {
  const FirestoreErrorCard({
    super.key,
    required this.error,
    required this.isDark,
  });

  final Object error;
  final bool isDark;

  bool get _isPermissionDenied =>
      error is FirebaseException &&
      (error as FirebaseException).code == 'permission-denied';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.negative.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPermissionDenied
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              size: 24,
              color: AppColors.negative,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isPermissionDenied
                ? 'Firestore access denied'
                : 'Could not load data',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _isPermissionDenied
                ? 'Open Firebase Console → Firestore Database → Rules and publish rules that allow authenticated users to read and write their own data.'
                : 'Check your connection and try again.',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
