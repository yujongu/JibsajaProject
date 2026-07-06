import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/api_call_record.dart';
import '../../providers/audit_log_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';

final _listStamp = DateFormat('MM/dd HH:mm');
final _fullStamp = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Local audit log of every sheet-mutating API call, newest first — the
/// reconciliation view for "did the app really send that row?".
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = ref.watch(auditLogRecordsProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'API call history',
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy log as JSON',
            onPressed: records.isEmpty ? null : () => _copyLog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear log',
            onPressed: records.isEmpty ? null : () => _clearLog(context, ref),
          ),
        ],
        body: records.isEmpty
            ? _EmptyState(isDark: isDark)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: records.length,
                itemBuilder: (context, i) =>
                    _RecordTile(record: records[i], isDark: isDark),
              ),
      ),
    );
  }

  void _copyLog(BuildContext context, WidgetRef ref) {
    Clipboard.setData(
        ClipboardData(text: ref.read(auditLogProvider).exportJson()));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Log copied')));
  }

  Future<void> _clearLog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear API call history?'),
        content: const Text(
            'This removes every locally recorded call. The sheet itself is '
            'not touched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    ref.read(auditLogProvider).clear();
    ref.invalidate(auditLogRecordsProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Log cleared')));
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.isDark});
  final ApiCallRecord record;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        record.success ? AppColors.positive : AppColors.negative;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _showDetail(context, record),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              record.success ? Icons.check_rounded : Icons.close_rounded,
              size: 18,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_listStamp.format(record.timestamp)} · '
                  '${record.operation.label} · ${record.sheetName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color:
                isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, ApiCallRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordDetailSheet(record: record),
    );
  }
}

class _RecordDetailSheet extends StatelessWidget {
  const _RecordDetailSheet({required this.record});
  final ApiCallRecord record;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor =
        record.success ? AppColors.positive : AppColors.negative;
    final status = [
      record.success ? 'Success' : 'Failed',
      if (record.httpStatus case final code?) 'HTTP $code',
    ].join(' · ');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ListView(
          controller: scrollController,
          children: [
            SheetDragHandle(isDark: isDark),
            const SizedBox(height: 12),
            SheetTitleRow(title: record.summary, isDark: isDark),
            const SizedBox(height: 16),
            _DetailRow(label: 'Time',
                value: _fullStamp.format(record.timestamp), isDark: isDark),
            _DetailRow(label: 'Operation',
                value: record.operation.label, isDark: isDark),
            _DetailRow(label: 'Sheet', value: record.sheetName, isDark: isDark),
            _DetailRow(label: 'Status',
                value: status, isDark: isDark, valueColor: statusColor),
            if (record.detail case final d?)
              _DetailRow(label: 'Detail', value: d, isDark: isDark),
            const SizedBox(height: 16),
            FieldLabel(label: 'ROWS SENT', isDark: isDark),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  record.rows.isEmpty
                      ? '(no rows)'
                      : record.rows.map(jsonEncode).join('\n'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.textTertiaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ??
                    (isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 40,
            color:
                isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            'No API calls recorded yet.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
