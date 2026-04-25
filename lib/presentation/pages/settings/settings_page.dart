import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../../domain/entities/sync_settings.dart';
import '../../providers/sync_settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider).valueOrNull;
    final settingsAsync = ref.watch(syncSettingsStreamProvider);
    final settings = settingsAsync.valueOrNull ?? SyncSettings.empty;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
          padding: const EdgeInsets.only(
            top: 0,
            bottom: 48,
            left: 20,
            right: 20,
          ),
          children: [
            // ── Header ──────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                Text('Settings', style: textTheme.headlineLarge),
              ],
            ),
            const SizedBox(height: 32),

            // ── Google Sheets Sync ───────────────────────────
            _SectionLabel(label: 'Google Sheets Sync', isDark: isDark),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Toggle row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Sync',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Syncs every 5 minutes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: settings.enabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.primary,
                          onChanged: user == null
                              ? null
                              : (val) {
                                  ref
                                      .read(syncSettingsRepositoryProvider)
                                      .saveSettings(
                                        user.uid,
                                        settings.copyWith(enabled: val),
                                      );
                                },
                        ),
                      ],
                    ),
                  ),

                  _Divider(isDark: isDark),

                  // Last synced
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Last synced',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatLastSynced(settings.lastSyncedAt),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _Divider(isDark: isDark),

                  // Status
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: settings.enabled
                                ? AppColors.positive
                                : (isDark
                                    ? AppColors.textTertiary
                                    : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          settings.enabled ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: settings.enabled
                                ? AppColors.positive
                                : (isDark
                                    ? AppColors.textTertiary
                                    : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── What syncs info card ─────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight),
                      const SizedBox(width: 8),
                      Text(
                        'What syncs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ..._syncItems(isDark).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$1,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondaryLight,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Account section ──────────────────────────────
            _SectionLabel(label: 'Account', isDark: isDark),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          'Signed in as',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          user?.email ?? '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.negative,
                  side: BorderSide(color: AppColors.negative.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                },
              ),
            ),
          ],
        ),
        ), // SafeArea
      ),
    );
  }

  String _formatLastSynced(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  List<(IconData, String)> _syncItems(bool isDark) => [
        (
          Icons.swap_horiz_rounded,
          'Accounts & Cards — two-way sync between the Accounts tab and the app'
        ),
        (
          Icons.swap_horiz_rounded,
          'Transactions (Expense/Deposit) — two-way sync between the Transactions tab and the app'
        ),
        (
          Icons.arrow_downward_rounded,
          'Holdings — one-way from Google Sheets to the app (derived from your Buy/Sell rows)'
        ),
        (
          Icons.schedule_rounded,
          'Firestore → Sheet runs every 5 minutes. Sheet → Firestore runs instantly on edit'
        ),
      ];
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppColors.textTertiary : AppColors.textSecondaryLight,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.darkDivider : AppColors.surfaceContainerLow,
    );
  }
}
