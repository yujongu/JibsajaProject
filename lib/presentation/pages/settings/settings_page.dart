import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/sheet_profile.dart';
import '../../providers/sheet_profile_providers.dart';
import '../../providers/theme_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../history/history_page.dart';

/// Minimalist settings: pick which sheet endpoint the app talks to ("Test" /
/// "Real"), edit each slot's URL + API key, and reach the API call history.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profiles = ref.watch(sheetProfilesProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'Settings',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SectionLabel('Appearance', isDark: isDark),
            const SizedBox(height: 8),
            const _ThemeModeCard(),
            const SizedBox(height: 12),
            _SectionLabel('Active sheet', isDark: isDark),
            const SizedBox(height: 8),
            for (final profile in profiles.all) ...[
              _ProfileTile(
                profile: profile,
                isActive: profile.id == profiles.activeId,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _SectionLabel('Diagnostics', isDark: isDark),
            const SizedBox(height: 8),
            GlassListTile(
              leading: _LeadingIcon(
                icon: Icons.history_rounded,
                color: AppColors.secondaryFallback,
              ),
              title: 'API call history',
              subtitle: 'Every row the app sent to the sheet',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.textTertiaryLight,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-segment appearance picker. Follows the OS by default; picking Light
/// or Dark pins the app to that theme.
class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);

    return GlassCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _ThemeSegment(
            mode: ThemeMode.system,
            label: 'System',
            icon: Icons.brightness_auto_rounded,
            isSelected: selected == ThemeMode.system,
          ),
          _ThemeSegment(
            mode: ThemeMode.light,
            label: 'Light',
            icon: Icons.light_mode_rounded,
            isSelected: selected == ThemeMode.light,
          ),
          _ThemeSegment(
            mode: ThemeMode.dark,
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            isSelected: selected == ThemeMode.dark,
          ),
        ],
      ),
    );
  }
}

class _ThemeSegment extends ConsumerWidget {
  const _ThemeSegment({
    required this.mode,
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(11);
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textTertiary : AppColors.textTertiaryLight);

    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: () => ref.read(themeModeProvider.notifier).set(mode),
          borderRadius: radius,
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.isDark,
  });

  final SheetProfile profile;
  final bool isActive;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = profile.isConfigured
        ? _shortUrl(profile.webAppUrl)
        : 'Not configured — tap to set up';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => _onTap(context, ref),
      child: Row(
        children: [
          _LeadingIcon(
            icon: profile.id == SheetProfile.realId
                ? Icons.verified_rounded
                : Icons.science_rounded,
            color: profile.id == SheetProfile.realId
                ? AppColors.primary
                : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: profile.isConfigured
                            ? (isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight)
                            : AppColors.warning,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isActive)
            const Icon(Icons.check_circle_rounded,
                size: 22, color: AppColors.positive)
          else
            Icon(Icons.radio_button_unchecked_rounded,
                size: 22,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.textTertiaryLight),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            tooltip: 'Edit ${profile.name} sheet',
            color:
                isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            onPressed: () => _showEditSheet(context, profile),
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref) {
    if (isActive) return;
    if (!profile.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Set the ${profile.name} sheet URL first')));
      _showEditSheet(context, profile);
      return;
    }
    ref.read(sheetProfilesProvider.notifier).switchTo(profile.id);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${profile.name} sheet')));
  }

  /// Middle-elided URL so the tile stays one line.
  static String _shortUrl(String url) {
    const head = 30, tail = 12;
    if (url.length <= head + tail + 1) return url;
    return '${url.substring(0, head)}…${url.substring(url.length - tail)}';
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color:
              isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

void _showEditSheet(BuildContext context, SheetProfile profile) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditProfileSheet(profile: profile),
  );
}

/// Bottom-sheet form for one slot's endpoint URL + API key.
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final SheetProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  bool _revealKey = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.profile.webAppUrl);
    _keyCtrl = TextEditingController(text: widget.profile.apiKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(sheetProfilesProvider.notifier).updateProfile(
          widget.profile.copyWith(
            webAppUrl: _urlCtrl.text.trim(),
            apiKey: _keyCtrl.text.trim(),
          ),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.profile.name} sheet saved')));
  }

  static String? _validateUrl(String? v) {
    final url = v?.trim() ?? '';
    if (url.isEmpty) return 'Required';
    if (!url.startsWith('https://')) return 'Must be an https:// URL';
    if (!url.contains('/exec')) {
      return 'Should be an Apps Script web app /exec URL';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      // Keep the fields above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetDragHandle(isDark: isDark),
              const SizedBox(height: 12),
              SheetTitleRow(
                  title: '${widget.profile.name} sheet', isDark: isDark),
              const SizedBox(height: 20),
              FieldLabel(label: 'WEB APP URL', isDark: isDark),
              const SizedBox(height: 8),
              SheetTextField(
                ctrl: _urlCtrl,
                hint: 'https://script.google.com/macros/s/…/exec',
                isDark: isDark,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.url,
                validator: _validateUrl,
              ),
              const SizedBox(height: 16),
              FieldLabel(label: 'API KEY', isDark: isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _keyCtrl,
                obscureText: !_revealKey,
                style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w500),
                decoration:
                    sheetInputDeco(isDark: isDark, hint: 'Optional shared secret')
                        .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _revealKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 19,
                    ),
                    tooltip: _revealKey ? 'Hide key' : 'Reveal key',
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight,
                    onPressed: () => setState(() => _revealKey = !_revealKey),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Save', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
