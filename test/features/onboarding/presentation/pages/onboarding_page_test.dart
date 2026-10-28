@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/onboarding_seen_preferences.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/adoption_figures_source.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_routes.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../../support/test_env.dart';

/// The page the introduction's route builds, away from the app's own router.
///
/// What is settled here is the way it leaves, because the router depends on it and the body does not: both controls
/// remember that the introduction has been shown, and both hand the pending location to the login page. The four
/// panels replace the body in the flow's own step and should not have to re-establish any of this.
/// Hands back whatever figures a test asks for. A hand fake rather than a mock: the one method has no arguments to
/// verify and the test cares about the value, not the call.
class _FixedFigures implements IAdoptionFiguresSource {
  const _FixedFigures(this.figures);

  final AdoptionFigures figures;

  @override
  Future<AdoptionFigures> read() async => figures;
}

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
    AdoptionFigures figures = const AdoptionFigures(engines: 42, channels: 48, listings: 31),
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
      RepositoryProvider<IAdoptionFiguresSource>(
        create: (_) => _FixedFigures(figures),
        child: BlocProvider<OnboardingCubit>.value(
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
      ),
    );
    await tester.pumpAndSettle();
    return router.state.uri.toString();
  }

  /// Swipes to the last panel, where the primary control is the one that leaves.
  Future<void> reachLastPanel(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(onboardingDoneKey));
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
      if (key == onboardingDoneKey) await reachLastPanel(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(cubit.state, const OnboardingSeen());
      expect(await isRemembered(), isTrue, reason: 'the next launch would show the introduction again');
    });

    testWidgets('$name opens the login page', (tester) async {
      await pumpWelcome(tester);
      if (key == onboardingDoneKey) await reachLastPanel(tester);

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(find.text('the login page'), findsOneWidget);
    });

    testWidgets('$name hands the pending location to the login page', (tester) async {
      await pumpWelcome(tester, returnUrl: ApplicationRoutesConstants.settings);
      if (key == onboardingDoneKey) await reachLastPanel(tester);

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
    await reachLastPanel(tester);

    await tester.tap(find.byKey(onboardingDoneKey));
    await tester.pumpAndSettle();

    expect(
      (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).state.uri.toString(),
      ApplicationRoutesConstants.login,
    );
  });

  group('the four panels', () {
    testWidgets('opens on Platform and reaches Studio, this app and the listings in order', (tester) async {
      await pumpWelcome(tester);

      const titles = [
        'LibreDB Platform governs',
        'LibreDB Studio runs them',
        'This app is the window',
        'Where you already look',
      ];
      for (final (index, title) in titles.indexed) {
        expect(find.text(title), findsOneWidget, reason: 'panel ${index + 1}');
        for (final other in titles.where((candidate) => candidate != title)) {
          expect(find.text(other), findsNothing, reason: 'one panel at a time; $other was on screen with $title');
        }
        if (index < titles.length - 1) {
          await tester.tap(find.byKey(onboardingDoneKey));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('the Studio panel carries the figures its source gives it', (tester) async {
      await pumpWelcome(tester, figures: const AdoptionFigures(engines: 7, channels: 9, listings: 3));

      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('7'), findsWidgets, reason: 'the engines it was given');
      expect(find.textContaining('9'), findsWidgets, reason: 'the channels it was given');
    });

    testWidgets('the listings panel carries the figure its source gives it', (tester) async {
      await pumpWelcome(tester, figures: const AdoptionFigures(engines: 7, channels: 9, listings: 3));
      await reachLastPanel(tester);

      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('a source that can only fall back still shows numbers, never a zero', (tester) async {
      // `AdoptionFigures.fallback` is what every failure collapses into, so this is the worst case the page meets.
      await pumpWelcome(tester, figures: AdoptionFigures.fallback);

      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('42'), findsWidgets);
      expect(find.textContaining('48'), findsWidgets);
      expect(find.textContaining('0 '), findsNothing, reason: 'a zero reads as a claim about the product');
    });

    testWidgets('the primary control advances while there is a panel left, and leaves on the last', (tester) async {
      await pumpWelcome(tester);

      expect(find.text('Next'), findsOneWidget);
      await reachLastPanel(tester);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Get started'), findsOneWidget);

      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pumpAndSettle();
      expect(find.text('the login page'), findsOneWidget);
    });

    testWidgets('a swipe moves between panels as well as the control', (tester) async {
      await pumpWelcome(tester);

      await tester.drag(find.text('LibreDB Platform governs'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('LibreDB Studio runs them'), findsOneWidget);
    });

    testWidgets('Skip leaves from any panel, not only the first', (tester) async {
      await pumpWelcome(tester);
      await tester.tap(find.byKey(onboardingDoneKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(onboardingSkipKey));
      await tester.pumpAndSettle();

      expect(find.text('the login page'), findsOneWidget);
      expect(cubit.state, const OnboardingSeen());
    });
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

      testWidgets('keeps both controls reachable on $name', (tester) async {
        await pumpWelcome(tester, viewport: viewport, textScale: scale, locale: locale);

        for (final key in [onboardingDoneKey, onboardingSkipKey]) {
          await tester.ensureVisible(find.byKey(key));
          await tester.pumpAndSettle();
          expect(find.byKey(key), findsOneWidget, reason: '$key on $name');
        }
      });
    }

    // The layout is made to survive, not redesigned: on the surface the app is built for it the panel still fills
    // the screen rather than sitting in a scrolled strip at the top. It used to be the welcome title that was
    // measured here; the welcome is gone and the panel that replaced it is what has to hold the middle.
    testWidgets('still centres the panel on a phone at the ordinary text size', (tester) async {
      await pumpWelcome(tester);

      final title = tester.getCenter(find.text('LibreDB Platform governs'));
      expect(title.dy, greaterThan(844 * 0.2));
      expect(title.dy, lessThan(844 * 0.6));
    });
  });
}
