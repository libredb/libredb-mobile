@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_2_browse.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// The second screen of the introduction: the tree, the row counts, then a column closing over into a mask.
///
/// The mask is asserted twice — the clear address is on screen first, the mask is what is left at the end. Only the
/// pair proves a mask: a column that was masked from its first frame renders the same last frame, and the audit that
/// caught the prototype inventing a mask shape is the reason the mask text itself is spelled out here rather than
/// read back off the widget.
void main() {
  /// The step in the box the chassis gives it: [width] wide, and free to be as tall as it likes, which is what the
  /// hero's own scroll view does on the page. [textScale] is the reader's setting, [locale] the phone's.
  Future<void> show(
    WidgetTester tester, {
    bool disableAnimations = false,
    double width = 320,
    double textScale = 1.0,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations, textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: SizedBox(width: width, child: const Step2Browse()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, String key) => tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

  S l10nOf(WidgetTester tester) => S.of(tester.element(find.byType(Step2Browse)));

  testWidgets('the tree unfolds and the three row counts count up to their values', (tester) async {
    await show(tester);
    await tester.pump();

    final l10n = l10nOf(tester);
    expect(find.text('public'), findsOneWidget);
    expect(find.text(l10n.ob2_tables(3)), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3), reason: 'every count starts at nothing, and is the number alone');

    // Half way through the count-up each number is on its way and none has arrived.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('128,440'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('128,440'), findsOneWidget);
    expect(find.text('12,901'), findsOneWidget);
    expect(find.text('44,512'), findsOneWidget);
  });

  testWidgets('the tree leaves and the grid takes its place', (tester) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('public'), findsOneWidget);
    expect(find.text('id'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('public'), findsNothing, reason: 'the tree has slid out');
    expect(find.text('id'), findsOneWidget);
    expect(find.text('email'), findsOneWidget);
    expect(find.text('total'), findsOneWidget);
  });

  testWidgets('the addresses arrive in the clear and then close over into the mask', (tester) async {
    await show(tester);

    // 2900 ms: the grid is in and the values are still the ones the engine answered with.
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text('ayse@libredb.io'), findsOneWidget, reason: 'the clear value is what was shown first');
    expect(find.text('mert@libredb.io'), findsOneWidget);
    expect(find.text('onur@libredb.io'), findsOneWidget);
    expect(find.text('a***@l*********'), findsNothing);
    for (var i = 0; i < 3; i++) {
      expect(opacityOf(tester, 'ob2-mask-lock-$i'), 0.0, reason: 'no padlock while the column is in the clear');
    }

    // The end: the mask is what is left, and the padlock stands beside the column.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('ayse@libredb.io'), findsNothing, reason: 'the clear value is gone');
    expect(find.text('mert@libredb.io'), findsNothing);
    expect(find.text('onur@libredb.io'), findsNothing);
    expect(find.text('a***@l*********'), findsOneWidget, reason: "Studio's own email mask keeps the length");
    expect(find.text('m***@l*********'), findsOneWidget);
    expect(find.text('o***@l*********'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(opacityOf(tester, 'ob2-mask-lock-$i'), 1.0);
    }

    expect(find.text('1249.00'), findsOneWidget, reason: 'an unmatched column is untouched');
    expect(find.text('8842'), findsOneWidget);
    expect(find.text(l10nOf(tester).ob2_why), findsOneWidget);
  });

  testWidgets('the value blurs while it closes over, and the blur clears once the mask is there', (tester) async {
    await show(tester);

    await tester.pump(const Duration(milliseconds: 3150));
    expect(find.byType(ImageFiltered), findsWidgets, reason: 'the column is closing over');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(ImageFiltered), findsNothing, reason: 'the mask is left readable');
  });

  testWidgets('with animations off it settles into its finished state on the first frame', (tester) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    expect(find.text('public'), findsNothing);
    expect(find.text('a***@l*********'), findsOneWidget);
    expect(find.text('ayse@libredb.io'), findsNothing);
    expect(opacityOf(tester, 'ob2-mask-lock-0'), 1.0);
    expect(opacityOf(tester, 'ob2-note'), 1.0);
    expect(find.text(l10nOf(tester).ob2_why), findsOneWidget);
  });

  testWidgets('nothing in the step is tappable', (tester) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    final step = find.byType(Step2Browse);
    expect(find.descendant(of: step, matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: step, matching: find.byType(GestureDetector)), findsNothing);
  });

  /// The geometry of the prototype's second screen, read in headless Chrome at 390x844 (Turkish, light; the same in
  /// English and dark). The tree is a card of four 28 high rows (`padding:6.5px 11px` round a 15 line, the tables
  /// indented to 30 with a guide line at 20), 114 high with its border; the grid is a card of a 28 high header and
  /// three
  /// 29 high rows (a 1px rule over 28), 117 high, in columns of 40, the rest and 66, each cell `padding:7px 8px`
  /// around a 14 mono line, the padlock 10 square and 5 off the value.
  ///
  /// **The font trap:** every height here is a box round a line whose height is a multiplier of its size (`15/12`,
  /// `14/11`), which Ahem lays out as the product font does, and every x is an inset from the card's edge, which the
  /// glyphs do not move.
  group('the tree and the grid are the prototype\'s', () {
    Rect rect(WidgetTester tester, Finder f) => tester.getRect(f);

    testWidgets('the tree is four 28 high rows in a 114 high card, the tables indented to 30', (tester) async {
      await show(tester, width: 318);
      await tester.pump(const Duration(milliseconds: 1500));

      final card = rect(tester, find.byKey(const ValueKey('ob2-tree')));
      expect(card.height, closeTo(114, 0.5));
      for (var i = 0; i < 4; i++) {
        expect(rect(tester, find.byKey(ValueKey('ob2-node-$i'))).height, closeTo(28, 0.5), reason: 'row $i');
      }
      expect(rect(tester, find.text('public')).left - card.left, closeTo(12, 0.5), reason: '1 border + 11 padding');
      expect(rect(tester, find.text('orders')).left - card.left, closeTo(31, 0.5), reason: '1 border + 30 padding');
      expect(
        card.right - rect(tester, find.text('128,440')).right,
        closeTo(12, 0.5),
        reason: 'the count is the number alone, 1 border + 11 in from the right',
      );
    });

    testWidgets('the tree draws a guide line at 20 down every table row, and lights orders in a 11 radius', (
      tester,
    ) async {
      await show(tester, width: 318);
      await tester.pump(const Duration(milliseconds: 1500));

      final card = rect(tester, find.byKey(const ValueKey('ob2-tree')));
      for (var i = 1; i < 4; i++) {
        final guide = rect(tester, find.byKey(ValueKey('ob2-guide-$i')));
        expect(guide.left - card.left, closeTo(21, 0.5), reason: '1 border + 20');
        expect(guide.width, 1);
        expect(guide.height, closeTo(28, 0.5));
      }
      expect(find.byKey(const ValueKey('ob2-guide-0')), findsNothing, reason: 'the schema has no guide');
      final lit = tester.widget<DecoratedBox>(
        find.descendant(of: find.byKey(const ValueKey('ob2-node-1')), matching: find.byType(DecoratedBox)).first,
      );
      expect((lit.decoration as BoxDecoration).borderRadius, BorderRadius.circular(11));
    });

    testWidgets('the grid is a 28 high header over three 29 high rows in a 117 high card', (tester) async {
      await show(tester, width: 318, disableAnimations: true);
      await tester.pump();

      final card = rect(tester, find.byKey(const ValueKey('ob2-grid')));
      expect(card.height, closeTo(117, 0.5));
      expect(rect(tester, find.byKey(const ValueKey('ob2-head'))).height, closeTo(28, 0.5));
      for (var i = 0; i < 3; i++) {
        expect(rect(tester, find.byKey(ValueKey('ob2-row-$i'))).height, closeTo(29, 0.5), reason: 'row $i');
      }
      expect(rect(tester, find.byKey(const ValueKey('ob2-head-id'))).width, closeTo(40, 0.5));
      expect(rect(tester, find.byKey(const ValueKey('ob2-head-total'))).width, closeTo(66, 0.5));
    });

    testWidgets('in the grid the value is 8 in, the padlock 10 square and 5 before it, the total 8 from the right', (
      tester,
    ) async {
      await show(tester, width: 318, disableAnimations: true);
      await tester.pump();

      final card = rect(tester, find.byKey(const ValueKey('ob2-grid')));
      final lock = rect(tester, find.byKey(const ValueKey('ob2-mask-lock-0')));
      final value = rect(tester, find.text('a***@l*********'));
      expect(rect(tester, find.text('id')).left - card.left, closeTo(9, 0.5), reason: '1 border + 8');
      expect(rect(tester, find.text('email')).left - card.left, closeTo(49, 0.5), reason: '1 + 40 + 8');
      expect(lock.size, const Size(10, 10));
      expect(lock.left - card.left, closeTo(49, 0.5));
      expect(value.left - lock.right, closeTo(5, 0.5));
      expect(card.right - rect(tester, find.text('1249.00')).right, closeTo(9, 0.5), reason: '1 border + 8');
    });

    testWidgets('the grid is mono 11, the header 600 tracked .09em, the mask in the accent ink', (tester) async {
      await show(tester, width: 318, disableAnimations: true);
      await tester.pump();

      final scheme = Theme.of(tester.element(find.byType(Step2Browse))).colorScheme;
      final head = tester.widget<Text>(find.text('email')).style!;
      final value = tester.widget<Text>(find.text('a***@l*********')).style!;
      expect(head.fontSize, 11);
      expect(head.fontWeight, FontWeight.w600);
      expect(head.letterSpacing, closeTo(0.99, 0.001));
      expect(head.fontFamily, AppTypography.mono);
      expect(value.fontSize, 11);
      expect(value.fontStyle, isNot(FontStyle.italic), reason: 'the prototype does not set a mask in italics');
      expect(value.color, scheme.onPrimaryContainer);
      expect(value.letterSpacing, 0);
    });

    testWidgets('the note sits 8 under the grid, mono 11 over 1.5, and is not there in the tree\'s phase', (
      tester,
    ) async {
      await show(tester, width: 318);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byKey(const ValueKey('ob2-note')), findsNothing, reason: 'the tree is centred on its own');

      await tester.pump(const Duration(milliseconds: 3000));
      final card = rect(tester, find.byKey(const ValueKey('ob2-grid')));
      final note = rect(tester, find.byKey(const ValueKey('ob2-note')));
      final style = tester.widget<Text>(find.text(l10nOf(tester).ob2_why)).style!;
      expect(note.top - card.bottom, closeTo(8, 0.5));
      expect(style.fontSize, 11);
      expect(style.height, 1.5);
      expect(style.letterSpacing, 0);
    });
  });

  /// The tree's rows are a name and a row count at opposite ends of one line, and a count is as wide as the reader's
  /// text size makes it: at a scale of 3.0 `128.440 satır` is wider than the whole hero, so the line cannot hold it
  /// and the row has to give the count a line of its own. Measured on the hero's real width — 318pt on a 390x844
  /// phone, 248pt on a 320x568 one — because the overflow is a width against a width, not a scale against a scale.
  group('a row count the line cannot hold', () {
    const hero = 318.0;
    const smallHero = 248.0;

    /// Where the timeline is looked at: the tree arriving, the counts arrived, and the grid that replaces it.
    const beats = [Duration(milliseconds: 400), Duration(milliseconds: 1500), Duration(milliseconds: 4200)];

    const overflowing = <(String, double, double, Locale)>[
      ('a phone at an accessibility text size', hero, 2.0, Locale('tr')),
      ('a phone at the largest accessibility text size', hero, 3.0, Locale('tr')),
      ('a phone in English at the largest accessibility text size', hero, 3.0, Locale('en')),
      ('a small phone at the largest ordinary text size', smallHero, 1.3, Locale('tr')),
      ('a small phone at the largest accessibility text size', smallHero, 3.0, Locale('tr')),
    ];

    for (final (name, width, scale, locale) in overflowing) {
      testWidgets('the tree holds its box on $name', (tester) async {
        await show(tester, width: width, textScale: scale, locale: locale);

        for (final beat in beats) {
          await tester.pump(beat);
          expect(tester.takeException(), isNull, reason: 'nothing overflows ${beat.inMilliseconds} ms in');
        }
      });
    }

    // The ordinary text size is the one measured against the approved prototype, and it must not move: the name
    // starts at the row's left edge and the count ends at its right, both on one line.
    for (final (locale, count) in [(const Locale('tr'), '128.440'), (const Locale('en'), '128,440')]) {
      testWidgets('at the ordinary text size the count stays beside the name in ${locale.languageCode}', (
        tester,
      ) async {
        await show(tester, width: hero, locale: locale);
        await tester.pump(const Duration(milliseconds: 1500));

        final tree = tester.getRect(find.byKey(const ValueKey('ob2-tree')));
        final name = tester.getRect(find.text('orders'));
        final rows = tester.getRect(find.text(count));
        expect(rows.center.dy, closeTo(name.center.dy, 0.01), reason: 'one line, the two centred on it');
        expect(name.left - tree.left, closeTo(31, 0.01), reason: 'the name at the left edge of the indented row');
        expect(tree.right - rows.right, closeTo(12, 0.01), reason: 'the count at the right edge of the row');
      });
    }

    // The count is the number alone now, as the prototype writes it, so at 3.0 it still shares a line with the name on
    // a
    // 318 hero (`128.440` is 138 there, against 277 of room). A 200 box is the width at which it cannot.
    testWidgets('at a text size the line cannot hold, the count takes a line under the name', (tester) async {
      await show(tester, width: 200, textScale: 3.0, locale: const Locale('tr'));
      await tester.pump(const Duration(milliseconds: 1500));

      final tree = tester.getRect(find.byKey(const ValueKey('ob2-tree')));
      final name = tester.getRect(find.text('orders'));
      final rows = tester.getRect(find.text('128.440'));
      expect(rows.top, greaterThanOrEqualTo(name.bottom), reason: 'the count is under the name, not beside it');
      expect(rows.left, closeTo(name.left, 0.01), reason: 'and starts where the name starts');
      expect(rows.right, lessThanOrEqualTo(tree.right + 0.01), reason: 'and stays inside the hero');
    });
  });
}
