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
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/test_env.dart';

/// The four renderings the first run can have: {light, dark} × {English, Turkish}.
///
/// The brightness comes from the device when nothing has been chosen and the language from the phone's own setting,
/// so a user who has never opened the app before meets one of these four without choosing anything. No golden is
/// added for them: this machine draws goldens differently from CI, and what matters here is not the picture but that
/// each panel's own heading and paragraph are on screen in the language under test and that none of it is cut off.
///
/// **Turkish is the longer language**, and the introduction holds the longest text the app shows before sign-in. It
/// has overflowed once already (#365), so every rendering is held at the ordinary text size and at an accessibility
/// size a real Android setting reaches, on all four panels rather than only the one the page opens on.
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
        testWidgets('$brightness, in $language, says every panel at $size', (tester) async {
          const width = 390.0;
          final l10n = await pumpIntroduction(tester, dark: dark, locale: locale, textScale: scale);

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

            expectFitsAcross(tester, find.text(title), width: width, what: 'the heading of $where');
            expectFitsAcross(tester, find.text(body), width: width, what: 'the paragraph of $where');
            if (adoption != null) {
              expectFitsAcross(tester, find.text(adoption), width: width, what: 'the figures of $where');
            }
            expectLabelFits(tester, onboardingDoneKey, width: width, what: 'the primary control on $where');
            expectLabelFits(tester, onboardingSkipKey, width: width, what: 'Skip on $where');
            expectNothingCutOff(tester, where: '$where at $size');

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
