import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/presentation/extensions/transaction_category_ui.dart';

void main() {
  // The whole point of the palette is that a row is recognizable by color
  // alone; two categories sharing a value quietly defeats that.
  for (final (mode, isDark) in [('light', false), ('dark', true)]) {
    test('every category has a distinct $mode color', () {
      final colors = <Color>{
        for (final c in TransactionCategory.values) c.color(isDark),
      };

      expect(colors, hasLength(TransactionCategory.values.length));
    });
  }

  test('the two modes give every category a different value', () {
    for (final c in TransactionCategory.values) {
      expect(c.color(true), isNot(c.color(false)), reason: c.label);
    }
  });
}
