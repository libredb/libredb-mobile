@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_1_connections.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_marks.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';

/// The first screen of the introduction: the connection list assembling.
///
/// The screen draws the real list, so what is settled here is the list's own grammar — the strip only on production,
/// a filled PROD badge with black ink, the read-only mark — and the order the rows arrive in. The arrival is read off
/// the opacity of each row rather than off the end state: a step whose three rows all land at once renders the same
/// final frame, which is the one defect a test that looks only at the end cannot see.
void main() {
  /// The step in the box the chassis's hero gives it on a 390pt phone: 318pt wide, scrolled vertically.
  ///
  /// Width is the whole point. The hero absorbs vertical growth by scrolling, so what a text size can still break
  /// is the one axis it cannot yield on — and the row's badges are the part of the real list that is laid out side
  /// by side rather than wrapped.
  Future<void> showInHero(
    WidgetTester tester, {
    required double textScale,
    required Locale locale,
    double width = 318,
  }) async {
    tester.view.physicalSize = Size(width > 390 ? width : 390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
            data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(child: Step1Connections()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> show(WidgetTester tester, {bool disableAnimations = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
            child: const Scaffold(body: Center(child: Step1Connections())),
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, String key) => tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

  Color stripOf(WidgetTester tester, int index) {
    final strip = find.byKey(ValueKey('ob1-strip-$index'));
    if (strip.evaluate().isEmpty) return Colors.transparent;
    return ((tester.widget<Container>(strip)).decoration as BoxDecoration).color!;
  }

  testWidgets('at the end it shows the three connections, their badges and the empty-list line', (tester) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('orders-prod'), findsOneWidget);
    expect(find.text('billing-stage'), findsOneWidget);
    expect(find.text('lab'), findsOneWidget);
    expect(find.text('orders'), findsOneWidget);
    expect(find.text('billing'), findsOneWidget);
    expect(find.text('dvdrental'), findsOneWidget);
    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('STAGING'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
    expect(find.text('Read only'), findsOneWidget);

    final l10n = S.of(tester.element(find.byType(Step1Connections)));
    expect(find.text(l10n.ob1_empty(l10n.connection_list_empty_governed)), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(l10n.ob1_empty(l10n.connection_list_empty_governed))).style!.letterSpacing,
      0,
      reason: 'Material\'s labelSmall tracks 0.5, which wrapped the sentence to four lines where `.empt` takes three',
    );
    expect(
      l10n.ob1_empty(l10n.connection_list_empty_governed),
      isNot(contains('\n')),
      reason:
          'the prototype\'s `.empt` collapses whitespace, so the sentence is one paragraph that wraps, not four lines',
    );

    for (final row in ['ob1-row-0', 'ob1-row-1', 'ob1-row-2']) {
      expect(opacityOf(tester, row), 1.0, reason: '$row should have finished arriving');
    }
    expect(opacityOf(tester, 'ob1-empty'), 1.0);
  });

  testWidgets('the rows arrive one after another, and the empty line only once they are all there', (tester) async {
    await show(tester);
    await tester.pump();

    // The first frame: nothing has moved yet.
    expect(opacityOf(tester, 'ob1-row-0'), 0.0);
    expect(opacityOf(tester, 'ob1-row-1'), 0.0);
    expect(opacityOf(tester, 'ob1-row-2'), 0.0);

    await tester.pump(const Duration(milliseconds: 150));
    final first = opacityOf(tester, 'ob1-row-0');
    final second = opacityOf(tester, 'ob1-row-1');
    expect(first, greaterThan(second), reason: 'the first row leads the second');
    expect(second, greaterThan(0.0), reason: 'the second row has begun by 150 ms');
    expect(opacityOf(tester, 'ob1-row-2'), 0.0, reason: 'the third row has not begun at 150 ms');

    // 500 ms: every row has begun and the sentence still waits.
    await tester.pump(const Duration(milliseconds: 350));
    expect(opacityOf(tester, 'ob1-row-2'), greaterThan(0.0));
    expect(opacityOf(tester, 'ob1-empty'), 0.0, reason: 'the empty-list line waits for the rows');

    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester, 'ob1-empty'), greaterThan(0.0), reason: 'the empty-list line has begun by 1000 ms');
    expect(opacityOf(tester, 'ob1-empty'), lessThan(1.0), reason: 'and has not finished');
  });

  testWidgets('with animations off it settles into its finished state on the first frame', (tester) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    expect(opacityOf(tester, 'ob1-row-0'), 1.0);
    expect(opacityOf(tester, 'ob1-row-1'), 1.0);
    expect(opacityOf(tester, 'ob1-row-2'), 1.0);
    expect(opacityOf(tester, 'ob1-empty'), 1.0);
    expect(find.text('PROD'), findsOneWidget);
    expect(stripOf(tester, 0), EnvironmentColors.production);
  });

  testWidgets('only the production row carries the environment strip, and PROD is filled with black ink', (
    tester,
  ) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    expect(stripOf(tester, 0), EnvironmentColors.production);
    expect(stripOf(tester, 1), Colors.transparent, reason: 'STAGING is not an operator colour and not production');
    expect(stripOf(tester, 2), Colors.transparent, reason: 'DEV is not an operator colour and not production');

    expect(tester.widget<Text>(find.text('PROD')).style?.color, Colors.black);
    final badge = find.ancestor(of: find.text('PROD'), matching: find.byType(DecoratedBox)).first;
    expect(
      (tester.widget<DecoratedBox>(badge).decoration as BoxDecoration).color,
      EnvironmentColors.production,
      reason: 'the badge is filled, not outlined',
    );
  });

  testWidgets('nothing in the step is tappable', (tester) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    final step = find.byType(Step1Connections);
    expect(find.descendant(of: step, matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: step, matching: find.byType(GestureDetector)), findsNothing);
  });

  group('the badges survive an accessibility text size', () {
    for (final locale in [const Locale('en'), const Locale('tr')]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        testWidgets('nothing overflows the hero in ${locale.languageCode} at x$scale', (tester) async {
          await showInHero(tester, textScale: scale, locale: locale);

          expect(tester.takeException(), isNull, reason: 'the row is 318pt wide whatever the text size');
        });
      }
    }

    // The prototype draws a row as `.crow{display:flex;align-items:center}`: the name yields and the badges keep
    // their size. This layout cannot express that without a magic width — both are flex children of one `Row`, so
    // `RenderFlex` splits the free space between them — and on the longest row ("billing-stage" with STAGING and
    // the read-only mark) the two want more than the row has at every text size, so one of them has to give. Here
    // the badge gives, by about a tenth, and the name keeps its characters.
    //
    // So the claim is not "nothing is ever scaled"; it is that a badge is **never scaled below nine tenths** of its
    // own size, in either language. A fit that scaled further would be shrinking the mark rather than fitting it,
    // and the row above already pins that nothing overflows at any text size, which is the property that matters.
    testWidgets('at the ordinary text size a badge is drawn at its own size, or within a tenth of it', (tester) async {
      for (final locale in [const Locale('en'), const Locale('tr')]) {
        await showInHero(tester, textScale: 1.0, locale: locale);

        final badges = find.byWidgetPredicate((w) => w is OnboardingBadge || w is OnboardingReadOnlyPill);
        expect(badges, findsNWidgets(4), reason: 'three environments and one read-only mark');
        for (var i = 0; i < 4; i++) {
          final drawn = tester.getRect(badges.at(i)).size;
          final own = tester.renderObject<RenderBox>(badges.at(i)).size;
          expect(
            drawn.width / own.width,
            greaterThanOrEqualTo(0.9),
            reason: 'badge $i of ${locale.languageCode} is drawn at ${drawn.width} of its own ${own.width}',
          );
          expect(drawn.width / own.width, lessThanOrEqualTo(1.0), reason: 'a badge is never drawn larger than it is');
        }
      }
    });
  });

  /// The row is one line, as the prototype's `.crow{display:flex;align-items:center;gap:10px}` is: the name over the
  /// database on the left, the marks on the right of that same line, the row about 54 high (54, 55, 55 in headless
  /// Chrome at 390x844 in both languages) against the 82 the stacked arrangement drew.
  ///
  /// **The font trap:** Ahem's glyphs are full em squares, so "orders-prod" and "Salt okunur" are a third wider here
  /// than on a phone and the one-line row cannot fit 318 pt under test the way it does on the device. So the one-line
  /// claim is read in a box wide enough for Ahem, and the narrow box is asked the other question — that the row
  /// degrades to the stacked form rather than overflow. Heights are read as differences against the name block's own
  /// height, which cancels the font out.
  group('the row is one line while the marks fit beside the name', () {
    Rect rect(WidgetTester tester, Finder f) => tester.getRect(f);

    testWidgets('where they fit, the row is the name block and the vertical padding, and nothing more', (tester) async {
      const names = ['orders-prod', 'billing-stage', 'lab'];
      const databases = ['orders', 'billing', 'dvdrental'];
      for (final locale in [const Locale('en'), const Locale('tr')]) {
        await showInHero(tester, textScale: 1.0, locale: locale, width: 900);
        for (final index in [0, 1, 2]) {
          final row = find.byKey(ValueKey('ob1-line-$index'));
          final name = rect(tester, find.descendant(of: row, matching: find.text(names[index])));
          final database = rect(tester, find.descendant(of: row, matching: find.text(databases[index])));
          final block = name.expandToInclude(database);
          expect(
            rect(tester, row).height - block.height,
            22,
            reason:
                'row $index (${locale.languageCode}) is taller than its name block: the marks are on their own line',
          );
        }
      }
    });

    testWidgets('where they fit, the marks stand to the right of the name on its line', (tester) async {
      await showInHero(tester, textScale: 1.0, locale: const Locale('tr'), width: 900);
      final row = find.byKey(const ValueKey('ob1-line-0'));
      final name = rect(tester, find.descendant(of: row, matching: find.text('orders-prod')));
      final pill = rect(tester, find.descendant(of: row, matching: find.byType(OnboardingReadOnlyPill)));
      final badge = rect(tester, find.descendant(of: row, matching: find.byType(OnboardingBadge)));
      expect(pill.left, greaterThanOrEqualTo(name.right + 10), reason: 'the pill is beside the name, not under it');
      expect(pill.right, lessThan(badge.left), reason: 'the pill comes first and the badge last');
      expect(badge.center.dy, pill.center.dy);
      expect(badge.center.dy, inInclusiveRange(name.top, name.bottom + 20), reason: 'the marks sit on the name block');
      expect(rect(tester, row).right - badge.right, 11, reason: 'the badge ends at the row\'s own inset');
    });

    testWidgets('where they cannot fit, the marks go under the name and nothing overflows', (tester) async {
      await showInHero(tester, textScale: 3.0, locale: const Locale('tr'));
      final row = find.byKey(const ValueKey('ob1-line-0'));
      final database = rect(tester, find.descendant(of: row, matching: find.text('orders')));
      final pill = rect(tester, find.descendant(of: row, matching: find.byType(OnboardingReadOnlyPill)));
      expect(pill.top, greaterThanOrEqualTo(database.bottom), reason: 'the stacked form is the fallback at x3');
      expect(tester.takeException(), isNull);
    });
  });

  /// The row's geometry, read off the prototype in headless Chrome at 390x844 (Turkish, light; the same in English and
  /// dark): the row is 54 (`padding:11px 11px 11px 0` around a 16 + 2 + 14 name block), the strip is a 4 x 30 bar with
  /// its right corners rounded 2 and is not the row's height, the mark is 17, the gaps are 10, PROD is
  /// `padding:3px 6px;border-radius:4px` around a 14 line (20 tall) and the read-only pill is the same with a 1px
  /// border
  /// and a full radius (22 tall).
  ///
  /// **The font trap:** every number here is a box this widget draws round a line whose height is set by a multiplier
  /// (`14/11` for the mono, `16/12.5` for the name), which Ahem lays out at the same height as the product font, and
  /// every width is read as the box less the text inside it, which cancels the glyph size.
  group('the row is the prototype\'s row', () {
    Rect rect(WidgetTester tester, Finder f) => tester.getRect(f);

    testWidgets('the row is 54 high with a 4 x 30 strip, a 17 mark and 10 between them', (tester) async {
      await showInHero(tester, textScale: 1.0, locale: const Locale('tr'), width: 900);
      final row = rect(tester, find.byKey(const ValueKey('ob1-line-0')));
      final strip = rect(tester, find.byKey(const ValueKey('ob1-strip-0')));
      final mark = rect(tester, find.byKey(const ValueKey('ob1-engine-0')));
      final name = rect(tester, find.text('orders-prod'));

      expect(row.height, closeTo(54, 0.5));
      expect(strip.size, const Size(4, 30));
      expect(strip.left, row.left);
      expect(strip.center.dy, closeTo(row.center.dy, 0.5));
      expect(mark.size, const Size(17, 17));
      expect(mark.left - strip.right, 10);
      expect(name.left - mark.right, 10);
    });

    testWidgets('the card is 166 high: three rows, two rules and a border outside them', (tester) async {
      await showInHero(tester, textScale: 1.0, locale: const Locale('tr'), width: 900);
      final card = rect(tester, find.byKey(const ValueKey('ob1-card')));
      final first = rect(tester, find.byKey(const ValueKey('ob1-line-0')));
      final last = rect(tester, find.byKey(const ValueKey('ob1-line-2')));

      expect(card.height, closeTo(166, 0.5), reason: '54 + 1 + 54 + 1 + 54 inside a 1px border on each side');
      expect(first.top - card.top, closeTo(1, 0.5), reason: 'the border is outside the first row, not under it');
      expect(card.bottom - last.bottom, closeTo(1, 0.5));
    });

    testWidgets('the name is 12.5 semibold and the database is mono, 2 below it', (tester) async {
      await showInHero(tester, textScale: 1.0, locale: const Locale('tr'), width: 900);
      final name = tester.widget<Text>(find.text('orders-prod')).style!;
      final database = tester.widget<Text>(find.text('orders')).style!;

      expect(name.fontSize, 12.5);
      expect(name.fontWeight, FontWeight.w600);
      expect(database.fontSize, 11);
      expect(database.fontFamily, AppTypography.mono);
      expect(database.letterSpacing, 0, reason: 'Material\'s labelSmall tracks 0.5; `.sb` has none');
      expect(name.letterSpacing, closeTo(-0.125, 0.001), reason: '`letter-spacing:-.01em` over 12.5');
      expect(
        rect(tester, find.text('orders')).top - rect(tester, find.text('orders-prod')).bottom,
        closeTo(2, 0.5),
        reason: '`.sb{margin-top:2px}`',
      );
    });

    testWidgets('PROD is 3 and 6 round its line with a 4 radius, and the read-only pill is the same with a border', (
      tester,
    ) async {
      await showInHero(tester, textScale: 1.0, locale: const Locale('tr'), width: 900);
      final prod = find.byType(OnboardingBadge).first;
      final prodText = find.descendant(of: prod, matching: find.text('PROD'));
      final pill = find.byType(OnboardingReadOnlyPill);
      final pillText = find.descendant(of: pill, matching: find.text('Salt okunur'));
      final row = rect(tester, find.byKey(const ValueKey('ob1-line-0')));

      expect(rect(tester, prod).height, closeTo(20, 0.5));
      expect(rect(tester, prod).width - rect(tester, prodText).width, closeTo(12, 0.5));
      expect(rect(tester, pill).height, closeTo(22, 0.5));
      expect(rect(tester, pill).width - rect(tester, pillText).width, closeTo(14, 0.5));
      expect(rect(tester, prod).left - rect(tester, pill).right, closeTo(10, 0.5));
      expect(row.right - rect(tester, prod).right, closeTo(11, 0.5), reason: '`padding:11px 11px 11px 0`');

      final badge = tester.widget<DecoratedBox>(find.descendant(of: prod, matching: find.byType(DecoratedBox)).first);
      expect((badge.decoration as BoxDecoration).borderRadius, BorderRadius.circular(AppRadius.sm));
      final style = tester.widget<Text>(prodText).style!;
      expect(style.fontFamily, AppTypography.mono);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, closeTo(1.1, 0.01));
    });

    testWidgets('STAGING and DEV are quiet ink on the fill, PROD is black on the production red', (tester) async {
      await showInHero(tester, textScale: 1.0, locale: const Locale('tr'), width: 900);
      final scheme = Theme.of(tester.element(find.byType(Step1Connections))).colorScheme;
      final staging = find.byType(OnboardingBadge).at(1);
      final text = tester.widget<Text>(find.descendant(of: staging, matching: find.text('STAGING')));
      final box = tester.widget<DecoratedBox>(find.descendant(of: staging, matching: find.byType(DecoratedBox)).first);

      expect(text.style!.color, scheme.onSurfaceVariant);
      expect((box.decoration as BoxDecoration).color, scheme.surfaceContainerHighest);
    });
  });

  /// The card cuts its rows to its own corners.
  ///
  /// The prototype's card is `overflow:hidden`, and the row's environment strip is drawn inside it, flush with its
  /// left edge. Without the clip the strip is painted at the row's left edge while the card's corner curves away
  /// from it, so on the first row a straight red bar stands outside the rounded rectangle with a gap behind it —
  /// which is what shipped, and what the owner saw.
  testWidgets('the card cuts its rows to its own corners, so no strip stands outside them', (tester) async {
    await show(tester, disableAnimations: true);

    final card = find.byKey(const ValueKey('ob1-card'));
    expect(card, findsOneWidget, reason: 'the card the rows are cut to');

    final clip = find.descendant(of: card, matching: find.byType(ClipRRect), matchRoot: true);
    expect(clip, findsOneWidget, reason: 'the rows are not clipped, so a strip can stand outside the corner');

    final radius = tester.widget<ClipRRect>(clip).borderRadius as BorderRadius;
    expect(
      radius.topLeft.x,
      AppRadius.xl,
      reason: 'the clip has to be the corner the border draws, or the strip is cut on a different curve',
    );

    final cardRect = tester.getRect(card);
    final stripRect = tester.getRect(find.byKey(const ValueKey('ob1-strip-0')));
    expect(
      stripRect.left,
      greaterThanOrEqualTo(cardRect.left),
      reason: 'the first row starts outside the card it belongs to',
    );
  });

  /// The row draws its engine, not its engine's family.
  ///
  /// The prototype's rows are `[[PG,'orders-prod',…],[MY,'billing-stage',…],[PG,'lab',…]]`, and `PG` and `MY` are two
  /// different marks in its source: `PG` is a database cylinder — `<ellipse cx="12" cy="6" rx="7.5" ry="3"/>` over a
  /// body with one band — and `MY` is an arc rising to a filled dot, `<path d="M3 18c3-6 6-9 9-9s6 3 9 9"/>` with
  /// `<circle cx="12" cy="9" r="1.6"/>`. The deck drew the shared `engineIcon` for all three, and that token maps a
  /// *family*: `postgres` and `mysql` are both relational, so all three rows came out as one table glyph.
  ///
  /// **The font trap:** nothing here is a text measurement. The claim is read off the mark widgets themselves and off
  /// the geometry of the paths they draw, and a path's coordinates are the same under Ahem as on a phone.
  group('the row draws its engine', () {
    /// The mark alone. The `Semantics` label sits outside the key on purpose: compared *with* it, `postgres` and
    /// `mysql` differ for free and the test passes without either row drawing its own glyph.
    String markOf(WidgetTester tester, int index) =>
        tester.widget<KeyedSubtree>(find.byKey(ValueKey('ob1-engine-$index'))).child.toString();

    testWidgets('postgres and mysql are two marks, and the two postgres rows share one', (tester) async {
      await show(tester, disableAnimations: true);
      await tester.pump();

      expect(markOf(tester, 0), markOf(tester, 2), reason: 'rows 0 and 2 are both postgres, so they draw one mark');
      expect(
        markOf(tester, 1),
        isNot(markOf(tester, 0)),
        reason: 'row 1 is mysql, which the prototype draws as MY and not as the postgres cylinder',
      );
    });
  });

  /// The read-only mark belongs to the production row, as the design puts it.
  ///
  /// The prototype's own data is `[PG,'orders-prod','orders','PROD',var(--prod),1,1]` — the last two flags are the
  /// strip and the read-only mark, both on the first row — and `[MY,'billing-stage',…,0,0]` carries neither. The
  /// deck built it the other way round, so the screen taught the reader that the staging database is the locked
  /// one and production is not, which is the opposite of what the sentence under it says.
  testWidgets('the two marks on the production row are ten apart, as the prototype\'s row gap is', (tester) async {
    // `.crow{display:flex;align-items:center;gap:10px}`: headless Chrome at 390x844 measures the distance between the
    // read-only pill and the PROD badge as exactly 10 in both languages and both themes. A gap is a number that does
    // not come from text, so Ahem does not touch it.
    await show(tester, disableAnimations: true);

    final prodRow = find.byKey(const ValueKey('ob1-line-0'));
    final env = tester.getRect(find.descendant(of: prodRow, matching: find.byType(OnboardingBadge)));
    final readOnly = tester.getRect(find.descendant(of: prodRow, matching: find.byType(OnboardingReadOnlyPill)));
    expect(env.center.dy, readOnly.center.dy, reason: 'the two marks share a line, so the gap is a horizontal one');
    // The prototype draws the pill first and the badge last: `${r[6]?'<div class="ro">':''}<div class="bdg">`.
    expect(env.left - readOnly.right, 10.0);
  });

  testWidgets('the production row is the read-only one, as the design has it', (tester) async {
    await show(tester, disableAnimations: true);

    final prodRow = find.ancestor(of: find.text('orders-prod'), matching: find.byKey(const ValueKey('ob1-line-0')));
    expect(prodRow, findsOneWidget);
    expect(
      find.descendant(of: prodRow, matching: find.byType(OnboardingReadOnlyPill)),
      findsOneWidget,
      reason: 'the production row carries the read-only mark in the design',
    );
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('billing-stage'), matching: find.byKey(const ValueKey('ob1-line-1'))),
        matching: find.byType(OnboardingReadOnlyPill),
      ),
      findsNothing,
      reason: 'the staging row carries neither flag in the design',
    );
  });
}
