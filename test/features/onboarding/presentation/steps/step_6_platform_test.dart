@Tags(['widget'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_6_platform.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// The sixth screen: who allowed the statement of the third screen, and where it was written down.
///
/// Two things here are the payoff of the deck and both of them are order claims, so both are measured rather than
/// looked at:
///
/// * **The log reads newest first**, the order the real Audit tab uses. An audit caught the prototype rendering
///   `Just now → 21 min → 12 min` — the right rows in the wrong order, which is exactly the defect a screenshot
///   cannot show. The rows are therefore read off their painted positions, top to bottom.
/// * **The log writes itself in**, oldest first, so that each new line pushes the older ones down and the newest lands
///   on top. That is the opposite insertion order from the reading order, and the two are asserted apart.
///
/// The drawing is the prototype's (`ob.html`, screen 6, measured in headless Chrome at 390x844 and a device scale of
/// 2): two cards, the grants over the log, a coloured bar down the left of every log line, the time in a column of 74,
/// the outcome a square outlined tag at the end, and the redaction said in the line under the one it belongs to.
///
/// The clock is fixed, because the grant line reads a date.
void main() {
  /// The instant the deck is read at. Fixed so the grant's date is a value the test can state.
  final now = DateTime(2026, 10, 29, 14, 30);

  /// A frame at [elapsed] of the step's timeline, in a hero [width] wide, pumped from the first frame.
  Future<S> pumpStep(
    WidgetTester tester, {
    Duration elapsed = Duration.zero,
    Locale locale = const Locale('en'),
    bool disableAnimations = false,
    double width = 318,
    ThemeData? theme,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = Size(width > 290 ? width + 100 : 390, 1600);
    tester.view.devicePixelRatio = 1.0;
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: locale,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: const Step6Platform()),
              ),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
      );
      if (elapsed > Duration.zero) await tester.pump(elapsed);
    });
    return S.of(tester.element(find.byType(Step6Platform)));
  }

  Finder row(String key) => find.byKey(ValueKey(key));

  /// The painted height of a row's slot. A row that has not been written in yet has none.
  double drawnHeight(WidgetTester tester, String key) => tester.getSize(row(key)).height;

  double topOf(WidgetTester tester, String key) => tester.getTopLeft(row(key)).dy;

  Rect rect(WidgetTester tester, String key) => tester.getRect(row(key));

  void expectInside(WidgetTester tester, String key, Finder text, {required String what}) {
    expect(
      find.descendant(of: row(key), matching: text),
      findsOneWidget,
      reason: what,
    );
  }

  testWidgets('the audit log reads newest first, the order the Audit tab uses', (tester) async {
    final s = await pumpStep(tester, elapsed: Step6Beats.whole);

    expect(topOf(tester, 'ob6-event-0'), lessThan(topOf(tester, 'ob6-event-1')));
    expect(topOf(tester, 'ob6-event-1'), lessThan(topOf(tester, 'ob6-event-2')));
    expectInside(
      tester,
      'ob6-event-0',
      find.text(s.platform_audit_time_just_now),
      what: 'the newest line is not on top',
    );
    expectInside(
      tester,
      'ob6-event-1',
      find.text(s.platform_audit_time_minutes_ago(12)),
      what: 'the middle line is not the 12-minute-old one',
    );
    expectInside(
      tester,
      'ob6-event-2',
      find.text(s.platform_audit_time_minutes_ago(21)),
      what: 'the oldest line is not at the bottom',
    );
  });

  testWidgets('the top row is the reader\'s own SELECT, with the 41 ms and the one row of the third screen', (
    tester,
  ) async {
    final s = await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

    expectInside(tester, 'ob6-event-0', find.textContaining(s.ob6_you), what: 'the top line is not the reader\'s');
    expectInside(tester, 'ob6-event-0', find.textContaining('SELECT'), what: 'the top line is not a SELECT');
    expectInside(
      tester,
      'ob6-event-0',
      find.text('orders-prod · ${s.platform_audit_duration(41)} · ${s.platform_audit_row_count(1)}'),
      what: 'the top line does not carry the 41 ms and the one row the third screen answered with',
    );
    expectInside(
      tester,
      'ob6-event-0',
      find.text(s.platform_audit_status_success),
      what: 'the top line is not marked successful',
    );
  });

  testWidgets('both the reader\'s line and the refused one say the connection withheld the statement', (tester) async {
    final s = await pumpStep(tester, elapsed: Step6Beats.whole);

    expectInside(
      tester,
      'ob6-event-0',
      find.text(s.platform_audit_statement_redacted),
      what: 'the reader\'s line does not say its statement was withheld',
    );
    expectInside(
      tester,
      'ob6-event-2',
      find.text(s.platform_audit_statement_redacted),
      what: 'the refused line does not say its statement was withheld',
    );
    expect(
      find.text(s.platform_audit_statement_redacted),
      findsNWidgets(2),
      reason: 'the colleague\'s line shows none',
    );
    expectInside(
      tester,
      'ob6-event-2',
      find.text(s.platform_audit_status_refused),
      what: 'the refused line is not marked refused',
    );
    expectInside(
      tester,
      'ob6-event-1',
      find.text(s.platform_audit_status_success),
      what: 'the colleague\'s UPDATE is not marked successful',
    );
  });

  testWidgets('the sentences are the prototype\'s, in both languages', (tester) async {
    for (final (locale, redacted) in [
      (const Locale('tr'), 'Bağlantının kayıt ayarı tarafından maskelendi'),
      (const Locale('en'), 'Redacted by the connection\'s capture setting'),
    ]) {
      final s = await pumpStep(tester, elapsed: Step6Beats.whole, locale: locale);
      expect(s.platform_audit_statement_redacted, redacted);
    }
  });

  testWidgets('the grant that let the person read orders-prod names its granter and the day, in the short date', (
    tester,
  ) async {
    final s = await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

    expectInside(tester, 'ob6-grant-0', find.text(s.ob6_you), what: 'the reader\'s own grant is not named as theirs');
    expectInside(
      tester,
      'ob6-grant-0',
      find.text('orders-prod · ${s.platform_grants_granted_by('ayse', '27 Oct')}'),
      what: 'the grant does not say who granted it and on which day, two days ago',
    );
    expectInside(
      tester,
      'ob6-grant-0',
      find.text(s.platform_grants_level_read.toUpperCase()),
      what: 'the grant that let them read is not a read grant',
    );
    expectInside(
      tester,
      'ob6-grant-1',
      find.text(s.platform_grants_level_write.toUpperCase()),
      what: 'the colleague\'s write grant is not a write grant',
    );
    expectInside(tester, 'ob6-grant-1', find.text('orders-prod · ∞'), what: 'the write grant is not open-ended');
  });

  testWidgets('the outcome is the app\'s word and the level its word in capitals, not English in a Turkish deck', (
    tester,
  ) async {
    final s = await pumpStep(tester, elapsed: Step6Beats.whole, locale: const Locale('tr'), width: 700);

    expect(s.platform_audit_status_refused, 'Reddedildi');
    expect(find.text(s.platform_audit_status_success), findsNWidgets(2), reason: 'two of the three lines ran');
    expect(find.text(s.platform_audit_status_refused), findsOneWidget);
    expect(find.text('OKUMA'), findsOneWidget);
    expect(find.text('YAZMA'), findsOneWidget);
    expect(find.text('Veren: ayse, 27 Eki'), findsNothing, reason: 'the granter is in the line with the connection');
    expect(find.textContaining('Veren: ayse, 27 Eki'), findsOneWidget);
  });

  testWidgets('the log writes itself in oldest first, so the newest lands on top', (tester) async {
    await pumpStep(tester, elapsed: Step6Beats.firstLine + const Duration(milliseconds: 100));

    expect(drawnHeight(tester, 'ob6-event-2'), greaterThan(0), reason: 'the oldest line is not written in first');
    expect(drawnHeight(tester, 'ob6-event-1'), 0, reason: 'the middle line arrived before the oldest finished');
    expect(drawnHeight(tester, 'ob6-event-0'), 0, reason: 'the newest line arrived first, so nothing pushed it down');
  });

  testWidgets('nothing in the step answers a finger', (tester) async {
    await pumpStep(tester, elapsed: Step6Beats.whole);

    expect(find.descendant(of: find.byType(Step6Platform), matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: find.byType(Step6Platform), matching: find.byType(GestureDetector)), findsNothing);
  });

  testWidgets('with animations off the whole record is on screen at the first frame', (tester) async {
    final s = await pumpStep(tester, disableAnimations: true);

    for (final key in ['ob6-grant-0', 'ob6-grant-1', 'ob6-event-0', 'ob6-event-1', 'ob6-event-2']) {
      expect(drawnHeight(tester, key), greaterThan(0), reason: '$key is not drawn with animations off');
    }
    expect(find.text(s.platform_audit_statement_redacted), findsNWidgets(2));
    expect(topOf(tester, 'ob6-event-0'), lessThan(topOf(tester, 'ob6-event-2')));
  });

  /// The geometry of the prototype's sixth screen, read in headless Chrome at 390x844 and a device scale of 2 (Turkish,
  /// light; the same in English and dark). The grants are one card: rows of `padding:9px 11px` round a mono who over a
  /// mono when 2 under it, the level a tag of `padding:3px 5px` (22.5 high) at the end, 49 and 50 high. The log is a
  /// second card 14 under it: rows of `padding:8px 11px 8px 0`, a bar of 3 down the leading edge inset 8 top and
  /// bottom, the time in a column of 74, 8 between the pieces, the outcome a tag of `padding:2px 5px` (20.5 high).
  ///
  /// **The font trap:** every height is a box round lines whose heights are multipliers of their sizes, which Ahem lays
  /// out as the product font does, and every x is an inset or a fixed column. The hero is 700 wide so that nothing
  /// wraps in Ahem's full-em glyphs.
  group('the record is the prototype\'s', () {
    const mono = 1.32;
    const eleven = 11.0;

    testWidgets('the grant rows are 9 above and below a who over a when 2 under it, and the tag is 22.5 high', (
      tester,
    ) async {
      await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

      expect(rect(tester, 'ob6-grant-0').height, closeTo(9 + eleven * mono + 2 + eleven * mono + 9, 1.5));
      final tag = tester.getRect(find.byKey(const ValueKey('ob6-level-0')));
      expect(tag.height, closeTo(3 + eleven * mono + 3 + 2, 0.6));
      expect(rect(tester, 'ob6-grant-0').right - tag.right, closeTo(11, 0.6), reason: '11 of padding inside the card');
      final who = tester.getRect(find.descendant(of: row('ob6-grant-0'), matching: find.text('you')));
      final when = tester.getRect(
        find.descendant(of: row('ob6-grant-0'), matching: find.textContaining('orders-prod')),
      );
      expect(when.top - who.bottom, closeTo(2, 0.6));
      expect(who.left - rect(tester, 'ob6-grant-0').left, closeTo(11, 0.6));
    });

    testWidgets('the log card is 14 under the grants card, and every row is 8 inside its rules', (tester) async {
      await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

      expect(
        rect(tester, 'ob6-log').top - rect(tester, 'ob6-grants').bottom,
        closeTo(14, 0.6),
        reason: 'the two cards are 14 apart',
      );
      expect(rect(tester, 'ob6-event-0').height, closeTo(8 + 3 * eleven * mono + 2 + 2 + 8, 2));
      expect(
        rect(tester, 'ob6-event-1').height,
        closeTo(1 + 8 + 2 * eleven * mono + 2 + 8, 2),
        reason: 'with its rule',
      );
    });

    testWidgets('each line has a bar 3 wide and 8 in from the top and the bottom, and the time is 74 wide', (
      tester,
    ) async {
      await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

      for (var i = 0; i < 3; i++) {
        final event = rect(tester, 'ob6-event-$i');
        final bar = rect(tester, 'ob6-bar-$i');
        final time = rect(tester, 'ob6-time-$i');
        expect(bar.width, 3);
        expect(bar.top - event.top, closeTo(i == 0 ? 8 : 9, 0.6), reason: 'bar $i, under a 1px rule after the first');
        expect(event.bottom - bar.bottom, closeTo(8, 0.6), reason: 'bar $i');
        expect(time.width, 74);
        expect(time.left - bar.right, closeTo(8, 0.6));
      }
    });

    testWidgets('the outcome is a square 4 radius tag 20.5 high, in the success ink and the error ink', (tester) async {
      await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

      final success = AppTheme.light().extension<SemanticColors>()!.success;
      final error = AppTheme.light().colorScheme.error;
      for (final (i, ink) in [(0, success), (1, success), (2, error)]) {
        final tag = tester.getRect(find.byKey(ValueKey('ob6-out-$i')));
        expect(tag.height, closeTo(2 + eleven * mono + 2 + 2, 0.6), reason: 'tag $i');
        final box = tester.widget<Container>(find.byKey(ValueKey('ob6-out-$i'))).decoration! as BoxDecoration;
        expect(box.borderRadius, BorderRadius.circular(4));
        expect(box.border!.top.color, ink, reason: 'tag $i');
        expect((tester.widget<Container>(row('ob6-bar-$i')).decoration! as BoxDecoration).color, ink, reason: 'bar $i');
      }
    });

    testWidgets('the level tags are the accent for read and the staging yellow for write, tracked .11em', (
      tester,
    ) async {
      await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

      final read = tester.widget<Container>(find.byKey(const ValueKey('ob6-level-0'))).decoration! as BoxDecoration;
      final write = tester.widget<Container>(find.byKey(const ValueKey('ob6-level-1'))).decoration! as BoxDecoration;
      final scheme = AppTheme.light().colorScheme;
      expect(read.border!.top.color, scheme.primary);
      expect(write.border!.top.color, EnvironmentColors.staging);
      final style = tester.widget<Text>(find.text('READ')).style!;
      expect(style.fontFamily, AppTypography.mono);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, closeTo(1.21, 0.001));
    });

    testWidgets('the reader\'s own grant and line are the accent fill with an 11 radius', (tester) async {
      await pumpStep(tester, elapsed: Step6Beats.whole, width: 700);

      final scheme = AppTheme.light().colorScheme;
      for (final key in ['ob6-grant-box-0', 'ob6-event-box-0']) {
        final box = tester.widget<Container>(row(key)).decoration! as BoxDecoration;
        expect(box.color, scheme.primaryContainer, reason: key);
        expect(box.borderRadius, BorderRadius.circular(11), reason: key);
      }
      expect((tester.widget<Container>(row('ob6-grant-box-1')).decoration as BoxDecoration?)?.color, isNull);
    });
  });

  /// What a measurement of a painted edge is allowed to be out by: a rounded border, not a column of text.
  const rounding = 0.01;

  /// The record has to survive the text size the reader has set.
  ///
  /// The hero is 318pt wide on the phone the deck was measured against and 224 inside the card on the smallest phone
  /// the flow is tested on, and it **scrolls itself vertically** — so what it cannot absorb is width. Android's font
  /// size setting goes to 3.0 and Turkish is the longer of the two languages.
  ///
  /// **The claim is horizontal only.** A height measured under `flutter test` is a claim about Ahem, whose glyphs are
  /// square ems, not about the product font; a width that does not fit is wrong in both.
  group('the record survives the text size the reader has set', () {
    /// How far past the right edge of its box the step paints, and what paints there.
    (double, String) widestRight(WidgetTester tester) {
      var worst = 0.0;
      var what = 'nothing';
      void walk(RenderObject node) {
        if (node is RenderBox && node.hasSize && node.attached) {
          final right = node.localToGlobal(Offset(node.size.width, 0)).dx;
          if (right > worst) {
            worst = right;
            what = node.toStringShort();
          }
        }
        node.visitChildren(walk);
      }

      walk(tester.renderObject(find.byType(Step6Platform)));
      return (worst, what);
    }

    const cases = <(String, double, double, Locale)>[
      ('the hero of the phone it was measured on', 318, 1.0, Locale('en')),
      ('the hero at the largest ordinary text size', 318, 1.3, Locale('tr')),
      ('the hero at an accessibility text size', 318, 2.0, Locale('tr')),
      ('the hero at the largest accessibility text size', 318, 3.0, Locale('tr')),
      ('the hero at the largest accessibility text size in English', 318, 3.0, Locale('en')),
      ('the smallest phone', 224, 1.0, Locale('tr')),
      ('the smallest phone at the largest ordinary text size', 224, 1.3, Locale('tr')),
      ('the smallest phone at an accessibility text size', 224, 2.0, Locale('tr')),
      ('the smallest phone at the largest accessibility text size', 224, 3.0, Locale('tr')),
    ];

    for (final (name, width, scale, locale) in cases) {
      testWidgets('nothing of the record reaches past $name', (tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.delegate.supportedLocales,
              locale: locale,
              home: Scaffold(
                // The hero the chassis gives a step scrolls itself vertically, so a record taller than the box is the
                // ordinary case at an accessibility size; what nothing absorbs is width.
                body: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, child: const Step6Platform()),
                  ),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
                child: child!,
              ),
            ),
          );
        });
        await tester.pump();

        final (right, what) = widestRight(tester);
        expect(
          right,
          lessThanOrEqualTo(width + rounding),
          reason:
              '$what paints ${(right - width).toStringAsFixed(1)}pt past the ${width}pt the hero gives it, at '
              'a text scale of $scale in ${locale.languageCode}',
        );
        expect(tester.takeException(), isNull, reason: 'the record overflowed its box at a text scale of $scale');
      });
    }
  });
}
