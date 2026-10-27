@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app_status_gate.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/usecases/check_platform_liveness_usecase.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_unreachable_page.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mock_classes.dart';

class _MockSessionCubit extends MockCubit<SessionState> implements SessionCubit {}

class _MockOnboardingCubit extends MockCubit<OnboardingState> implements OnboardingCubit {}

const _offline = NetworkError('No Internet connection');

const _studioSession = SessionAuthenticated(target: SessionTarget.studio);
const _platformSession = SessionAuthenticated(target: SessionTarget.platform);

/// A Navigator with a text field, as the router is in the app, so a test sees whether open pages keep their state.
Widget _form() => Navigator(
  onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: TextField())),
);

void main() {
  late MockIStudioStatusRepository studio;
  late MockIPlatformStatusRepository platform;
  late StudioStatusBloc studioBloc;
  late PlatformStatusBloc platformBloc;
  late _MockSessionCubit session;
  late StreamController<SessionState> sessions;
  late _MockOnboardingCubit onboarding;
  late StreamController<OnboardingState> introductions;

  setUp(() {
    studio = MockIStudioStatusRepository();
    platform = MockIPlatformStatusRepository();
    when(() => studio.liveness()).thenAnswer((_) async => const Success(null));
    when(() => platform.liveness()).thenAnswer((_) async => const Success(null));
    session = _MockSessionCubit();
    sessions = StreamController<SessionState>.broadcast();
    addTearDown(sessions.close);
    onboarding = _MockOnboardingCubit();
    introductions = StreamController<OnboardingState>.broadcast();
    addTearDown(introductions.close);
  });

  // The blocs are created inside the test body, so their event streams run in the test's fake async zone, and the
  // providers close them when the test unmounts the tree.
  Future<void> pumpAppGate(
    WidgetTester tester, {
    required PlatformTargetConfig target,
    required SessionState initial,
    // Seen by default, so every test written before the introduction existed is about what it was about.
    OnboardingState introduction = const OnboardingSeen(),
    Widget child = const Scaffold(body: Text('app content')),
  }) async {
    whenListen(session, sessions.stream, initialState: initial);
    whenListen(onboarding, introductions.stream, initialState: introduction);
    studioBloc = StudioStatusBloc(
      checkLivenessUseCase: CheckStudioLivenessUseCase(studio),
      readReadinessUseCase: ReadStudioReadinessUseCase(studio),
    );
    platformBloc = PlatformStatusBloc(checkLivenessUseCase: CheckPlatformLivenessUseCase(platform));
    await tester.pumpWidget(
      RepositoryProvider<AppConfig>.value(
        value: AppConfig(
          environment: Environment.mock,
          apiBaseUrl: 'https://studio.example.test/api',
          certificatePins: const [],
          idleTimeout: null,
          platform: target,
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SessionCubit>.value(value: session),
            BlocProvider<OnboardingCubit>.value(value: onboarding),
            BlocProvider(create: (_) => studioBloc),
            BlocProvider(create: (_) => platformBloc),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            builder: (context, _) => AppStatusGate(child: child),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> checkStudio(WidgetTester tester) async {
    studioBloc.add(const StudioLivenessCheckRequested());
    await tester.pump();
    await tester.pump();
  }

  Future<void> checkPlatform(WidgetTester tester) async {
    platformBloc.add(const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.retry));
    await tester.pump();
    await tester.pump();
  }

  Future<void> changeSession(WidgetTester tester, SessionState state) async {
    sessions.add(state);
    await tester.pump();
    await tester.pump();
  }

  Future<void> changeOnboarding(WidgetTester tester, OnboardingState state) async {
    introductions.add(state);
    await tester.pump();
    await tester.pump();
  }

  const sessionStates = <(String, SessionState)>[
    ('a Studio session', _studioSession),
    ('a Platform session', _platformSession),
    ('the restore', SessionUnknown()),
    ('the login page', SessionUnauthenticated()),
  ];

  // As on 3777948: the Studio gate covers the restore, the login page and a Studio session; Platform is never asked.
  group('a build without a Platform target', () {
    const target = PlatformNotConfigured();

    testWidgets('shows a signed-in Platform session while Studio is unreachable', (tester) async {
      await pumpAppGate(tester, target: target, initial: _platformSession);
      when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkStudio(tester);

      expect(find.byType(StudioUnreachablePage), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });

    for (final (name, state) in sessionStates.where((s) => s.$2 != _platformSession)) {
      testWidgets('covers $name with the Studio unreachable page while Studio is unreachable', (tester) async {
        await pumpAppGate(tester, target: target, initial: state);
        when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
        await checkStudio(tester);

        expect(find.byType(StudioUnreachablePage), findsOneWidget);
        expect(find.text('app content'), findsNothing);
      });
    }

    testWidgets('never asks Platform, in any session state', (tester) async {
      await pumpAppGate(tester, target: target, initial: const SessionUnknown());
      for (final (_, state) in sessionStates) {
        await changeSession(tester, state);
      }

      verifyNever(() => platform.liveness());
      expect(find.byType(PlatformUnreachablePage), findsNothing);
    });

    testWidgets('keeps the child and its unsaved input when a Platform session ends', (tester) async {
      await pumpAppGate(tester, target: target, initial: _platformSession, child: _form());
      await tester.enterText(find.byType(TextField), 'unsaved draft');
      when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkStudio(tester);

      await changeSession(tester, const SessionUnauthenticated());

      expect(find.byType(StudioUnreachablePage), findsOneWidget);
      expect(find.text('unsaved draft', skipOffstage: false), findsOneWidget);
    });
  });

  group('a build with a Platform target', () {
    const target = PlatformConfigured(baseUrl: 'https://platform.example.test/api');

    group('with Studio unreachable', () {
      testWidgets('covers a Studio session with the Studio unreachable page', (tester) async {
        await pumpAppGate(tester, target: target, initial: _studioSession);
        when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
        await checkStudio(tester);

        expect(find.byType(StudioUnreachablePage), findsOneWidget);
        expect(find.byType(PlatformUnreachablePage), findsNothing);
        expect(find.text('app content'), findsNothing);
      });

      for (final (name, state) in sessionStates.where((s) => s.$2 != _studioSession)) {
        testWidgets('shows $name, with no unreachable page', (tester) async {
          await pumpAppGate(tester, target: target, initial: state);
          when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
          await checkStudio(tester);

          expect(find.byType(StudioUnreachablePage), findsNothing);
          expect(find.byType(PlatformUnreachablePage), findsNothing);
          expect(find.text('app content'), findsOneWidget);
        });
      }
    });

    group('with Platform unreachable', () {
      testWidgets('covers a Platform session with the Platform unreachable page', (tester) async {
        await pumpAppGate(tester, target: target, initial: _platformSession);
        when(() => platform.liveness()).thenAnswer((_) async => const Failure(_offline));
        await checkPlatform(tester);

        expect(find.byType(PlatformUnreachablePage), findsOneWidget);
        expect(find.byType(StudioUnreachablePage), findsNothing);
        expect(find.text('app content'), findsNothing);
      });

      for (final (name, state) in sessionStates.where((s) => s.$2 != _platformSession)) {
        testWidgets('shows $name, with no unreachable page', (tester) async {
          await pumpAppGate(tester, target: target, initial: state);
          when(() => platform.liveness()).thenAnswer((_) async => const Failure(_offline));
          await checkPlatform(tester);

          expect(find.byType(StudioUnreachablePage), findsNothing);
          expect(find.byType(PlatformUnreachablePage), findsNothing);
          expect(find.text('app content'), findsOneWidget);
        });
      }
    });

    group("Platform's first check", () {
      for (final (name, state) in <(String, SessionState)>[
        ('the login page', const SessionUnauthenticated()),
        ('a Platform session', _platformSession),
      ]) {
        testWidgets('is sent once when the app opens on $name', (tester) async {
          await pumpAppGate(tester, target: target, initial: state);

          verify(() => platform.liveness()).called(1);
        });
      }

      testWidgets('is not sent during the restore or in a Studio session', (tester) async {
        await pumpAppGate(tester, target: target, initial: const SessionUnknown());
        await changeSession(tester, _studioSession);

        verifyNever(() => platform.liveness());
      });

      testWidgets('is sent when the session first needs Platform, and only then', (tester) async {
        await pumpAppGate(tester, target: target, initial: const SessionUnknown());
        verifyNever(() => platform.liveness());

        await changeSession(tester, const SessionUnauthenticated());
        verify(() => platform.liveness()).called(1);

        await changeSession(tester, _platformSession);
        await changeSession(tester, const SessionUnauthenticated());
        verifyNever(() => platform.liveness());
      });
    });

    testWidgets('keeps a text field through an outage, a recovery and a session change', (tester) async {
      await pumpAppGate(tester, target: target, initial: _platformSession, child: _form());
      await tester.enterText(find.byType(TextField), 'unsaved draft');

      when(() => platform.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkPlatform(tester);
      expect(find.byType(PlatformUnreachablePage), findsOneWidget);
      expect(find.text('unsaved draft', skipOffstage: false), findsOneWidget);

      when(() => platform.liveness()).thenAnswer((_) async => const Success(null));
      await checkPlatform(tester);
      expect(find.byType(PlatformUnreachablePage), findsNothing);
      expect(find.text('unsaved draft'), findsOneWidget);

      when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkStudio(tester);
      await changeSession(tester, const SessionUnauthenticated());
      expect(find.text('unsaved draft'), findsOneWidget);
      await changeSession(tester, _studioSession);
      expect(find.byType(StudioUnreachablePage), findsOneWidget);
      expect(find.text('unsaved draft', skipOffstage: false), findsOneWidget);
    });
  });

  /// The introduction needs no server, and it is the first screen a new user meets. A gate that covers it with an
  /// unreachable page turns the one screen guaranteed to work offline into a failure notice — the exact first
  /// impression this milestone exists to remove. So while the introduction is required, both gates pass through and
  /// Platform's first check waits for it to end.
  group('while the introduction is required', () {
    const introduction = OnboardingRequired();

    testWidgets('shows the introduction in a build without a Platform target, with Studio unreachable', (tester) async {
      await pumpAppGate(
        tester,
        target: const PlatformNotConfigured(),
        initial: const SessionUnauthenticated(),
        introduction: introduction,
      );
      when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkStudio(tester);

      expect(find.byType(StudioUnreachablePage), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('shows the introduction in a build with a Platform target, with both servers unreachable', (
      tester,
    ) async {
      await pumpAppGate(
        tester,
        target: const PlatformConfigured(baseUrl: 'https://platform.example.test/api'),
        initial: const SessionUnauthenticated(),
        introduction: introduction,
      );
      when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
      when(() => platform.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkStudio(tester);
      await checkPlatform(tester);

      expect(find.byType(StudioUnreachablePage), findsNothing);
      expect(find.byType(PlatformUnreachablePage), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });

    // AppStatusGate sits above the wait that holds the router back, so it is built while the flag is still being
    // read. Asking then is asking before the answer exists: a first run would probe a server on the way to a screen
    // that needs none, which is the thing this defers. The restore is short, and nothing but the spinner is on
    // screen during it, so waiting for it costs nothing.
    testWidgets('asks Platform nothing while the flag is still being read', (tester) async {
      await pumpAppGate(
        tester,
        target: const PlatformConfigured(baseUrl: 'https://platform.example.test/api'),
        initial: const SessionUnauthenticated(),
        introduction: const OnboardingRestoring(),
      );

      verifyNever(() => platform.liveness());
    });

    testWidgets('asks Platform once the flag says the introduction is behind the user', (tester) async {
      await pumpAppGate(
        tester,
        target: const PlatformConfigured(baseUrl: 'https://platform.example.test/api'),
        initial: const SessionUnauthenticated(),
        introduction: const OnboardingRestoring(),
      );
      verifyNever(() => platform.liveness());

      await changeOnboarding(tester, const OnboardingSeen());

      verify(() => platform.liveness()).called(1);
    });

    testWidgets('asks Platform nothing, although the login page would', (tester) async {
      await pumpAppGate(
        tester,
        target: const PlatformConfigured(baseUrl: 'https://platform.example.test/api'),
        initial: const SessionUnauthenticated(),
        introduction: introduction,
      );

      verifyNever(() => platform.liveness());
    });

    testWidgets('asks Platform once the introduction ends, and only once', (tester) async {
      await pumpAppGate(
        tester,
        target: const PlatformConfigured(baseUrl: 'https://platform.example.test/api'),
        initial: const SessionUnauthenticated(),
        introduction: introduction,
      );
      verifyNever(() => platform.liveness());

      await changeOnboarding(tester, const OnboardingSeen());
      verify(() => platform.liveness()).called(1);

      await changeSession(tester, _platformSession);
      verifyNever(() => platform.liveness());
    });

    testWidgets('covers the login page again once the introduction ends and Studio does not answer', (tester) async {
      await pumpAppGate(
        tester,
        target: const PlatformNotConfigured(),
        initial: const SessionUnauthenticated(),
        introduction: introduction,
      );
      when(() => studio.liveness()).thenAnswer((_) async => const Failure(_offline));
      await checkStudio(tester);
      expect(find.byType(StudioUnreachablePage), findsNothing);

      await changeOnboarding(tester, const OnboardingSeen());

      expect(find.byType(StudioUnreachablePage), findsOneWidget);
    });
  });
}
