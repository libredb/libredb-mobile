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

  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.byKey(onboardingDoneKey));
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
      reason: 'the headline block is ${box.height.toStringAsFixed(1)}, under the ${(line * 3).toStringAsFixed(1)} '
          'that three lines of its own type come to (the prototype reserves 98)',
    );
  });

  group('the words and the controls do not move between screens', () {
    for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
      testWidgets('the words and the foot land at the same y on all six $language screens', (tester) async {
        await pumpFrame(tester, locale: locale);
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
        expect(find.text(l10n.ob_next), findsOneWidget, reason: 'step ${step + 1} of 6 still advances');
        expect(find.text(l10n.ob_done), findsNothing, reason: 'step ${step + 1} of 6 does not leave yet');
        await advance(tester);
      }

      expect(find.text(l10n.ob_done), findsOneWidget);
      expect(find.text(l10n.ob_next), findsNothing);
    });

    testWidgets('Skip holds the leading gutter and the primary control the trailing one', (tester) async {
      await pumpFrame(tester);

      expect(
        tester.getTopLeft(find.byKey(onboardingSkipKey)).dx,
        closeTo(AppSpacing.xxxxl, 1.0),
        reason: 'Skip sits on the frame\'s own indent, at the leading edge of the words above it',
      );
      expect(
        tester.getTopRight(find.byKey(onboardingDoneKey)).dx,
        closeTo(390 - AppSpacing.xl, 1.0),
        reason: 'the primary control sits at the opposite end, under the counter',
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
    testWidgets('the words rise into place over the slow duration rather than appearing', (tester) async {
      await pumpFrame(tester);
      final resting = tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dy;

      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pump();

      expect(entrance(tester).opacity.value, lessThan(0.1), reason: 'the words of the new step start invisible');
      expect(
        tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dy,
        greaterThan(resting),
        reason: 'the words of the new step start below where they come to rest',
      );

      await tester.pump(AppDurations.slow ~/ 2);
      expect(entrance(tester).opacity.value, greaterThan(0.1), reason: 'half way through, the words are on their way');
      expect(entrance(tester).opacity.value, lessThan(1.0), reason: 'half way through, the words have not arrived');

      await tester.pump(AppDurations.slow);
      expect(entrance(tester).opacity.value, 1.0);
      expect(tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dy, resting);
    });

    testWidgets('with animations off every screen settles immediately into its finished state', (tester) async {
      await pumpFrame(tester, disableAnimations: true);
      final resting = tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dy;
      final accent = AppTheme.light().colorScheme.primary;

      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pump();

      expect(entrance(tester).opacity.value, 1.0, reason: 'the words are fully there on the first frame');
      expect(tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dy, resting, reason: 'and already at rest');
      expect(segments(tester).where((colour) => colour == accent).length, 2, reason: 'and the rule is already filled');
      expect(tester.widget<Text>(find.byKey(onboardingCounterKey)).data, '02 / 06');
    });
  });
}
