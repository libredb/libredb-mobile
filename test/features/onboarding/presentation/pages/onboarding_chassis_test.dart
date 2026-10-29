@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

import '../../../../support/test_env.dart';

/// The frame the six screens of the introduction are shown in: the counter, the caption, the headline with its one
/// accented word, the body, the six-segment progress rule and the two controls.
///
/// The frame is tested on its own, with no hero: a step draws only its animated hero and the chassis draws
/// everything around it, so every claim here holds whatever the six steps turn out to paint.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<S> pumpFrame(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    bool dark = false,
    double textScale = 1.0,
    bool disableAnimations = false,
    Size viewport = const Size(390, 844),
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      BlocProvider<OnboardingCubit>.value(
        value: cubit,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: locale,
          home: const OnboardingPage(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return S.of(tester.element(find.byType(OnboardingPage)));
  }

  /// Moves to the next screen the way a user does: the deck is turned by dragging it, and the primary control is
  /// gone from every screen but the last.
  Future<void> advance(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
    await tester.pump();
    await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
  }

  /// The colour each of the six progress segments is painted in, left to right.
  List<Color?> segments(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(of: find.byKey(onboardingProgressKey), matching: find.byType(DecoratedBox)),
      )
      .map((box) => (box.decoration as BoxDecoration).color)
      .toList();

  /// The fade the words of the current step are rising inside.
  FadeTransition entrance(WidgetTester tester) => tester.widget<FadeTransition>(
    find.ancestor(of: find.byKey(onboardingHeadlineKey), matching: find.byType(FadeTransition)).first,
  );

  group('the counter reads the step', () {
    testWidgets('it counts from 01 to 06, padded, and never changes its denominator', (tester) async {
      await pumpFrame(tester);

      for (final expected in ['01 / 06', '02 / 06', '03 / 06', '04 / 06', '05 / 06', '06 / 06']) {
        expect(
          tester.widget<Text>(find.byKey(onboardingCounterKey)).data,
          expected,
          reason: 'the counter on the step that should read $expected',
        );
        if (expected != '06 / 06') await advance(tester);
      }
    });

    testWidgets('a screen reader hears the step in words, not the padded digits', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = await pumpFrame(tester);

      expect(find.bySemanticsLabel(l10n.ob_step_semantics(1, 6)), findsOneWidget);
      await advance(tester);
      expect(find.bySemanticsLabel(l10n.ob_step_semantics(2, 6)), findsOneWidget);
      handle.dispose();
    });
  });

  group('the progress rule', () {
    testWidgets('has six segments and never dots', (tester) async {
      await pumpFrame(tester);

      expect(segments(tester), hasLength(6));
    });

    testWidgets('fills one more segment on every step', (tester) async {
      await pumpFrame(tester);
      final accent = AppTheme.light().colorScheme.primary;

      for (var step = 0; step < 6; step++) {
        final filled = segments(tester).where((colour) => colour == accent).length;
        expect(filled, step + 1, reason: 'the rule on step ${step + 1} of 6');
        if (step < 5) await advance(tester);
      }
    });
  });

  group('the accented word', () {
    for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
      testWidgets('is the only part of the $language headline painted in the accent colour', (tester) async {
        final l10n = await pumpFrame(tester, locale: locale);
        final accent = AppTheme.light().colorScheme.primary;
        final accents = <String>[
          l10n.ob1_accent,
          l10n.ob2_accent,
          l10n.ob3_accent,
          l10n.ob4_accent,
          l10n.ob5_accent,
          l10n.ob6_accent,
        ];
        final titles = <String>[
          l10n.ob1_title,
          l10n.ob2_title,
          l10n.ob3_title,
          l10n.ob4_title,
          l10n.ob5_title,
          l10n.ob6_title,
        ];

        for (var step = 0; step < 6; step++) {
          final headline = tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text;
          expect(headline.toPlainText(), titles[step], reason: 'the whole headline of step ${step + 1}');

          final painted = <String, Color?>{};
          headline.visitChildren((span) {
            if (span is TextSpan && span.text != null) painted[span.text!] = span.style?.color;
            return true;
          });
          expect(
            painted[accents[step]],
            accent,
            reason: 'the accented word of step ${step + 1} in $language is "${accents[step]}"',
          );
          for (final MapEntry(key: run, value: colour) in painted.entries) {
            if (run == accents[step]) continue;
            expect(colour, isNot(accent), reason: '"$run" of step ${step + 1} is painted in the accent colour too');
          }
          if (step < 5) await advance(tester);
        }
      });
    }
  });

  /// What the fixed headline and body boxes are for.
  ///
  /// **The foot alone does not prove them.** The hero takes the slack above the words, so the progress rule and
  /// the controls sit at the bottom of the frame whatever the words do — a box sized to the *first* of the six
  /// strings instead of the tallest leaves that claim passing and still moves the screen. What moves is the words'
  /// own top edge: without the reserve, the headline of a two-line screen starts lower than the headline of a
  /// three-line one, and a reader's eye is dragged up and down the six screens. Both are measured, and the second
  /// is the one that bites.
  /// The air the approved prototype leaves under the headline.
  ///
  /// Its stylesheet sets `h2{min-height:98px}` at `font-size:30px;line-height:1.08` — three lines of its own type
  /// for titles that are authored as two, so the headline sits in a block with room under it rather than hugging
  /// its last line. The app's `displaySmall` is the same 30/1.08, so the same rule reads as three lines here.
  /// Measured on the emulator before this was added, the block was 64 — the two lines the titles use, 34 short.
  ///
  /// **Why the wide viewport.** `flutter test` does not load the product font; it draws in Ahem, whose every glyph
  /// is a full em square. At phone width that wraps a two-line Turkish title to four lines and the block comes to
  /// 192 on its own, so a floor of three lines changes nothing and the test cannot fail. Given room for each
  /// authored line to fit, the content is the two lines it is on a real phone and the floor is the only thing that
  /// can lift the block — which is the thing being tested.
  testWidgets('the headline block keeps the three lines of air the prototype leaves it', (tester) async {
    await pumpFrame(tester, viewport: const Size(1400, 844));

    final style = Theme.of(tester.element(find.byType(OnboardingPage))).textTheme.displaySmall!;
    final line = style.fontSize! * style.height!;
    final box = tester.getRect(find.byKey(onboardingHeadlineKey));

    expect(
      box.height,
      greaterThanOrEqualTo(line * 3 - 0.5),
      reason:
          'the headline block is ${box.height.toStringAsFixed(1)}, under the ${(line * 3).toStringAsFixed(1)} '
          'that three lines of its own type come to (the prototype reserves 98)',
    );
  });

  /// The same question for the body: `.body{min-height:62px}` is a floor, in the prototype's own pixels.
  ///
  /// It used to be three lines of `bodyMedium` and the tallest of the six bodies; the prototype's body is `13.5px/1.5`
  /// type and its box is 62 until a body needs more (English screen 5, which grows it). **Why the wide viewport** is
  /// the headline test's reason: `flutter test` draws in Ahem, whose every glyph is a full em square, so at phone
  /// width the bodies wrap to four to eight lines and clear any floor by themselves. Given room, the same six come to
  /// one or two Ahem lines, and the floor is the only thing that can lift the block.
  testWidgets('the body block keeps the 62 the prototype leaves it', (tester) async {
    await pumpFrame(tester, viewport: const Size(1400, 844));

    final box = tester.getRect(find.byKey(onboardingBodyKey));

    expect(box.height, closeTo(62, 0.5), reason: 'the body block is ${box.height.toStringAsFixed(1)}, not 62');
  });

  /// The measure the approved prototype gives the body, which is narrower than the one it gives the headline.
  ///
  /// `ob.html` caps exactly one of the two: `.body{margin-top:10px;font-size:13.5px;line-height:1.5;
  /// color:var(--quiet);max-width:302px;min-height:62px}`, against an `h2` that runs the whole 318 the content
  /// column of a 390 frame is wide. Measured on the emulator before this was added, the Flutter body ran the full
  /// column — 320.7 of it — so a line of body text was longer here than in the design and every line of all six
  /// screens broke in a different place.
  ///
  /// **How this avoids the font trap.** Nothing here is a text height. The column is read off the progress rule,
  /// whose segments are `Expanded` and so fill the content column whatever is written anywhere; the body's own box
  /// is given its width rather than taking it from its longest line. Ahem's square ems move neither, so the number
  /// this test reads on the machine is the number a phone draws.
  testWidgets('the body is capped a spacing step short of the column, the way the prototype caps it', (tester) async {
    await pumpFrame(tester);

    final column = tester.getRect(find.byKey(onboardingProgressKey)).width;
    final measure = tester.getRect(find.byKey(onboardingBodyKey)).width;

    expect(column, closeTo(318, 0.5), reason: 'the content column of a 390 frame, which the prototype runs h2 across');
    expect(
      measure,
      closeTo(column - AppSpacing.lg, 0.5),
      reason:
          'the body is ${measure.toStringAsFixed(1)} wide of the ${column.toStringAsFixed(1)} the column has; the '
          'prototype caps it at 302, which is this column less one spacing step',
    );
  });

  /// The prototype stacks the counter above the caption instead of setting them on one row: `.counter{position:
  /// absolute;right:24px;top:40px}` against a caption in the flow at `padding-top:38px` + `#cap{margin-top:14px}` = 52.
  /// Measured in headless Chrome, 390x844, both languages and both themes: counter box 40..54, caption box 52..66.
  ///
  /// **Top-anchored, and why.** Both live in the header, which the device's own top inset decides, not in the foot
  /// the 94 dp of a shorter phone is taken out of. The 40 is therefore measured from the top of the page the app is
  /// given (below the status bar), and the 12 between the two is a difference, which no glyph size touches.
  group('the counter is stacked above the caption', () {
    testWidgets('the caption sits 12 below the counter and the counter is on the right', (tester) async {
      await pumpFrame(tester);

      final counter = tester.getRect(find.byKey(onboardingCounterKey));
      final caption = tester.getRect(find.byKey(onboardingCaptionKey));
      final column = tester.getRect(find.byKey(onboardingProgressKey));

      expect(caption.top - counter.top, closeTo(12, 0.5), reason: 'the prototype: counter 40, caption 52');
      expect(counter.right, closeTo(column.right, 0.5), reason: 'the counter ends at the column\'s right edge');
      expect(caption.left, closeTo(column.left, 0.5), reason: 'the caption starts at the left edge of the column');
    });

    /// `.counter{letter-spacing:.16em}` and `.cap{letter-spacing:.14em}`, over 11px: 1.76 and 1.54. The app tracked
    /// both at 0.1em, which drew `01 / 06` 53.9 wide where the prototype's is 58.5.
    testWidgets('the counter is tracked .16em and the caption .14em, as the prototype sets them', (tester) async {
      await pumpFrame(tester);

      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).style!.letterSpacing, closeTo(1.76, 0.001));
      expect(tester.widget<Text>(find.byKey(onboardingCaptionKey)).style!.letterSpacing, closeTo(1.54, 0.001));
    });

    /// The owner's decision, which overrides the prototype: the prototype is asymmetric (48 on the left, 24 on the
    /// right of a 390 frame, a 318 column), and he wants the content centred. The column keeps its 318 and the 72 that
    /// is left is split evenly: 36 a side. Everything the column governs moves with it — the caption and counter, the
    /// hero, the headline, the body, the rule and the controls — so each is checked against the same two edges.
    testWidgets('the margins are equal: 36 a side, and every part of the page is on the same two edges', (
      tester,
    ) async {
      await pumpFrame(tester);

      final rule = tester.getRect(find.byKey(onboardingProgressKey));
      expect(rule.left, closeTo(36, 0.5));
      expect(390 - rule.right, closeTo(36, 0.5));
      expect(rule.width, closeTo(318, 0.5), reason: 'the column keeps its width');
      for (final key in [onboardingCaptionKey, onboardingHeadlineKey, onboardingBodyKey]) {
        expect(tester.getRect(find.byKey(key)).left, closeTo(36, 0.5), reason: '$key');
      }
      expect(tester.getRect(find.byKey(onboardingCounterKey)).right, closeTo(390 - 36, 0.5));
      expect(tester.getRect(find.byKey(onboardingSkipKey)).left, closeTo(36, 0.5));
    });

    testWidgets('the counter is 40 from the top of the page', (tester) async {
      await pumpFrame(tester);

      expect(tester.getRect(find.byKey(onboardingCounterKey)).top, closeTo(40, 0.5));
    });
  });

  /// `.body{font-size:13.5px;line-height:1.5;max-width:302px;min-height:62px}`, `h2{min-height:98px}` and the 10
  /// between
  /// them, then `.foot{margin-top:16px}` to the rule: the headline's top is 98 + 10 + 62 + 16 = 186 above the rule's.
  ///
  /// **Bottom-anchored, and why.** The prototype's frame is 844 tall and this phone's page is 94 shorter; the headline
  /// is a block of the foot, held up from the rule by its own box, so what is preserved is the distance from the
  /// foot. Everything above it — the hero — is what yields.
  ///
  /// **The wide viewport** is the font trap's: in Ahem the bodies wrap to four to eight lines at phone width and
  /// outgrow any floor, so the floor could not be seen. At 1400 each one is a line or two.
  group('the words sit where the prototype puts them from the foot', () {
    testWidgets('the headline top is 186 above the progress rule, the body 78', (tester) async {
      await pumpFrame(tester, viewport: const Size(1400, 844));

      final rule = tester.getRect(find.byKey(onboardingProgressKey)).top;
      expect(rule - tester.getRect(find.byKey(onboardingHeadlineKey)).top, closeTo(186, 0.5));
      expect(rule - tester.getRect(find.byKey(onboardingBodyKey)).top, closeTo(78, 0.5));
    });

    /// `h2{font-size:30px;line-height:1.08;letter-spacing:-.028em}` measured -0.84px in Chrome. The design system's
    /// display-m is -0.024em (-0.72), 1.7 wider over `veritabanları.`; the introduction follows the prototype.
    testWidgets('the headline is tracked -.028em, as the prototype sets it', (tester) async {
      await pumpFrame(tester);

      final style = tester.widget<Text>(find.byKey(onboardingHeadlineKey)).style!;
      expect(style.fontSize, 30);
      expect(style.letterSpacing, closeTo(-0.84, 0.001));
    });

    testWidgets('the body is drawn at 13.5 over a line of 1.5, which is what keeps it on two lines', (tester) async {
      await pumpFrame(tester);

      final style = tester.widget<Text>(find.byKey(onboardingBodyKey)).style!;
      expect(style.fontSize, 13.5);
      expect(style.height, 1.5);
      // Material's `bodyMedium` carries 0.25 of tracking and the design system's `_level` keeps it when it is given
      // none. The prototype's `.body` has none, and 0.25 over a 44-character line is 11 px, which wrapped the first
      // screen's Turkish body to three lines at 13.5 as well.
      expect(style.letterSpacing, 0);
    });
  });

  group('the words and the controls do not move between screens', () {
    for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
      // At phone width a body that needs a fourth line grows its block, as the prototype's does on English screen 5;
      // given room, none does, and the words land where the floor puts them on every screen.
      testWidgets('the words and the foot land at the same y on all six $language screens', (tester) async {
        await pumpFrame(tester, locale: locale, viewport: const Size(1400, 844));
        final anchors = <Key, double>{
          for (final key in [onboardingHeadlineKey, onboardingBodyKey, onboardingProgressKey])
            key: tester.getTopLeft(find.byKey(key)).dy,
        };

        for (var step = 1; step < 6; step++) {
          await advance(tester);
          for (final MapEntry(key: key, value: anchor) in anchors.entries) {
            expect(
              tester.getTopLeft(find.byKey(key)).dy,
              closeTo(anchor, 0.5),
              reason: '$key on step ${step + 1} of 6 in $language starts elsewhere than it does on step 1',
            );
          }
        }
      });
    }
  });

  group('the control that leaves', () {
    testWidgets('says Next until the last screen, where it says the word that signs in', (tester) async {
      final l10n = await pumpFrame(tester);

      for (var step = 0; step < 5; step++) {
        expect(find.text(l10n.ob_next), findsNothing, reason: 'step ${step + 1} of 6 still carries a Next');
        expect(find.text(l10n.ob_done), findsNothing, reason: 'step ${step + 1} of 6 does not leave yet');
        await advance(tester);
      }

      expect(find.text(l10n.ob_done), findsOneWidget);
      expect(find.text(l10n.ob_next), findsNothing);
    });

    testWidgets('Skip holds the leading gutter, and the control that signs in the trailing one', (tester) async {
      await pumpFrame(tester);

      expect(
        tester.getTopLeft(find.byKey(onboardingSkipKey)).dx,
        closeTo(36, 1.0),
        reason: 'Skip sits on the frame\'s own indent, at the leading edge of the words above it',
      );
      expect(
        find.byKey(onboardingDoneKey),
        findsNothing,
        reason: 'the deck is turned by dragging it, so nothing holds the trailing end before the last screen',
      );

      // The control that signs in appears on the sixth, and it is the one that takes the trailing gutter.
      for (var step = 0; step < onboardingStepCount - 1; step++) {
        await advance(tester);
      }
      expect(
        tester.getTopRight(find.byKey(onboardingDoneKey)).dx,
        closeTo(390 - 36, 1.0),
        reason: 'the control that signs in sits at the opposite end, under the counter',
      );
    });

    /// `.skip{font-size:14px;font-weight:600;color:var(--quiet);background:none;border:0}` — a bare word, 26.5 wide in
    /// Turkish, whose left edge is the content column's 48. The app's `TextButton` carried the theme's 16 of padding
    /// (the word at 64) and the brand colour. The 48 high hit area stays.
    /// `.next{font-size:15px;font-weight:600;border-radius:999px;padding:13px 26px}` over `min-height:48px`: measured
    /// in
    /// headless Chrome the pill is 114 wide around Turkish "Giriş yap" (a 62 word and 26 either side) and 48 high.
    /// The app's button took the theme's smaller padding and size, which drew it 88 wide in a lighter weight.
    testWidgets('the sign-in control is a 48 high pill, a 15 semibold word with 26 either side', (tester) async {
      await pumpFrame(tester);
      for (var step = 0; step < onboardingStepCount - 1; step++) {
        await advance(tester);
      }

      final button = find.byKey(onboardingDoneKey);
      final word = find.descendant(of: button, matching: find.byType(Text));
      expect(tester.getSize(button).height, 48);
      expect(tester.getSize(button).width - tester.getSize(word).width, closeTo(52, 0.5));
      final style = tester.widget<FilledButton>(button).style!.textStyle!.resolve({})!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('Skip is a quiet 14 semibold word on the content edge, in a 48 high target', (tester) async {
      await pumpFrame(tester);

      final word = find.descendant(of: find.byKey(onboardingSkipKey), matching: find.byType(Text));
      final style = tester.widget<Text>(word).style ?? DefaultTextStyle.of(tester.element(word)).style;
      final colors = Theme.of(tester.element(find.byType(OnboardingPage))).colorScheme;

      expect(tester.getTopLeft(word).dx, closeTo(36, 0.5), reason: 'the word, not the button, is on the edge');
      expect(tester.getSize(find.byKey(onboardingSkipKey)).height, 48);
      final resolved = tester.widget<TextButton>(find.byKey(onboardingSkipKey)).style!.textStyle!.resolve({});
      expect(resolved!.fontSize, 14);
      expect(resolved.fontWeight, FontWeight.w600);
      expect(
        tester.widget<TextButton>(find.byKey(onboardingSkipKey)).style!.foregroundColor!.resolve({}),
        colors.onSurfaceVariant,
      );
      expect(style, isNotNull);
      // `padded` is Material's default and makes the target 48 wide whatever the word, which centres a 26.5 word in it
      // 11 in from the edge: on a phone the word started at 58.8, not 48. The 48 high comes from the row's constraint.
      expect(
        tester.widget<TextButton>(find.byKey(onboardingSkipKey)).style!.tapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
    });

    testWidgets('Skip is on every screen', (tester) async {
      final l10n = await pumpFrame(tester);

      for (var step = 0; step < 6; step++) {
        expect(find.text(l10n.ob_skip), findsOneWidget, reason: 'Skip on step ${step + 1} of 6');
        if (step < 5) await advance(tester);
      }
    });
  });

  group('the step change is animated', () {
    // The entrance travelled upward until the owner replaced the primary control with the gesture on 2026-10-29;
    // the deck is turned sideways, so the screen arrives sideways. The axis is what changed, not the timing.
    testWidgets('the words travel in sideways over the slow duration rather than appearing', (tester) async {
      await pumpFrame(tester);
      final resting = tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dx;

      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pump();

      expect(entrance(tester).opacity.value, lessThan(0.1), reason: 'the words of the new step start invisible');
      expect(
        tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dx,
        greaterThan(resting),
        reason: 'dragged to the left, the words of the new step start to the right of where they come to rest',
      );

      await tester.pump(AppDurations.slow ~/ 2);
      expect(entrance(tester).opacity.value, greaterThan(0.1), reason: 'half way through, the words are on their way');
      expect(entrance(tester).opacity.value, lessThan(1.0), reason: 'half way through, the words have not arrived');

      await tester.pump(AppDurations.slow);
      expect(entrance(tester).opacity.value, 1.0);
      expect(tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dx, resting);
    });

    testWidgets('with animations off every screen settles immediately into its finished state', (tester) async {
      await pumpFrame(tester, disableAnimations: true);
      final resting = tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dx;
      final accent = AppTheme.light().colorScheme.primary;

      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pump();

      expect(entrance(tester).opacity.value, 1.0, reason: 'the words are fully there on the first frame');
      expect(tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dx, resting, reason: 'and already at rest');
      expect(segments(tester).where((colour) => colour == accent).length, 2, reason: 'and the rule is already filled');
      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).data, '02 / 06');
    });
  });

  /// The counter as the chassis writes it: the digits are padded, the separator is the ARB's.
  String padded(S l10n, int step) =>
      l10n.ob_step(step, onboardingStepCount).replaceAllMapped(RegExp(r'\d+'), (m) => m[0]!.padLeft(2, '0'));

  /// The deck is turned by hand.
  ///
  /// The owner replaced the primary control with the gesture: a drag to the left is the next screen, a drag to the
  /// right is the one before, Skip still leaves from anywhere, and the control that signs in stays on the last
  /// screen because without it there is no way out of the deck.
  group('the deck is turned by dragging it', () {
    testWidgets('a drag to the left is the next screen and a drag to the right is the one before', (tester) async {
      final l10n = await pumpFrame(tester);

      expect(find.byKey(onboardingCounterKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).data, padded(l10n, 1));

      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).data, padded(l10n, 2));

      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).data, padded(l10n, 1));
    });

    testWidgets('there is no Next control before the last screen, and the last one still signs in', (tester) async {
      final l10n = await pumpFrame(tester);

      for (var step = 1; step < onboardingStepCount; step++) {
        expect(
          find.text(l10n.ob_next),
          findsNothing,
          reason: 'screen $step of $onboardingStepCount still carries a Next control',
        );
        await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
        await tester.pump();
        await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
        await tester.pumpAndSettle();
      }
      expect(find.text(l10n.ob_done), findsOneWidget);
    });

    testWidgets('the first screen does not go back past itself', (tester) async {
      final l10n = await pumpFrame(tester);

      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(300, 0), 800);
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).data, padded(l10n, 1));
    });
  });
}
