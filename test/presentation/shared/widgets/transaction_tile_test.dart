import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/presentation/shared/widgets/transaction_tile.dart';

final _date = DateTime(2026, 8, 24);

SheetTransaction _purchase(TransactionCategory category) => SheetTransaction(
  date: _date,
  account: 'BoA',
  type: TransactionType.purchase,
  category: category,
  description: 'Lunch',
  amount: -1200,
);

SheetTransaction _typed(TransactionType type, {String? rawType}) =>
    SheetTransaction(
      date: _date,
      account: 'BoA',
      type: type,
      description: 'Note',
      amount: -1200,
      rawType: rawType,
    );

/// Pumps tiles at a fixed screen size and text scale, so the block's measured
/// width is deterministic rather than dependent on the host view.
Future<void> _pump(
  WidgetTester tester,
  List<SheetTransaction> txs, {
  double textScale = 1.0,
  Size size = const Size(360, 800),
  String? currency,
  bool showIdentity = true,
}) async {
  // The widget tree lays out against the *view*, not MediaQuery.size — without
  // this the row is 800px wide however small the MediaQuery says the phone is,
  // and nothing ever runs out of room.
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Column(
            children: [
              for (final tx in txs)
                TransactionTile(
                  tx: tx,
                  isDark: false,
                  currency: currency,
                  showIdentity: showIdentity,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Width of the identity block holding [label] — the `SizedBox` the label's
/// column sits in.
double _blockWidth(WidgetTester tester, String label) => tester
    .getSize(
      find
          .ancestor(of: find.text(label), matching: find.byType(SizedBox))
          .first,
    )
    .width;

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The label's rendered color, and the color of the block it actually sits on.
///
/// Found by key: the tile paints two washes, and an index-based ColoredBox
/// finder silently picked the *body* wash — which is lighter, so every
/// assertion passed even with the block painted in the raw hue.
({Color label, Color block}) _labelOnBlock(WidgetTester tester, String label) {
  final text = tester.widget<Text>(find.text(label));
  final ground = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(const ValueKey('block-ground')),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (
    label: text.style!.color!,
    block: (ground.decoration as BoxDecoration).color!,
  );
}

/// Width of the description column — the `Column` holding the title and the
/// account/date line. Every fixture here describes itself as 'Lunch'.
double _descriptionWidth(WidgetTester tester) => tester
    .getSize(
      find
          .ancestor(of: find.text('Lunch'), matching: find.byType(Column))
          .first,
    )
    .width;

void main() {
  // The measurement is memoized in a module-level cache, so without this a test
  // can silently re-read the previous test's number instead of measuring.
  setUp(resetBlockWidthCache);

  group('identity block width', () {
    testWidgets('is the same for every row, whatever its own label', (
      tester,
    ) async {
      await _pump(tester, [
        _purchase(TransactionCategory.food), // 식비 — one of the shortest
        _typed(TransactionType.transfer), // TRANSFER — the longest
      ]);

      expect(_blockWidth(tester, '식비'), _blockWidth(tester, 'TRANSFER'));
    });

    testWidgets('is wide enough that the longest label is not clipped', (
      tester,
    ) async {
      // Every other assertion here is about widths being equal or bounded, and
      // "equal and clipped" satisfies those. This is the one that fails if the
      // block is measured from anything narrower than the whole label set.
      await _pump(tester, [
        _purchase(TransactionCategory.food),
        _typed(TransactionType.transfer),
      ]);

      for (final label in ['식비', 'TRANSFER']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        // didExceedMaxLines is no good here: these labels are single unbreakable
        // words, so a too-narrow block ellipsizes them on one line and never
        // exceeds maxLines. Compare the width the label got against the width it
        // actually needs.
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
          ),
          reason: '$label is clipped inside the block',
        );
      }
    });

    testWidgets('follows the platform text scale', (tester) async {
      await _pump(tester, [_purchase(TransactionCategory.food)]);
      final atNormal = _blockWidth(tester, '식비');
      resetBlockWidthCache();

      await _pump(tester, [
        _purchase(TransactionCategory.food),
      ], textScale: 1.6);

      expect(_blockWidth(tester, '식비'), greaterThan(atNormal));
    });

    testWidgets('an unrecognized type does not widen it', (tester) async {
      await _pump(tester, [_purchase(TransactionCategory.food)]);
      final withoutUnknown = _blockWidth(tester, '식비');

      // Without this the second pump hits the memo and re-reads the number
      // above, so the comparison would hold however the width was derived.
      resetBlockWidthCache();

      // The sheet's own wording is shown for a Type the app doesn't know, and
      // it can be arbitrarily long — it must ellipsize, not widen every row.
      await _pump(tester, [
        _purchase(TransactionCategory.food),
        _typed(TransactionType.unknown, rawType: 'Reimbursement adjustment'),
      ]);

      expect(_blockWidth(tester, '식비'), withoutUnknown);
      expect(_blockWidth(tester, 'REIMBURSEMENT ADJUSTMENT'), withoutUnknown);
    });

    testWidgets('leaves the description room at an accessibility text scale', (
      tester,
    ) async {
      // Found on an iOS simulator at the largest accessibility size: the amount
      // is not a flex child, so uncapped it took the whole row and squeezed the
      // Expanded description to zero width.
      await _pump(
        tester,
        [
          SheetTransaction(
            date: _date,
            account: 'BoA',
            type: TransactionType.purchase,
            category: TransactionCategory.food,
            description: 'Lunch',
            // A real seven-figure ₩ amount — the short one this file uses
            // elsewhere is too narrow to starve anything.
            amount: -10688000,
          ),
        ],
        textScale: 3.1,
        currency: 'KRW',
      );

      final description = tester.getSize(
        find
            .ancestor(of: find.text('Lunch'), matching: find.byType(Column))
            .first,
      );
      expect(description.width, greaterThan(0));
    });

    testWidgets('is capped so a huge text scale cannot eat the row', (
      tester,
    ) async {
      await _pump(tester, [
        _purchase(TransactionCategory.food),
      ], textScale: 4.0);

      expect(_blockWidth(tester, '식비'), lessThanOrEqualTo(360 * 0.30));
    });
  });

  group('label legibility', () {
    // The label is drawn on a block washed in its own hue, so the two colors
    // start out close. Mixing the label toward the theme's text color is what
    // keeps it readable rather than decorative.
    for (final isDark in [false, true]) {
      final name = isDark ? 'dark' : 'light';
      testWidgets('every label clears 4:1 on its own block ($name)', (
        tester,
      ) async {
        final samples = <String, SheetTransaction>{
          for (final c in TransactionCategory.values)
            c.sheetValue.toUpperCase(): _purchase(c),
          // The tightest pairs in both themes are type labels, not categories:
          // Sell 4.20 (light) and Transfer 4.60 (dark).
          for (final t in TransactionType.values)
            if (t != TransactionType.purchase)
              (t == TransactionType.unknown ? 'OTHER' : t.label.toUpperCase()):
                  _typed(t),
        };

        for (final entry in samples.entries) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(size: Size(360, 800)),
                child: Scaffold(
                  body: TransactionTile(tx: entry.value, isDark: isDark),
                ),
              ),
            ),
          );

          final pair = _labelOnBlock(tester, entry.key);
          expect(
            _contrast(pair.label, pair.block),
            greaterThan(4.0),
            reason: '${entry.key} label on its own block ($name)',
          );
        }
      });
    }
  });

  group('showIdentity: false', () {
    // The category detail page is already filtered to one category, so a block
    // on every row would repeat the same icon and word down the whole list.
    testWidgets('draws no block, and no label to repeat', (tester) async {
      await _pump(tester, [
        _purchase(TransactionCategory.food),
      ], showIdentity: false);

      expect(find.byKey(const ValueKey('block-ground')), findsNothing);
      expect(find.text('식비'), findsNothing);
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('gives the width back to the description', (tester) async {
      await _pump(tester, [_purchase(TransactionCategory.food)]);
      final withBlock = _descriptionWidth(tester);

      await _pump(tester, [
        _purchase(TransactionCategory.food),
      ], showIdentity: false);
      final without = _descriptionWidth(tester);

      expect(without, greaterThan(withBlock));
    });

    testWidgets('keeps the category tint on the card', (tester) async {
      await _pump(tester, [
        _purchase(TransactionCategory.food),
      ], showIdentity: false);

      final card = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Lunch'),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect((card.decoration as BoxDecoration).color, isNot(Colors.white));
    });
  });
}
