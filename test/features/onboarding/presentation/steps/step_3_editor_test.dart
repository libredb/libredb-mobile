@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_3_editor.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/syntax_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// The third screen's hero: a statement that types itself, runs, and is then replaced by a delete that raises the
/// write confirmation.
///
/// What is settled here is the three things an audit of the prototype caught or could have caught: the typed text is
/// never a doubled fragment and ends complete, the answer is the number the screen promises, and the confirmation
/// quotes all five of the app's own lines. The colours of the confirmation are checked against the roles rather than
/// against a picture, because the prototype's fill was `error` with white on it at 1.90:1.
void main() {
  /// The whole timeline and a little more, so a pump of this length lands on the finished screen.
  const past = Duration(seconds: 6);

  /// The frame the count has finished climbing on, which is before the confirmation takes the answer's place.
  final counted = Step3Editor.answersAt + Step3Editor.countsUpOver + const Duration(milliseconds: 60);

  Future<void> show(
    WidgetTester tester, {
    bool animations = true,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    double heroWidth = 318,
    ThemeData? theme,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
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
                .copyWith(disableAnimations: !animations, textScaler: TextScaler.linear(textScale)),
            // The hero box the chassis gives a step scrolls, as the prototype's does, so a step that
            // grows past it is the ordinary case. What must not happen is an overflow.
            child: Scaffold(
              body: SingleChildScrollView(
                // The hero's own width, not the screen's: the chassis pads the panel 48 pt on the
                // leading edge and 24 on the trailing one, which leaves a step 318 pt on a 390 pt phone.
                // A step tested at the full screen width is tested 48 pt wider than it will ever be.
                child: SizedBox(width: heroWidth, child: const Step3Editor()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What the editor box holds right now, as plain text.
  String statement(WidgetTester tester) {
    final text = tester.widget<Text>(find.byKey(Step3Editor.statementKey));
    return text.textSpan!.toPlainText();
  }

  S l10n(WidgetTester tester) => S.of(tester.element(find.byType(Step3Editor)));

  group('the statement that types itself', () {
    testWidgets('is a prefix of itself at every frame and complete when the typing stops', (tester) async {
      await show(tester);
      final seen = <String>[];
      // Short steps across the typing window, so a frame that held a doubled fragment cannot slip between them.
      for (var elapsed = Duration.zero; elapsed < Step3Editor.runLitAt; elapsed += const Duration(milliseconds: 20)) {
        seen.add(statement(tester));
        await tester.pump(const Duration(milliseconds: 20));
      }
      for (final frame in seen) {
        expect(
          Step3Editor.statement.startsWith(frame),
          isTrue,
          reason: 'the editor held "$frame", which is not a prefix of "${Step3Editor.statement}"',
        );
      }
      expect(seen.last, Step3Editor.statement);
    });

    testWidgets('colours its keywords and strings in the prototype\'s ink and leaves the rest plain', (tester) async {
      await show(tester);
      await tester.pump(Step3Editor.runLitAt);
      final span = tester.widget<Text>(find.byKey(Step3Editor.statementKey)).textSpan! as TextSpan;
      final byText = <String, TextStyle?>{};
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) byText[child.text!] = child.style;
        return true;
      });
      // `select` and `from` are keywords of the app's own SQL rules; `count` and `orders` are not, so they come back
      // in the plain runs between them. The difference between the two is the whole of what reusing the app's own
      // highlighting buys, so both sides of it are checked.
      final keyword = SyntaxColors.keyword(Brightness.light);
      expect(byText['select']?.color, keyword);
      expect(byText['select']?.fontWeight, FontWeight.w600);
      expect(byText['from']?.color, keyword);
      expect(byText[' count(*) ']?.color, isNot(keyword));
      expect(byText[' orders;']?.color, isNot(keyword));
    });

    testWidgets('grows: the frames are not all the finished statement', (tester) async {
      await show(tester);
      await tester.pump(Step3Editor.typeStartsAt + const Duration(milliseconds: 60));
      final early = statement(tester);
      expect(early, isNot(Step3Editor.statement));
      expect(Step3Editor.statement.startsWith(early), isTrue);
    });
  });

  group('the answer', () {
    testWidgets('counts up to 128,440 beside 1 row and 41 ms', (tester) async {
      await show(tester);
      await tester.pump(counted);
      expect(find.text('128,440'), findsOneWidget);
      final s = l10n(tester);
      expect(find.text(s.ob3_meta(s.sql_history_rows(1), s.sql_history_duration(41))), findsOneWidget);
      expect(find.text(s.ob3_count.toUpperCase()), findsOneWidget, reason: 'in capitals, as `.scal .h` sets it');
    });

    testWidgets('is not there before the run answers', (tester) async {
      await show(tester);
      await tester.pump(Step3Editor.answersAt - const Duration(milliseconds: 40));
      expect(find.text('128,440'), findsNothing);
      expect(find.textContaining('128'), findsNothing);
    });
  });

  group('the write confirmation', () {
    // The step may not import the SQL editor's check — `import_guard_test.dart` holds cross-feature imports at zero —
    // so the reason line is written on the step and this test is what keeps it true. A demo statement edited into
    // something the real check flags differently fails here rather than shipping a sheet that says the wrong thing.
    test('says what the editor\'s own check says about the demo statement', () {
      expect(
        const InterimWriteCheck().check(Step3Editor.deleteStatement, isSql: true),
        isA<AsksBeforeRunning>()
            .having((a) => a.reasons, 'reasons', contains(WriteCheckReason.mayWrite))
            .having(
              (a) => a.flaggedWord,
              'flaggedWord',
              const FlaggedWord(word: Step3Editor.flaggedWord, line: Step3Editor.flaggedLine),
            ),
      );
    });

    testWidgets('carries all five of its lines, and the delete that raised it', (tester) async {
      await show(tester);
      await tester.pump(past);
      final s = l10n(tester);
      expect(statement(tester), Step3Editor.deleteStatement);
      expect(find.text(s.write_confirm_title), findsOneWidget);
      expect(find.text(s.write_confirm_reason_may_write_at('DELETE', 1)), findsOneWidget);
      expect(find.text(s.write_confirm_production_prompt), findsOneWidget);
      expect(find.text(s.write_confirm_name_label(Step3Editor.connectionName)), findsOneWidget);
      expect(find.text(s.write_confirm_read_grant), findsOneWidget);
    });

    testWidgets('rises after the delete replaces the select, not before', (tester) async {
      await show(tester);
      await tester.pump(Step3Editor.deletesAt + const Duration(milliseconds: 40));
      final s = l10n(tester);
      expect(statement(tester), Step3Editor.deleteStatement);
      expect(find.text(s.write_confirm_title), findsNothing);
    });

    // The audit that first drew this header on `errorContainer` measured the prototype's old pair, white on `#FCA5A5`
    // at 1.90:1. The prototype's pair is now `--err-fill` / `--on-err`: the error colour with white in the light scope
    // and `#3A0F13` with `#F2F4FB` in the dark one. What matters is the contrast, and both scopes clear 4.5:1.
    testWidgets('is drawn on the prototype\'s error fill, readable in both scopes', (tester) async {
      for (final (theme, fill, ink) in [
        (AppTheme.light(), AppTheme.light().colorScheme.error, AppTheme.light().colorScheme.onError),
        (AppTheme.dark(), AppTheme.dark().colorScheme.errorContainer, AppTheme.dark().colorScheme.onSurface),
      ]) {
        await show(tester, theme: theme);
        await tester.pump(past);
        final header = tester.widget<DecoratedBox>(find.byKey(Step3Editor.sheetHeaderKey));
        expect((header.decoration as BoxDecoration).color, fill);
        final title = tester.widget<Text>(find.text(l10n(tester).write_confirm_title));
        expect(title.style?.color, ink);
        double luminance(Color c) => c.computeLuminance();
        final light = luminance(fill) > luminance(ink) ? fill : ink;
        final dark = luminance(fill) > luminance(ink) ? ink : fill;
        expect((luminance(light) + 0.05) / (luminance(dark) + 0.05), greaterThanOrEqualTo(4.5));
      }
    });
  });

  /// The geometry of the prototype's third screen, read in headless Chrome at 390x844 (Turkish, light; the same in
  /// English and dark). The editor is a card at least 52 high (`padding:10px 12px`, mono 11 over 1.7), the Run pill is
  /// 26 high (`padding:6px 14px` round a mono 11/700 label tracked .1em, in capitals), the answer is a 76 high card —
  /// a 26 high header (`padding:6px 11px`, tracked .13em, in capitals) over a 48 high number (`padding:11px`, mono 26
  /// over a line of 1) — 9 under the bar, and the confirmation is a card whose header is 27 high, its prompt box 28,
  /// its two pills 27, with 11 of margin either side of the box and 10 under the pills.
  ///
  /// **The font trap:** every height here is a box round a line whose height is a multiplier of its size, which Ahem
  /// lays out as the product font does, and every width is read as a box less the text inside it. The hero is 700
  /// wide so that each line of the confirmation is the one line it is on a phone and not one of four in Ahem.
  group('the screen is the prototype\'s', () {
    Rect rect(WidgetTester tester, String key) => tester.getRect(find.byKey(ValueKey(key)));

    testWidgets('the editor is a 52 high card with 12 inside it, and the bar is 8 under it', (tester) async {
      await show(tester, heroWidth: 700);
      await tester.pump(counted);

      final editor = rect(tester, 'ob3-editor');
      expect(editor.height, closeTo(52, 0.5));
      expect(tester.getRect(find.byKey(Step3Editor.statementKey)).left - editor.left, closeTo(13, 0.5));
      expect(
        tester.getRect(find.byKey(Step3Editor.statementKey)).top - editor.top,
        closeTo(11, 0.5),
        reason: 'the statement sits on the top line of the box, 1 border + 10 padding in, not at the bottom of a 52',
      );
      expect(rect(tester, 'ob3-run').top - editor.bottom, closeTo(8, 0.5));
      expect(tester.widget<Text>(find.byKey(Step3Editor.statementKey)).textSpan!.style!.height, 1.7);
    });

    testWidgets('the Run pill is 26 high, 14 round a tracked mono label in capitals', (tester) async {
      await show(tester, heroWidth: 700);
      await tester.pump(counted);

      final pill = rect(tester, 'ob3-run');
      final label = find.descendant(of: find.byKey(const ValueKey('ob3-run')), matching: find.byType(Text));
      final style = tester.widget<Text>(label).style!;
      expect(tester.widget<Text>(label).data, 'RUN');
      expect(pill.height, closeTo(26, 0.5));
      expect(pill.width - tester.getRect(label).width, closeTo(28, 0.5));
      expect(style.fontFamily, AppTypography.mono);
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, closeTo(1.1, 0.001));
    });

    testWidgets('the answer is a 76 high card 9 under the bar: a 26 high header over a 48 high number', (tester) async {
      await show(tester, heroWidth: 700);
      await tester.pump(counted);

      final card = rect(tester, 'ob3-result');
      expect(card.height, closeTo(76, 0.5));
      expect(card.top - rect(tester, 'ob3-run').bottom, closeTo(9, 0.5));
      expect(rect(tester, 'ob3-result-head').height, closeTo(26, 0.5));
      expect(rect(tester, 'ob3-result-value').height, closeTo(48, 0.5));
      final head = tester.widget<Text>(find.text('COUNT'));
      expect(head.style!.letterSpacing, closeTo(1.43, 0.001));
      final value = tester.widget<Text>(find.text('128,440')).style!;
      expect(value.fontSize, 26);
      expect(value.fontWeight, FontWeight.w600);
      expect(value.height, 1);
      expect(value.letterSpacing, closeTo(-0.52, 0.001));
    });

    testWidgets('while the run is pending the line beside the pill is an ellipsis, not an icon', (tester) async {
      await show(tester, heroWidth: 700);
      await tester.pump(Step3Editor.pendingAt + const Duration(milliseconds: 60));

      expect(find.text('\u2026'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('the confirmation is a 27 high header, a 28 high prompt box and two 27 high pills', (tester) async {
      await show(tester, heroWidth: 700);
      await tester.pump(past);

      final sheet = rect(tester, 'ob3-sheet');
      expect(sheet.top - rect(tester, 'ob3-run').bottom, closeTo(9, 0.5));
      expect(tester.getRect(find.byKey(Step3Editor.sheetHeaderKey)).height, closeTo(27, 0.5));
      final box = rect(tester, 'ob3-typebox');
      expect(box.height, closeTo(28, 0.5));
      expect(box.left - sheet.left, closeTo(12, 0.5), reason: '1 border + 11 margin');
      expect(sheet.right - box.right, closeTo(12, 0.5));
      final cancel = rect(tester, 'ob3-cancel');
      final go = rect(tester, 'ob3-go');
      expect(cancel.height, closeTo(27, 0.5));
      expect(go.height, closeTo(27, 0.5));
      expect(go.left - cancel.right, closeTo(7, 0.5));
      expect(cancel.left - sheet.left, closeTo(12, 0.5));
      expect(sheet.bottom - cancel.bottom, closeTo(11, 0.5), reason: '10 under the pills + 1 border');
      expect(cancel.top - box.bottom, closeTo(9, 0.5));
    });

    testWidgets('the header is the error fill with white in light and the error container with text ink in dark', (
      tester,
    ) async {
      await show(tester, heroWidth: 700);
      await tester.pump(past);

      final light = AppTheme.light().colorScheme;
      final header = tester.widget<DecoratedBox>(find.byKey(Step3Editor.sheetHeaderKey));
      expect((header.decoration as BoxDecoration).color, light.error);
      expect(tester.widget<Text>(find.text(l10n(tester).write_confirm_title)).style!.color, light.onError);
      expect(tester.widget<Text>(find.text(l10n(tester).write_confirm_title)).style!.fontWeight, FontWeight.w700);
    });

    testWidgets('the Run pill of the sheet is the header fill at .45 and the Cancel pill is outlined', (tester) async {
      await show(tester, heroWidth: 700);
      await tester.pump(past);

      final go = tester.widget<Opacity>(
        find.ancestor(of: find.byKey(const ValueKey('ob3-go')), matching: find.byType(Opacity)).first,
      );
      expect(go.opacity, 0.45);
      final cancel = tester.widget<Container>(find.byKey(const ValueKey('ob3-cancel')));
      expect((cancel.decoration as BoxDecoration).border, isNotNull);
    });

    testWidgets('the sentences are the prototype\'s, in both languages', (tester) async {
      for (final (locale, body) in [
        (
          const Locale('tr'),
          'Veri değiştirebilecek her deyim önce onay ister. Üretim bağlantısında adını yazmanız gerekir.',
        ),
        (const Locale('en'), 'Anything that may change data asks first. On a production connection you type its name.'),
      ]) {
        await show(tester, locale: locale);
        expect(l10n(tester).ob3_body, body);
      }
    });
  });

  group('the screen itself', () {
    testWidgets('settles into the confirmation at once when animations are off', (tester) async {
      await show(tester, animations: false);
      await tester.pump();
      final s = l10n(tester);
      expect(statement(tester), Step3Editor.deleteStatement);
      expect(find.text(s.write_confirm_title), findsOneWidget);
      expect(find.text(s.write_confirm_read_grant), findsOneWidget);
      expect(find.text('128,440'), findsNothing);
    });

    testWidgets('lays out at every ordinary text scale without overflowing', (tester) async {
      // A `Spacer` with a bare line beside the Run pill overflowed the hero by 80 pt at a scale of 3, and a `Row`
      // under the confirmation by 272 pt. Both grow the screen taller now, which the scrolling hero box can give;
      // an overflow is a FlutterError, so a scale that overflows fails here rather than being drawn with a stripe.
      for (final scale in [1.0, 1.5, 2.0, 3.0]) {
        await show(tester, textScale: scale);
        await tester.pump(past);
      }
    });

    testWidgets('lays out in both languages and in the hero a small phone leaves, without overflowing', (tester) async {
      // The test above asks in English at the hero of a 390 pt phone only, and the overflow it misses is the Run
      // pill's own label: `Çalıştır` at a text scale of 3 is wider than the row it sits in, which walking the six
      // screens inside the chassis measured as 13 pt over on a 390 pt phone and 83 pt over on the 248 pt hero a
      // 320 pt phone leaves. The pill was the row's inflexible child, so it asked for its natural width whatever
      // the row had to give.
      for (final locale in [const Locale('en'), const Locale('tr')]) {
        for (final width in [318.0, 248.0]) {
          for (final scale in [1.0, 1.5, 2.0, 3.0]) {
            await show(tester, locale: locale, textScale: scale, heroWidth: width);
            await tester.pump(past);
          }
        }
      }
    });

    testWidgets('keeps the pill on the leading edge and the line on the trailing one at the ordinary text size', (
      tester,
    ) async {
      // The prototype's own measurement of this hero: the Run pill starts at the hero's left edge and the line
      // beside it ends at the hero's right edge (`runb go` l=0, `meta` l=219 w=99 in a 318 pt hero). Whatever the
      // bar does when the words outgrow it, at the ordinary text size it must still draw exactly this.
      //
      // `counted` is the frame the answer is on: the confirmation has not risen yet, so `Run` is the pill's own
      // label and nothing else on the screen says it.
      await show(tester);
      await tester.pump(counted);
      final s = l10n(tester);
      final pill = find.text(s.sql_editor_run.toUpperCase());
      final meta = find.text(
        s.ob3_meta(s.sql_history_rows(Step3Editor.answerRows), s.sql_history_duration(Step3Editor.answerMilliseconds)),
      );
      final hero = tester.getRect(find.byType(Step3Editor));

      expect(hero.width, 318, reason: 'the hero of a 390 pt phone, which the numbers below are the prototype of');
      expect(
        tester.getRect(pill).left - hero.left,
        14,
        reason: 'the pill label sits 14 inside the hero leading edge, the padding of its own fill',
      );
      expect(hero.right - tester.getRect(meta).right, 0, reason: 'the line ends on the hero trailing edge');
    });

    testWidgets('holds nothing a finger can press', (tester) async {
      await show(tester);
      await tester.pump(past);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('reads the number the Turkish way under a Turkish locale', (tester) async {
      await show(tester, locale: const Locale('tr'));
      await tester.pump(counted);
      expect(find.text('128.440'), findsOneWidget);

      await tester.pump(past);
      final s = l10n(tester);
      expect(find.text(s.write_confirm_title), findsOneWidget);
      expect(find.text(s.write_confirm_read_grant), findsOneWidget);
    });
  });
}
