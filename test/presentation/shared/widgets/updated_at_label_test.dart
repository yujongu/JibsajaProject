import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/presentation/shared/widgets/updated_at_label.dart';

void main() {
  group('updatedAgoLabel', () {
    final now = DateTime(2026, 7, 4, 15, 30);

    test('under a minute → just now', () {
      expect(
        updatedAgoLabel(now.subtract(const Duration(seconds: 40)), now: now),
        'just now',
      );
    });

    test('under an hour → minutes', () {
      expect(
        updatedAgoLabel(now.subtract(const Duration(minutes: 12)), now: now),
        '12m ago',
      );
    });

    test('under a day → hours', () {
      expect(
        updatedAgoLabel(now.subtract(const Duration(hours: 5)), now: now),
        '5h ago',
      );
    });

    test('a day or older → absolute date', () {
      expect(
        updatedAgoLabel(DateTime(2026, 7, 1, 9, 5), now: now),
        'Jul 1, 09:05',
      );
    });
  });
}
