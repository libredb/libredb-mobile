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
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';

import '../../../../support/test_env.dart';

/// The four renderings the first run can have: {light, dark} × {English, Turkish}.
///
/// The brightness comes from the device when nothing has been chosen and the language from the phone's own setting,
/// so a user who has never opened the app before meets one of these four without choosing anything. No golden is
/// added for them: this machine draws goldens differently from CI, and what matters here is not the picture but
/// that each screen's own caption, headline and body are **on screen** in the language under test and that none of
/// it is cut off.
///
/// **On screen, not in the tree.** `find.text` is satisfied by a word laid out a thousand points below the fold,
/// and the frame scrolls when the words outgrow it, so the finder alone would pass a page that shows six blank
/// screens. The claim is measured against the window that paints the page instead, and it is two claims rather
/// than one, because the frame scrolls on purpose:
///
/// * **At the ordinary text size nothing needs scrolling.** The whole of the caption, the headline and the body is
///   inside the window, on every one of the six screens.
/// * **At an accessibility text size the content is reachable, and visible once reached.** It legitimately
///   outgrows one screen there — Turkish at a scale of 2.0 lays the fifth screen's body out taller than the
///   window — and asking for containment would fail correct behaviour. What is asked instead is that scrolling
///   brings it into the window, and that the frame does not *open* blank: its headline is on screen before
///   anything is scrolled, at every size.
///
/// **Turkish is the longer language**, and the introduction holds the longest text the app shows before sign-in. It
/// has overflowed once already (#365), so every rendering is held at the ordinary text size and at an
/// accessibility size a real Android setting reaches, on all six screens rather than only the one the page opens
/// on.
///
/// **The brightness axis earns its place by measuring colour**, which is the only thing `AppTheme.light()` and
/// `AppTheme.dark()` differ in: each screen's three texts are measured against the page they are painted on. One
/// of those pairs is guarded nowhere else — the accented run of the headline is painted with `primary` *on the
/// page* rather than on a container, and `palette_contrast_test.dart` measures that role only against
/// `onPrimary`.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<S> pumpIntroduction(
    WidgetTester tester, {
    required bool dark,
    required Locale locale,
    required double textScale,
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
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Read the strings out of the tree rather than loading them again, so the test asserts the very text the page
    // was given for this locale.
    return S.of(tester.element(find.byType(OnboardingPage)));
  }

  /// The window the user sees of the frame. The frame scrolls inside it and nothing outside it is drawn, so it —
  /// not the screen — is what "on screen" means.
  ///
  /// **There are two scroll views on this page, and only one of them is the frame.** The chassis gives each step's
  /// hero its own scrolling box (`_HeroExtent` over a `SingleChildScrollView`), so `find.byType(Scrollable)` is
  /// ambiguous and the measurement has to name which one it means. It is named by what it holds: the words live in
  /// the frame and never in the hero's box, so the frame is the headline's scrolling ancestor. Asking for the
  /// *first* Scrollable would pick the same one today and quietly pick the wrong one the day the tree is reordered.
  Rect frameWindow(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.byKey(onboardingHeadlineKey), matching: find.byType(Scrollable)));

  /// Fails when a widget has no pixel inside the window that paints it, which is what a user means by "it is not
  /// there". This is the claim `find.text` cannot make: a word below the fold satisfies the finder and shows
  /// nothing.
  void expectOnScreen(WidgetTester tester, Finder finder, {required String what}) {
    final window = frameWindow(tester);
    final rect = tester.getRect(finder);
    final shown = rect.intersect(window);
    expect(
      shown.width > 0 && shown.height > 0,
      isTrue,
      reason:
          '$what is in the tree but nothing of it is on screen: it is laid out at $rect and the frame shows '
          '$window',
    );
  }

  /// Fails when any part of a widget is outside the window that paints it — the claim that holds at the ordinary
  /// text size, where the frame has room to spare and a user should not have to scroll for a word.
  void expectWhollyOnScreen(WidgetTester tester, Finder finder, {required String what}) {
    final window = frameWindow(tester);
    final rect = tester.getRect(finder);
    expect(
      rect.top >= window.top - 0.5 &&
          rect.bottom <= window.bottom + 0.5 &&
          rect.left >= window.left - 0.5 &&
          rect.right <= window.right + 0.5,
      isTrue,
      reason: '$what needs scrolling at the ordinary text size: it is laid out at $rect and the frame shows $window',
    );
  }

  /// Scrolls a widget into the window and then measures that it really arrived — the honest form of the claim at a
  /// text size where the frame's content outgrows one screen by design.
  Future<void> expectReachable(WidgetTester tester, Finder finder, {required String what}) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expectOnScreen(tester, finder, what: '$what, after scrolling to it,');
  }

  /// WCAG 2.1 AA 1.4.3's floor for ordinary text.
  const bodyFloor = 4.5;

  /// 1.4.3's floor for **large-scale** text, which it defines as 18 pt bold or 14 pt regular and up. The headline
  /// is the product's `display-m`: 30 px at `w700`, well past that, so this is its floor and not a relaxation of
  /// the other one. The accented run of the headline needs it: `primary` on `surface` reads at 3.08:1 in the dark
  /// palette, which clears the large-text floor and not the body one, and the palette is not this page's to
  /// change — `palette_contrast_test.dart` is where that value lives.
  const headlineFloor = 3.0;

  /// Fails when a colour this screen paints text in does not read on the page it is painted on, at WCAG 2.1 AA's
  /// 1.4.3 floor for text of that size.
  void expectColourReads(Color? colour, {required Color page, required String what, double floor = bodyFloor}) {
    expect(colour, isNotNull, reason: '$what resolved to no colour at all');
    final ratio = contrastRatio(colour!, page);
    expect(
      ratio,
      greaterThanOrEqualTo(floor),
      reason: '$what reads at ${ratio.toStringAsFixed(2)}:1 against the page, and its floor is $floor:1',
    );
  }

  /// Fails when text this screen paints does not read on the page it is painted on.
  ///
  /// The colour is read off the laid-out paragraph rather than off the `ColorScheme`, so what is measured is this
  /// call site's rendering: a role that reads on the page in general and a style that resolves to something else
  /// here are different claims, and only the second one is this screen's.
  void expectReads(WidgetTester tester, Finder finder, {required Color page, required String what}) {
    expectColourReads(tester.renderObject<RenderParagraph>(finder).text.style?.color, page: page, what: what);
  }

  /// The same claim for every run of the headline, including the one word painted in the accent colour.
  void expectHeadlineReads(WidgetTester tester, {required Color page, required String what}) {
    final headline = tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text;
    expectColourReads(headline.style?.color, page: page, what: what, floor: headlineFloor);
    headline.visitChildren((span) {
      final colour = span.style?.color;
      if (colour != null) {
        expectColourReads(colour, page: page, what: 'the accented run of $what', floor: headlineFloor);
      }
      return true;
    });
  }

  /// Moves to the next screen the way a user does: the deck is turned by dragging it, and the primary control is
  /// gone from every screen but the last.
  Future<void> advance(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
    await tester.pump();
    await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
  }

  /// Fails when a finder's widget is drawn outside the screen sideways, which is the shape clipped text takes: the
  /// frame scrolls vertically on purpose, so only the horizontal fit is a defect.
  void expectFitsAcross(WidgetTester tester, Finder finder, {required double width, required String what}) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((candidate) => candidate == element));
      expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$what is cut off on the left: $rect');
      expect(rect.right, lessThanOrEqualTo(width + 0.5), reason: '$what is cut off on the right: $rect');
    }
  }

  void expectLabelFits(WidgetTester tester, Key key, {required double width, required String what}) {
    expectFitsAcross(
      tester,
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      width: width,
      what: what,
    );
  }

  /// Fails when a button label that wrapped leaves its short line hanging on the leading edge.
  ///
  /// A button label is laid out in a box exactly as wide as its longest line, so alignment says nothing at all
  /// until the label wraps — and then it says everything, because the slack beside the short line is the whole
  /// difference between a centred label and a ragged one.
  void expectWrappedLabelCentred(WidgetTester tester, Key key, {required String what}) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    );
    final label = paragraph.text.toPlainText();
    final lines = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length));
    expect(lines.length, greaterThan(1), reason: '"$label" no longer wraps here, so this guard measures nothing');
    // The last line is the one to measure: it is the only one with no trailing space, and a wrapped line lays its
    // trailing space out past its own visible end. Centred, a line starts half the slack in; laid out from the
    // leading edge, it starts at zero.
    final last = lines.last;
    final slack = paragraph.size.width - (last.right - last.left);
    expect(
      last.left,
      closeTo(slack / 2, 1.0),
      reason:
          'the last line of "$label" starts ${last.left} pt into a box ${paragraph.size.width} pt wide, with '
          '$slack pt of slack beside it, so $what is ragged rather than centred under its first line',
    );
  }

  /// Fails when any word on screen is laid out larger than the box that paints it.
  ///
  /// This is the shape the defect takes here and the reason an exception is not enough: text that does not fit a
  /// box with a fixed height is simply cut off, silently, with no overflow stripe and nothing for `takeException`
  /// to hand back. What a user sees is the top half of a word.
  void expectNothingCutOff(WidgetTester tester, {required String where}) {
    for (final element in find.byType(Text).evaluate()) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byElementPredicate((candidate) => candidate == element),
      );
      final word = (element.widget as Text).data ?? paragraph.text.toPlainText();
      expect(
        paragraph.textSize.height,
        lessThanOrEqualTo(paragraph.size.height + 0.5),
        reason:
            '"$word" is cut off vertically on $where: it needs ${paragraph.textSize} and was given ${paragraph.size}',
      );
      expect(
        paragraph.textSize.width,
        lessThanOrEqualTo(paragraph.size.width + 0.5),
        reason: '"$word" is cut off sideways on $where: it needs ${paragraph.textSize} and was given ${paragraph.size}',
      );
    }
  }

  /// The caption, the headline and the body of each of the six screens, in the order the flow shows them.
  List<(String, String, String)> screens(S l10n, Locale locale) => [
    (onboardingCapitals(l10n.ob1_cap, locale), l10n.ob1_title, l10n.ob1_body),
    (onboardingCapitals(l10n.ob2_cap('orders-prod'), locale), l10n.ob2_title, l10n.ob2_body),
    (onboardingCapitals(l10n.ob3_cap('orders-prod'), locale), l10n.ob3_title, l10n.ob3_body),
    (onboardingCapitals(l10n.ob4_cap, locale), l10n.ob4_title, l10n.ob4_body),
    (onboardingCapitals(l10n.ob5_cap, locale), l10n.ob5_title, l10n.ob5_body),
    (onboardingCapitals(l10n.ob6_cap, locale), l10n.ob6_title, l10n.ob6_body),
  ];

  for (final (brightness, dark) in [('light', false), ('dark', true)]) {
    for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
      for (final (size, scale) in [('the ordinary text size', 1.0), ('a large text size', 2.0)]) {
        testWidgets('$brightness, in $language, shows every screen at $size', (tester) async {
          const width = 390.0;
          final l10n = await pumpIntroduction(tester, dark: dark, locale: locale, textScale: scale);
          final page = Theme.of(tester.element(find.byType(OnboardingPage))).colorScheme.surface;
          final flow = screens(l10n, locale);

          for (final (index, (caption, title, body)) in flow.indexed) {
            final where = 'screen ${index + 1} of ${flow.length} in $language';
            expect(
              tester.widget<Text>(find.byKey(onboardingCaptionKey)).data,
              caption,
              reason: 'the caption of $where',
            );
            expect(
              tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text.toPlainText(),
              title,
              reason: 'the headline of $where',
            );
            expect(tester.widget<Text>(find.byKey(onboardingBodyKey)).data, body, reason: 'the body of $where');

            // The frame never opens blank, whatever the text size: its headline is on screen before anything has
            // been scrolled.
            expectOnScreen(tester, find.byKey(onboardingHeadlineKey), what: 'the headline of $where as it opens');

            expectReads(tester, find.byKey(onboardingCaptionKey), page: page, what: 'the caption of $where');
            expectHeadlineReads(tester, page: page, what: 'the headline of $where in $brightness');
            expectReads(tester, find.byKey(onboardingBodyKey), page: page, what: 'the body of $where in $brightness');

            expectFitsAcross(tester, find.byKey(onboardingCaptionKey), width: width, what: 'the caption of $where');
            expectFitsAcross(tester, find.byKey(onboardingHeadlineKey), width: width, what: 'the headline of $where');
            expectFitsAcross(tester, find.byKey(onboardingBodyKey), width: width, what: 'the body of $where');
            expectFitsAcross(tester, find.byKey(onboardingCounterKey), width: width, what: 'the counter of $where');
            expectLabelFits(tester, onboardingDoneKey, width: width, what: 'the primary control on $where');
            expectLabelFits(tester, onboardingSkipKey, width: width, what: 'Skip on $where');
            expectNothingCutOff(tester, where: '$where at $size');

            if (scale == 1.0) {
              // Nothing to scroll for at the ordinary size: the frame has room to spare, so all of it is in view.
              expectWhollyOnScreen(tester, find.byKey(onboardingCaptionKey), what: 'the caption of $where');
              expectWhollyOnScreen(tester, find.byKey(onboardingHeadlineKey), what: 'the headline of $where');
              expectWhollyOnScreen(tester, find.byKey(onboardingBodyKey), what: 'the body of $where');
              expectWhollyOnScreen(tester, find.byKey(onboardingProgressKey), what: 'the progress rule of $where');
            } else {
              // At an accessibility size the body outgrows the frame by design, so the claim is reachability: a
              // scroll brings it in, and it is really there once it has.
              await expectReachable(tester, find.byKey(onboardingBodyKey), what: 'the body of $where');
              await expectReachable(tester, find.byKey(onboardingProgressKey), what: 'the progress rule of $where');
            }

            expect(tester.takeException(), isNull, reason: 'something overflowed on $where');

            if (index < flow.length - 1) await advance(tester);
          }
        });
      }
    }
  }

  /// The word on the primary control changes only on the last screen, so it is the one label a test that stops
  /// early never sees — and in Turkish it is the longest of the three.
  for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
    testWidgets('the control that leaves fits its $language word at the largest text size', (tester) async {
      const width = 390.0;
      final l10n = await pumpIntroduction(tester, dark: false, locale: locale, textScale: 3.0);

      for (var step = 0; step < onboardingStepCount - 1; step++) {
        expect(find.text(l10n.ob_next), findsNothing, reason: 'screen ${step + 1} still carries a Next');
        await advance(tester);
      }

      expect(find.text(l10n.ob_done), findsOneWidget);
      expectLabelFits(tester, onboardingDoneKey, width: width, what: 'the word that leaves');
      expectLabelFits(tester, onboardingSkipKey, width: width, what: 'Skip on the last screen');
      expectNothingCutOff(tester, where: 'the last screen in $language at the largest accessibility text size');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the control that leaves centres its $language word once it wraps', (tester) async {
      final l10n = await pumpIntroduction(tester, dark: false, locale: locale, textScale: 3.0);

      for (var step = 0; step < onboardingStepCount - 1; step++) {
        await advance(tester);
      }

      expect(find.text(l10n.ob_done), findsOneWidget);
      expectWrappedLabelCentred(tester, onboardingDoneKey, what: 'the $language word that leaves');
    });
  }
}
