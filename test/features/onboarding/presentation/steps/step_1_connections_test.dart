@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_1_connections.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// The first screen of the introduction: the connection list assembling.
///
/// The screen draws the real list, so what is settled here is the list's own grammar — the strip only on production,
/// a filled PROD badge with black ink, the read-only mark — and the order the rows arrive in. The arrival is read off
/// the opacity of each row rather than off the end state: a step whose three rows all land at once renders the same
/// final frame, which is the one defect a test that looks only at the end cannot see.
void main() {
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
    final decoration = tester.widget<Container>(find.byKey(ValueKey('ob1-strip-$index'))).decoration as BoxDecoration;
    return (decoration.border! as Border).left.color;
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
    /// The step in the box the chassis's hero gives it on a 390pt phone: 318pt wide, scrolled vertically.
    ///
    /// Width is the whole point. The hero absorbs vertical growth by scrolling, so what a text size can still break
    /// is the one axis it cannot yield on — and the row's badges are the part of the real list that is laid out side
    /// by side rather than wrapped.
    Future<void> showInHero(WidgetTester tester, {required double textScale, required Locale locale}) async {
      tester.view.physicalSize = const Size(390, 844);
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
              child: const Scaffold(
                body: Center(
                  child: SizedBox(width: 318, child: SingleChildScrollView(child: Step1Connections())),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

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

        final badges = find.byWidgetPredicate((w) => w is EnvironmentBadge || w is ReadOnlyChip);
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

  /// The read-only mark belongs to the production row, as the design puts it.
  ///
  /// The prototype's own data is `[PG,'orders-prod','orders','PROD',var(--prod),1,1]` — the last two flags are the
  /// strip and the read-only mark, both on the first row — and `[MY,'billing-stage',…,0,0]` carries neither. The
  /// deck built it the other way round, so the screen taught the reader that the staging database is the locked
  /// one and production is not, which is the opposite of what the sentence under it says.
  testWidgets('the production row is the read-only one, as the design has it', (tester) async {
    await show(tester, disableAnimations: true);

    final prodRow = find.ancestor(of: find.text('orders-prod'), matching: find.byKey(const ValueKey('ob1-strip-0')));
    expect(prodRow, findsOneWidget);
    expect(
      find.descendant(of: prodRow, matching: find.byType(ReadOnlyChip)),
      findsOneWidget,
      reason: 'the production row carries the read-only mark in the design',
    );
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('billing-stage'), matching: find.byKey(const ValueKey('ob1-strip-1'))),
        matching: find.byType(ReadOnlyChip),
      ),
      findsNothing,
      reason: 'the staging row carries neither flag in the design',
    );
  });
}
