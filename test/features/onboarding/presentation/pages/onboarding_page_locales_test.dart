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
import 'package:libredb_mobile/features/onboarding/domain/repositories/adoption_figures_source.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/onboarding_panel.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';

import '../../../../support/test_env.dart';

/// The four renderings the first run can have: {light, dark} × {English, Turkish}.
///
/// The brightness comes from the device when nothing has been chosen and the language from the phone's own setting,
/// so a user who has never opened the app before meets one of these four without choosing anything. No golden is
/// added for them: this machine draws goldens differently from CI, and what matters here is not the picture but
/// that each panel's own heading and paragraph are **on screen** in the language under test and that none of it is
/// cut off.
///
/// **On screen, not in the tree.** `find.text` is satisfied by a word laid out a thousand points below the fold,
/// and every panel is a `SingleChildScrollView`, so the finder alone would pass a page that shows four blank
/// panels. The claim is measured against the box that paints the panel instead, and it is two claims rather than
/// one, because the panel scrolls on purpose:
///
/// * **At the ordinary text size nothing needs scrolling.** The whole of the heading, the paragraph and the figures
///   line is inside the window. On a 390×844 phone the tallest of them, the second panel's paragraph, ends 134 pt
///   above the fold.
/// * **At an accessibility text size the content is reachable, and visible once reached.** It legitimately outgrows
///   one screen there — in Turkish at a scale of 3.0 the first paragraph lays out 1105 pt tall in a 646 pt window —
///   and asking for containment would fail correct behaviour. What is asked instead is that scrolling brings it
///   into the window, and that the panel does not *open* blank: its heading is on screen before anything is
///   scrolled, at every size.
///
/// **Turkish is the longer language**, and the introduction holds the longest text the app shows before sign-in. It
/// has overflowed once already (#365), so every rendering is held at the ordinary text size and at an accessibility
/// size a real Android setting reaches, on all four panels rather than only the one the page opens on.
///
/// **The brightness axis earns its place by measuring colour**, which is the only thing `AppTheme.light()` and
/// `AppTheme.dark()` differ in: each panel's three texts are measured against the page they are painted on. One of
/// those pairs is guarded nowhere else — the figures line is painted with `onPrimaryContainer` *on the page* rather
/// than on a container, and both `palette_contrast_test.dart` and `container_contrast_test.dart` measure that role
/// only against `primaryContainer` and the surface containers.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  /// The figures are fixed, so what the panels say does not move when `assets/adoption.json` is refreshed.
  const figures = AdoptionFigures(engines: 42, channels: 48, listings: 31);

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
      RepositoryProvider<IAdoptionFiguresSource>(
        create: (_) => const _FixedFigures(figures),
        child: BlocProvider<OnboardingCubit>.value(
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
      ),
    );
    await tester.pumpAndSettle();
    // Read the strings out of the tree rather than loading them again, so the test asserts the very text the page
    // was given for this locale.
    return S.of(tester.element(find.byType(OnboardingPage)));
  }

  /// The window the user sees of the panel this widget belongs to. The panel scrolls inside it and nothing outside
  /// it is drawn, so it — not the screen — is what "on screen" means for a panel's own text.
  Rect panelWindow(WidgetTester tester, Finder finder) =>
      tester.getRect(find.ancestor(of: finder, matching: find.byType(OnboardingPanel)));

  /// Fails when a widget has no pixel inside the window that paints it, which is what a user means by "it is not
  /// there". This is the claim `find.text` cannot make: a word below the fold satisfies the finder and shows
  /// nothing.
  void expectOnScreen(WidgetTester tester, Finder finder, {required String what}) {
    final window = panelWindow(tester, finder);
    final rect = tester.getRect(finder);
    final shown = rect.intersect(window);
    expect(
      shown.width > 0 && shown.height > 0,
      isTrue,
      reason:
          '$what is in the tree but nothing of it is on screen: it is laid out at $rect and the panel shows '
          '$window',
    );
  }

  /// Fails when any part of a widget is outside the window that paints it — the claim that holds at the ordinary
  /// text size, where the panel has room to spare and a user should not have to scroll for a word.
  void expectWhollyOnScreen(WidgetTester tester, Finder finder, {required String what}) {
    final window = panelWindow(tester, finder);
    final rect = tester.getRect(finder);
    expect(
      rect.top >= window.top - 0.5 &&
          rect.bottom <= window.bottom + 0.5 &&
          rect.left >= window.left - 0.5 &&
          rect.right <= window.right + 0.5,
      isTrue,
      reason: '$what needs scrolling at the ordinary text size: it is laid out at $rect and the panel shows $window',
    );
  }

  /// Scrolls a widget into the window and then measures that it really arrived — the honest form of the claim at a
  /// text size where the panel's content outgrows one screen by design.
  Future<void> expectReachable(WidgetTester tester, Finder finder, {required String what}) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expectOnScreen(tester, finder, what: '$what, after scrolling to it,');
  }

  /// Fails when text this screen paints does not read on the page it is painted on, at WCAG 2.1 AA's 1.4.3 floor.
  ///
  /// The colour is read off the laid-out paragraph rather than off the `ColorScheme`, so what is measured is this
  /// call site's rendering: a role that reads on the page in general and a style that resolves to something else
  /// here are different claims, and only the second one is this screen's.
  void expectReads(WidgetTester tester, Finder finder, {required Color page, required String what}) {
    final colour = tester.renderObject<RenderParagraph>(finder).text.style?.color;
    expect(colour, isNotNull, reason: '$what resolved to no colour at all');
    final ratio = contrastRatio(colour!, page);
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$what reads at ${ratio.toStringAsFixed(2)}:1 against the page, and the floor for text is 4.5:1',
    );
  }

  /// Fails when a finder's widget is drawn outside the screen sideways, which is the shape clipped text takes: the
  /// panels scroll vertically on purpose, so only the horizontal fit is a defect.
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
  /// This is the shape the defect takes here and the reason an exception is not enough: text that does not fit a box
  /// with a fixed height is simply cut off, silently, with no overflow stripe and nothing for `takeException` to
  /// hand back. What a user sees is the top half of a word.
  void expectNothingCutOff(WidgetTester tester, {required String where}) {
    for (final element in find.byType(Text).evaluate()) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byElementPredicate((candidate) => candidate == element),
      );
      final word = (element.widget as Text).data ?? '';
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

  for (final (brightness, dark) in [('light', false), ('dark', true)]) {
    for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
      for (final (size, scale) in [('the ordinary text size', 1.0), ('a large text size', 2.0)]) {
        testWidgets('$brightness, in $language, shows every panel at $size', (tester) async {
          const width = 390.0;
          final l10n = await pumpIntroduction(tester, dark: dark, locale: locale, textScale: scale);
          final page = Theme.of(tester.element(find.byType(OnboardingPage))).colorScheme.surface;

          final panels = <(String, String, String?)>[
            (l10n.onboarding_platform_title, l10n.onboarding_platform_body, null),
            (
              l10n.onboarding_studio_title,
              l10n.onboarding_studio_body,
              l10n.onboarding_studio_figures(figures.engines, figures.channels),
            ),
            (l10n.onboarding_mobile_title, l10n.onboarding_mobile_body, null),
            (l10n.onboarding_listings_title, l10n.onboarding_listings_body(figures.listings), null),
          ];

          for (final (index, (title, body, adoption)) in panels.indexed) {
            final where = 'panel ${index + 1} of ${panels.length} in $language';
            expect(find.text(title), findsOneWidget, reason: 'the heading of $where');
            expect(find.text(body), findsOneWidget, reason: 'the paragraph of $where');
            if (adoption != null) expect(find.text(adoption), findsOneWidget, reason: 'the figures of $where');

            // The panel never opens blank, whatever the text size: its heading is on screen before anything has
            // been scrolled.
            expectOnScreen(tester, find.text(title), what: 'the heading of $where as the panel opens');

            expectReads(tester, find.text(title), page: page, what: 'the heading of $where in $brightness');
            expectReads(tester, find.text(body), page: page, what: 'the paragraph of $where in $brightness');
            if (adoption != null) {
              expectReads(tester, find.text(adoption), page: page, what: 'the figures of $where in $brightness');
            }

            expectFitsAcross(tester, find.text(title), width: width, what: 'the heading of $where');
            expectFitsAcross(tester, find.text(body), width: width, what: 'the paragraph of $where');
            if (adoption != null) {
              expectFitsAcross(tester, find.text(adoption), width: width, what: 'the figures of $where');
            }
            expectLabelFits(tester, onboardingDoneKey, width: width, what: 'the primary control on $where');
            expectLabelFits(tester, onboardingSkipKey, width: width, what: 'Skip on $where');
            expectNothingCutOff(tester, where: '$where at $size');

            if (scale == 1.0) {
              // Nothing to scroll for at the ordinary size: the panel has room to spare, so all of it is in view.
              expectWhollyOnScreen(tester, find.text(title), what: 'the heading of $where');
              expectWhollyOnScreen(tester, find.text(body), what: 'the paragraph of $where');
              if (adoption != null) {
                expectWhollyOnScreen(tester, find.text(adoption), what: 'the figures of $where');
              }
            } else {
              // At an accessibility size the paragraph outgrows the panel by design, so the claim is reachability:
              // a scroll brings it in, and it is really there once it has.
              await expectReachable(tester, find.text(body), what: 'the paragraph of $where');
              if (adoption != null) {
                await expectReachable(tester, find.text(adoption), what: 'the figures of $where');
              }
            }

            expect(tester.takeException(), isNull, reason: 'something overflowed on $where');

            // The last panel's primary control leaves the page, and there is no router here to leave to.
            if (index < panels.length - 1) {
              await tester.tap(find.byKey(onboardingDoneKey));
              await tester.pumpAndSettle();
            }
          }
        });
      }
    }
  }

  /// The word on the primary control changes only on the last panel, so it is the one label a test that stops early
  /// never sees — and in Turkish it is the longest of the three.
  for (final (language, locale) in [('English', Locale('en')), ('Turkish', Locale('tr'))]) {
    testWidgets('the control that leaves fits its $language word at the largest text size', (tester) async {
      const width = 390.0;
      final l10n = await pumpIntroduction(tester, dark: false, locale: locale, textScale: 3.0);

      for (var panel = 0; panel < 3; panel++) {
        expect(find.text(l10n.onboarding_next), findsOneWidget, reason: 'panel ${panel + 1} still advances');
        await tester.tap(find.byKey(onboardingDoneKey));
        await tester.pumpAndSettle();
      }

      expect(find.text(l10n.onboarding_done), findsOneWidget);
      expectLabelFits(tester, onboardingDoneKey, width: width, what: 'the word that leaves');
      expectLabelFits(tester, onboardingSkipKey, width: width, what: 'Skip on the last panel');
      expectNothingCutOff(tester, where: 'the last panel in $language at the largest accessibility text size');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the control that leaves centres its $language word once it wraps', (tester) async {
      final l10n = await pumpIntroduction(tester, dark: false, locale: locale, textScale: 3.0);

      for (var panel = 0; panel < 3; panel++) {
        await tester.tap(find.byKey(onboardingDoneKey));
        await tester.pumpAndSettle();
      }

      expect(find.text(l10n.onboarding_done), findsOneWidget);
      expectWrappedLabelCentred(tester, onboardingDoneKey, what: 'the $language word that leaves');
    });
  }
}

/// Hands back the figures the test fixed. A hand fake rather than a mock: the one method takes no arguments to
/// verify and the test cares about the value, not the call.
class _FixedFigures implements IAdoptionFiguresSource {
  const _FixedFigures(this.figures);

  final AdoptionFigures figures;

  @override
  Future<AdoptionFigures> read() async => figures;
}
