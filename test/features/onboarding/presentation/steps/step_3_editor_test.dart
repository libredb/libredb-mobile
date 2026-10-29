@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_3_editor.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

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
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
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

    testWidgets('colours its keywords with the role the app colours a real statement with', (tester) async {
      await show(tester);
      await tester.pump(Step3Editor.runLitAt);
      final colors = AppTheme.light().colorScheme;
      final span = tester.widget<Text>(find.byKey(Step3Editor.statementKey)).textSpan! as TextSpan;
      final byText = <String, TextStyle?>{};
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) byText[child.text!] = child.style;
        return true;
      });
      // `select` and `from` are keywords of the app's own SQL rules; `count` and `orders` are not, so they come back
      // in the plain runs between them. The difference between the two is the whole of what reusing the app's own
      // highlighting buys, so both sides of it are checked.
      expect(byText['select']?.color, colors.onPrimaryContainer);
      expect(byText['from']?.color, colors.onPrimaryContainer);
      expect(byText[' count(*) ']?.color, isNot(colors.onPrimaryContainer));
      expect(byText[' orders;']?.color, isNot(colors.onPrimaryContainer));
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
      expect(find.text(s.ob3_count), findsOneWidget);
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

    testWidgets('is drawn on errorContainer with onErrorContainer ink, never error as a fill', (tester) async {
      await show(tester);
      await tester.pump(past);
      final colors = AppTheme.light().colorScheme;
      final header = tester.widget<DecoratedBox>(find.byKey(Step3Editor.sheetHeaderKey));
      expect((header.decoration as BoxDecoration).color, colors.errorContainer);
      final s = l10n(tester);
      final title = tester.widget<Text>(find.text(s.write_confirm_title));
      expect(title.style?.color, colors.onErrorContainer);
      for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) expect(decoration.color, isNot(colors.error));
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
