import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// Rebuild signal so relative labels ("3m ago") age while the app sits open.
final _minuteTickerProvider = StreamProvider<int>(
  (_) => Stream<int>.periodic(const Duration(minutes: 1), (i) => i),
);

/// Human label for how long ago [updatedAt] was, coarsening with age.
/// [now] is injectable for tests.
String updatedAgoLabel(DateTime updatedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(updatedAt);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  return DateFormat('MMM d, HH:mm').format(updatedAt);
}

/// Tiny "Updated 3m ago" caption shown above sheet-backed content, so the
/// user can tell whether they are looking at fresh or cached data. Renders
/// nothing until a first successful fetch has ever happened.
class UpdatedAtLabel extends ConsumerWidget {
  const UpdatedAtLabel({super.key, required this.updatedAt, required this.isDark});

  final DateTime? updatedAt;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = updatedAt;
    if (at == null) return const SizedBox.shrink();
    ref.watch(_minuteTickerProvider);

    final color =
        isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            'Updated ${updatedAgoLabel(at)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
