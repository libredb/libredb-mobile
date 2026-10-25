@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:libredb_mobile/app/app_studio_status_gate.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_status_gate.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

class _MockSessionCubit extends MockCubit<SessionState> implements SessionCubit {}

void main() {
  late MockIStudioStatusRepository repository;
  late StudioStatusBloc bloc;

  setUp(() {
    repository = MockIStudioStatusRepository();
    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
  });

  // The bloc is created inside the test body, so its event stream runs in the test's fake async zone, and the
  // provider closes it when the test unmounts the tree.
  Future<void> pumpGate(WidgetTester tester, Widget child, {Widget Function(Widget child)? gate}) async {
    bloc = StudioStatusBloc(
      checkLivenessUseCase: CheckStudioLivenessUseCase(repository),
      readReadinessUseCase: ReadStudioReadinessUseCase(repository),
    );
    await tester.pumpWidget(
      RepositoryProvider<AppConfig>.value(
        value: const AppConfig(
          environment: Environment.test,
          apiBaseUrl: 'https://studio.example.test/api',
          certificatePins: [],
          idleTimeout: null,
        ),
        child: BlocProvider(
          create: (_) => bloc,
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
            builder: (context, _) => (gate ?? (child) => StudioStatusGate(child: child))(child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> checkLiveness(WidgetTester tester) async {
    bloc.add(const StudioLivenessCheckRequested());
    await tester.pump();
    await tester.pump();
  }

  // A network blip on resume must not cost the user the screen they were on, such as a form with unsaved input.
  testWidgets('keeps the app and its unsaved input while Studio is unreachable, and shows it again once it answers', (
    tester,
  ) async {
    // A Navigator under the gate, as the router is in the app.
    await pumpGate(
      tester,
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: TextField())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'unsaved draft');

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    expect(find.byType(StudioUnreachablePage), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);

    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
    await checkLiveness(tester);

    expect(find.byType(StudioUnreachablePage), findsNothing);
    expect(find.text('unsaved draft'), findsOneWidget);
  });

  testWidgets('hides the app from semantics and stops its tickers while Studio is unreachable', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGate(tester, const Scaffold(body: Text('app content')));

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    final content = find.text('app content', skipOffstage: false);
    expect(TickerMode.valuesOf(tester.element(content)).enabled, isFalse);
    expect(find.bySemanticsLabel('app content'), findsNothing);
    semantics.dispose();
  });

  testWidgets('passes its child through, with no unreachable page, when told to', (tester) async {
    await pumpGate(
      tester,
      const Scaffold(body: Text('app content')),
      gate: (child) => StudioStatusGate(passThrough: true, child: child),
    );

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    expect(find.byType(StudioUnreachablePage), findsNothing);
    expect(find.text('app content'), findsOneWidget);
  });

  // M10-P: only a signed-in Platform session passes through; scoping the gate to Studio sessions is M11-P.
  group('AppStudioStatusGate', () {
    late _MockSessionCubit session;
    late StreamController<SessionState> sessions;

    setUp(() {
      session = _MockSessionCubit();
      sessions = StreamController<SessionState>.broadcast();
      addTearDown(sessions.close);
    });

    Future<void> pumpAppGate(WidgetTester tester, SessionState initial, Widget child) async {
      whenListen(session, sessions.stream, initialState: initial);
      await pumpGate(
        tester,
        child,
        gate: (child) => BlocProvider<SessionCubit>.value(
          value: session,
          child: AppStudioStatusGate(child: child),
        ),
      );
      when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
      await checkLiveness(tester);
    }

    testWidgets('shows a signed-in Platform session while Studio is unreachable', (tester) async {
      await pumpAppGate(
        tester,
        const SessionAuthenticated(target: SessionTarget.platform),
        const Scaffold(body: Text('platform shell')),
      );

      expect(find.byType(StudioUnreachablePage), findsNothing);
      expect(find.text('platform shell'), findsOneWidget);
    });

    for (final (name, state) in <(String, SessionState)>[
      ('a Studio session', const SessionAuthenticated(target: SessionTarget.studio)),
      ('the restore', const SessionUnknown()),
      ('the login page', const SessionUnauthenticated()),
    ]) {
      testWidgets('covers $name with the unreachable page while Studio is unreachable', (tester) async {
        await pumpAppGate(tester, state, const Scaffold(body: Text('app content')));

        expect(find.byType(StudioUnreachablePage), findsOneWidget);
        expect(find.text('app content'), findsNothing);
      });
    }

    testWidgets('keeps the child and its unsaved input when a Platform session ends', (tester) async {
      await pumpAppGate(
        tester,
        const SessionAuthenticated(target: SessionTarget.platform),
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: TextField())),
        ),
      );
      await tester.enterText(find.byType(TextField), 'unsaved draft');

      sessions.add(const SessionUnauthenticated());
      await tester.pump();

      expect(find.byType(StudioUnreachablePage), findsOneWidget);
      expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
      expect(find.text('unsaved draft', skipOffstage: false), findsOneWidget);
    });
  });
}
