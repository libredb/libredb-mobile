@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_routes.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/test_env.dart';

/// The page the introduction's route builds, away from the app's own router.
///
/// What is settled here is the way it leaves, because the router depends on it and the body does not: both controls
/// remember that the introduction has been shown, and both hand the pending location to the login page. The six
/// screens replace the body in the flow's own step and should not have to re-establish any of this.
///
/// **The adoption figures are gone**, not forgotten: the four panels that carried them are replaced by the six
/// screens the prototype agreed, and none of those six says a number about the product. The source that read them,
/// its asset and its generator are deleted, so there is nothing left for this page to be given.
void main() {
  late OnboardingCubit cubit;

  setUp(() async {
    await TestEnv.onboardingUnseen();
    cubit = OnboardingCubit(store: OnboardingSeenPreferences());
    addTearDown(cubit.close);
    await cubit.restore();
  });

  Future<bool> isRemembered() async => await AppLocalStorage().read(StorageKeys.onboardingSeen.key) != null;

  Future<String> pumpWelcome(
    WidgetTester tester, {
    String? returnUrl,
    Size viewport = const Size(390, 844),
    double textScale = 1.0,
    Locale locale = const Locale('en'),
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    final initial = returnUrl == null
        ? ApplicationRoutesConstants.welcome
        : '${ApplicationRoutesConstants.welcome}?returnUrl=${Uri.encodeQueryComponent(returnUrl)}';
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        ...OnboardingFeatureRoutes.routes,
        GoRoute(
          path: ApplicationRoutesConstants.login,
          builder: (context, state) => const Scaffold(body: Text('the login page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<OnboardingCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router.state.uri.toString();
  }

  /// Advances to the last screen, where the primary control is the one that leaves.
  Future<void> reachLastScreen(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
    }
  }

  test('the flag starts unset, so each test below meets a first run', () async {
    expect(await isRemembered(), isFalse);
    expect(cubit.state, const OnboardingRequired());
  });

  for (final (name, key) in <(String, Key)>[('the final control', onboardingDoneKey), ('Skip', onboardingSkipKey)]) {
    testWidgets('$name remembers that the introduction has been shown', (tester) async {
      await pumpWelcome(tester);
      if (key == onboardingDoneKey) await reachLastScreen(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(cubit.state, const OnboardingSeen());
      expect(await isRemembered(), isTrue, reason: 'the next launch would show the introduction again');
    });

    testWidgets('$name opens the login page', (tester) async {
      await pumpWelcome(tester);
      if (key == onboardingDoneKey) await reachLastScreen(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(find.text('the login page'), findsOneWidget);
    });

    testWidgets('$name hands the pending location to the login page', (tester) async {
      await pumpWelcome(tester, returnUrl: ApplicationRoutesConstants.settings);
      if (key == onboardingDoneKey) await reachLastScreen(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      final pending = Uri.encodeQueryComponent(ApplicationRoutesConstants.settings);
      expect(find.text('the login page'), findsOneWidget);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), isNotNull);
      expect(
        (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).state.uri.toString(),
        '${ApplicationRoutesConstants.login}?returnUrl=$pending',
      );
    });
  }

  testWidgets('without a pending location it opens the login page with nothing attached', (tester) async {
    await pumpWelcome(tester);
    await reachLastScreen(tester);

    await tester.ensureVisible(find.byKey(onboardingDoneKey));
    await tester.pump();
    await tester.tap(find.byKey(onboardingDoneKey));
    await tester.pumpAndSettle();

    expect(
      (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).state.uri.toString(),
      ApplicationRoutesConstants.login,
    );
  });

  /// The headline the flow is showing, as plain text. It is a `Text.rich` with one accented run, so its words are
  /// read off the paragraph rather than off a `Text` widget's `data`, which is null here.
  String headline(WidgetTester tester) =>
      tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text.toPlainText();

  group('the six screens', () {
    /// Every screen's caption and headline, in the order the flow shows them.
    List<(String, String)> screens(WidgetTester tester) {
      final element = tester.element(find.byKey(onboardingHeadlineKey));
      final l10n = S.of(element);
      final locale = Localizations.localeOf(element);
      return [
        (onboardingCapitals(l10n.ob1_cap, locale), l10n.ob1_title),
        (onboardingCapitals(l10n.ob2_cap('orders-prod'), locale), l10n.ob2_title),
        (onboardingCapitals(l10n.ob3_cap('orders-prod'), locale), l10n.ob3_title),
        (onboardingCapitals(l10n.ob4_cap, locale), l10n.ob4_title),
        (onboardingCapitals(l10n.ob5_cap, locale), l10n.ob5_title),
        (onboardingCapitals(l10n.ob6_cap, locale), l10n.ob6_title),
      ];
    }

    testWidgets('opens on the connection list and reaches all six in order, one at a time', (tester) async {
      await pumpWelcome(tester);
      final flow = screens(tester);

      for (final (index, (caption, title)) in flow.indexed) {
        expect(
          tester.widget<Text>(find.byKey(onboardingCaptionKey)).data,
          caption,
          reason: 'the caption of screen ${index + 1} of 6',
        );
        expect(
          tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text.toPlainText(),
          title,
          reason: 'the headline of screen ${index + 1} of 6',
        );
        for (final other in flow.where((candidate) => candidate.$2 != title)) {
          expect(
            find.text(other.$2),
            findsNothing,
            reason: 'one screen at a time; "${other.$2}" was on screen with "$title"',
          );
        }
        if (index < flow.length - 1) {
          await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
          await tester.pump();
          await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('the primary control advances while there is a screen left, and leaves on the last', (tester) async {
      await pumpWelcome(tester);
      final l10n = S.of(tester.element(find.byKey(onboardingHeadlineKey)));

      expect(find.text(l10n.ob_next), findsNothing, reason: 'Next is gone; the deck is turned by dragging it');
      await reachLastScreen(tester);
      expect(find.text(l10n.ob_next), findsNothing);
      expect(find.text(l10n.ob_done), findsOneWidget);

      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pumpAndSettle();
      expect(find.text('the login page'), findsOneWidget);
    });

    // The rule here was reversed by the owner on 2026-10-29: "ileri butonunu kaldır sağa sola kayrırabilmeli
    // ileride gidebilmeli geride gidebilmeli direk atlayadabilmeli". Until then the primary control was the only
    // way forward and a drag had to do nothing, which is what this test used to assert. Now the deck is turned by
    // dragging it, the control that signs in stays on the last screen because without it there is no way out, and
    // Skip still leaves from anywhere.
    testWidgets('a fling turns the deck forward and back, and the first screen does not go back past itself', (
      tester,
    ) async {
      await pumpWelcome(tester);
      final all = screens(tester).map((screen) => screen.$2).toList();

      String headline() => tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text.toPlainText();

      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(headline(), all.first, reason: 'the first screen went back past itself');

      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(headline(), all[1], reason: 'a fling to the left did not open the next screen');

      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(headline(), all.first, reason: 'a fling to the right did not open the screen before');
    });

    // The threshold is a velocity, not a distance: a reader repositioning a finger must not turn a page they did
    // not mean to turn.
    testWidgets('a slow drag does not turn the deck', (tester) async {
      await pumpWelcome(tester);
      final first = screens(tester).first.$2;

      await tester.drag(find.byKey(onboardingHeadlineKey), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(
        tester.renderObject<RenderParagraph>(find.byKey(onboardingHeadlineKey)).text.toPlainText(),
        first,
        reason: 'a slow drag turned the deck, and only a fling may',
      );
    });

    // The test above drags and lets go at rest: `tester.drag` dispatches no velocity, so a page that answered only
    // a *thrown* swipe — which is how Android's own pagers turn, and the gesture a reader of six screens actually
    // makes — would pass it and still move. Both directions are thrown, because a pager that refused the forward
    // fling would have taken the backward one. The throw starts from the second screen so that either direction
    // has a screen to land on, and a move in either would be visible.
    // This guard was written against the rule the owner reversed on 2026-10-29, and asserted that a fling moved
    // nothing. Reversed with the rule: a fling from the middle of the deck turns it both ways.
    testWidgets('a fling turns the deck from the middle of it, both ways', (tester) async {
      await pumpWelcome(tester);
      final flow = screens(tester);
      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(headline(tester), flow[1].$2, reason: 'the throw starts from the second of the six screens');

      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(headline(tester), flow[2].$2, reason: 'a fling to the left did not open the third screen');

      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(headline(tester), flow[1].$2, reason: 'a fling to the right did not go back');
    });

    testWidgets('Skip leaves from any screen, not only the first', (tester) async {
      await pumpWelcome(tester);
      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(onboardingSkipKey));
      await tester.pump();
      await tester.tap(find.byKey(onboardingSkipKey));
      await tester.pumpAndSettle();

      expect(find.text('the login page'), findsOneWidget);
      expect(cubit.state, const OnboardingSeen());
    });

    // That Skip is *drawn* on all six screens is measured in `onboarding_chassis_test.dart`; what is measured here
    // is that it still *leaves* from each of them. A Skip wired to nothing on the screens between the first and the
    // last passes both that test and the one above it, and still traps a reader in the middle of the deck — which
    // is the one place a reader who has seen enough actually presses it.
    for (var start = 0; start < onboardingStepCount; start++) {
      testWidgets('Skip leaves from screen ${start + 1} of $onboardingStepCount', (tester) async {
        await pumpWelcome(tester);
        final flow = screens(tester);
        for (var step = 0; step < start; step++) {
          await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
          await tester.pump();
          await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
          await tester.pumpAndSettle();
        }
        expect(headline(tester), flow[start].$2, reason: 'the walk did not reach screen ${start + 1}');

        await tester.ensureVisible(find.byKey(onboardingSkipKey));
        await tester.pump();
        await tester.tap(find.byKey(onboardingSkipKey));
        await tester.pumpAndSettle();

        expect(find.text('the login page'), findsOneWidget, reason: 'Skip did not leave from screen ${start + 1}');
        expect(cubit.state, const OnboardingSeen());
      });
    }
  });

  /// The first screen the app ever shows has to survive the device it is shown on.
  ///
  /// It was a plain Column with two Spacers and no scroll view: the Spacers absorb the slack until there is none,
  /// and then it overflows. Android's accessibility font size goes well past 1.3, so every row below is a setting a
  /// real user has — what they got was the overflow stripe across their first screen.
  group('the introduction survives the device it is shown on', () {
    const cases = <(String, Size, double, Locale)>[
      ('a phone', Size(390, 844), 1.0, Locale('en')),
      ('a phone at the largest ordinary text size', Size(390, 844), 1.3, Locale('tr')),
      ('a phone at an accessibility text size', Size(390, 844), 2.0, Locale('tr')),
      ('a phone at the largest accessibility text size', Size(390, 844), 3.0, Locale('tr')),
      ('a phone turned sideways', Size(844, 390), 1.3, Locale('tr')),
      ('sideways at an accessibility text size', Size(844, 390), 2.0, Locale('tr')),
      ('sideways at the largest accessibility text size', Size(844, 390), 3.0, Locale('tr')),
      ('a short viewport, as a keyboard leaves', Size(390, 380), 1.3, Locale('tr')),
      ('a small phone', Size(320, 568), 1.3, Locale('tr')),
    ];

    for (final (name, viewport, scale, locale) in cases) {
      testWidgets('shows no overflow on $name', (tester) async {
        await pumpWelcome(tester, viewport: viewport, textScale: scale, locale: locale);

        expect(tester.takeException(), isNull);
      });

      // Skip is the only control before the last screen: the deck is turned by dragging it, and the control that
      // signs in appears on the sixth. So this asks for Skip everywhere and for the other one only at the end.
      testWidgets('keeps the control that leaves reachable on $name', (tester) async {
        await pumpWelcome(tester, viewport: viewport, textScale: scale, locale: locale);

        await tester.ensureVisible(find.byKey(onboardingSkipKey));
        await tester.pumpAndSettle();
        expect(find.byKey(onboardingSkipKey), findsOneWidget, reason: 'Skip on $name');
        expect(find.byKey(onboardingDoneKey), findsNothing, reason: 'a Next control on the first screen of $name');

        await reachLastScreen(tester);
        await tester.ensureVisible(find.byKey(onboardingDoneKey));
        await tester.pumpAndSettle();
        expect(find.byKey(onboardingDoneKey), findsOneWidget, reason: 'the control that signs in on $name');
      });

      testWidgets('shows no overflow on the last screen of $name', (tester) async {
        await pumpWelcome(tester, viewport: viewport, textScale: scale, locale: locale);
        await reachLastScreen(tester);

        expect(tester.takeException(), isNull, reason: 'the word that leaves is the longest of the three');
      });
    }

    // A reader who scrolled down the fifth screen's body must not meet the sixth already scrolled past its own
    // headline: the frame gives the offset back on a step change.
    //
    // **How this avoids the Ahem trap.** `flutter test` draws in Ahem, whose square-em glyphs make every text-
    // dependent height about a third taller than on a phone — so no height is asked for here. The viewport is the
    // short one the case list above already exercises, which makes the frame scroll under any font, and the only
    // number asserted is zero, the offset after the step change, which no font metric can move. The
    // `greaterThan(0)` guards exist so that a frame which one day stops scrolling here fails loudly instead of
    // passing an assertion about an offset nobody ever moved.
    testWidgets('a step change gives back the offset the reader scrolled', (tester) async {
      await pumpWelcome(tester, viewport: const Size(390, 380), textScale: 1.3, locale: const Locale('tr'));
      // Two scroll views are on this page — the frame and the hero's own box — so the one meant is named by what
      // it holds rather than by its position in the tree: the words are in the frame and never in the hero's box.
      final frameScroll = find.ancestor(of: find.byKey(onboardingHeadlineKey), matching: find.byType(Scrollable));
      final frame = tester.widget<Scrollable>(frameScroll).controller!;
      expect(frame.position.maxScrollExtent, greaterThan(0), reason: 'the frame must scroll for this to mean a thing');

      frame.jumpTo(frame.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(frame.offset, greaterThan(0), reason: 'the reader scrolled down the screen they are on');

      await tester.ensureVisible(find.byKey(onboardingHeadlineKey));
      await tester.pump();
      await tester.fling(find.byKey(onboardingHeadlineKey), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();

      expect(frame.offset, 0, reason: 'the new screen opened already scrolled past its own headline');
    });

    // The layout is made to survive, not redesigned: on the surface the app is built for, the hero still holds the
    // top of the screen and the words and the controls sit under it, rather than everything collapsing into a
    // scrolled strip. It used to be the panel's heading that was measured here; the panel is gone and the frame
    // the six screens share is what has to hold the shape.
    testWidgets('gives the hero the top and the words the foot on a phone at the ordinary text size', (tester) async {
      await pumpWelcome(tester);

      expect(
        tester.getTopLeft(find.byKey(onboardingHeadlineKey)).dy,
        greaterThan(844 * 0.4),
        reason: 'the headline sits under the hero, not over it',
      );
      expect(
        tester.getBottomLeft(find.byKey(onboardingProgressKey)).dy,
        greaterThan(844 * 0.8),
        reason: 'the progress rule and the controls are at the foot of the screen',
      );
    });
  });
}
