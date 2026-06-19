import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_button.dart';
import 'glass_card.dart';

/// Shown whenever loading from the Google Sheet fails.
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.error,
    required this.isDark,
    this.onRetry,
  });

  final Object error;
  final bool isDark;
  final VoidCallback? onRetry;

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
            child: const Icon(
              Icons.error_outline_rounded,
              size: 24,
              color: AppColors.negative,
            ),
          ),
          const SizedBox(height: 14),
          Text('Could not load data', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '$error',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            GlassButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
