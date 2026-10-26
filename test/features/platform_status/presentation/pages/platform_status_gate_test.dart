@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/usecases/check_platform_liveness_usecase.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_status_gate.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/widgets/platform_unreachable_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

void main() {
  late MockIPlatformStatusRepository repository;
  late PlatformStatusBloc bloc;

  setUp(() {
    repository = MockIPlatformStatusRepository();
    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
  });

  Future<void> pumpGate(WidgetTester tester, Widget child, {bool passThrough = false}) async {
    bloc = PlatformStatusBloc(checkLivenessUseCase: CheckPlatformLivenessUseCase(repository));
    await tester.pumpWidget(
      RepositoryProvider<AppConfig>.value(
        value: const AppConfig(
          environment: Environment.mock,
          apiBaseUrl: 'https://studio.example.test/api',
          certificatePins: [],
          idleTimeout: null,
          platform: PlatformConfigured(baseUrl: 'https://platform.example.test:8443/api'),
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
            builder: (context, _) => PlatformStatusGate(passThrough: passThrough, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> checkLiveness(WidgetTester tester) async {
    bloc.add(const PlatformLivenessCheckRequested());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the child before any answer and while Platform answers', (tester) async {
    await pumpGate(tester, const Scaffold(body: Text('platform shell')));
    expect(find.text('platform shell'), findsOneWidget);

    await checkLiveness(tester);

    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(find.text('platform shell'), findsOneWidget);
  });

  testWidgets('keeps the app and its unsaved input while Platform is unreachable, and shows it again once it answers', (
    tester,
  ) async {
    await pumpGate(
      tester,
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: TextField())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'unsaved draft');

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    expect(find.byType(PlatformUnreachablePage), findsOneWidget);
    expect(find.text("Can't reach Platform"), findsOneWidget);
    expect(find.text('Platform address: platform.example.test:8443'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);

    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
    await checkLiveness(tester);

    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(find.text('unsaved draft'), findsOneWidget);
  });

  testWidgets('Retry asks Platform again and clears the page once it answers', (tester) async {
    await pumpGate(tester, const Scaffold(body: Text('platform shell')));
    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);
    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    verify(() => repository.liveness()).called(2);
    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(find.text('platform shell'), findsOneWidget);
  });

  testWidgets('hides the app from semantics and stops its tickers while Platform is unreachable', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGate(tester, const Scaffold(body: Text('app content')));

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    final content = find.text('app content', skipOffstage: false);
    expect(TickerMode.valuesOf(tester.element(content)).enabled, isFalse);
    expect(find.bySemanticsLabel('app content'), findsNothing);
    semantics.dispose();
  });

  // A screen that failed while covered loads again once uncovered (#343), so it must know when it is covered.
  testWidgets('tells the screens below it whether the unreachable page covers them', (tester) async {
    final covered = <bool>[];
    await pumpGate(
      tester,
      Builder(
        builder: (context) {
          covered.add(PlatformUnreachableStatus.isUnreachableOf(context));
          return const SizedBox();
        },
      ),
    );
    expect(covered.last, isFalse);

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);
    expect(covered.last, isTrue);

    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
    await checkLiveness(tester);
    expect(covered.last, isFalse);
  });

  testWidgets('tells a passed-through screen that nothing covers it', (tester) async {
    final covered = <bool>[];
    await pumpGate(
      tester,
      Builder(
        builder: (context) {
          covered.add(PlatformUnreachableStatus.isUnreachableOf(context));
          return const SizedBox();
        },
      ),
      passThrough: true,
    );

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    expect(covered, everyElement(isFalse));
  });

  testWidgets('passes its child through, with no unreachable page, when told to', (tester) async {
    await pumpGate(tester, const Scaffold(body: Text('app content')), passThrough: true);

    when(() => repository.liveness()).thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
    await checkLiveness(tester);

    expect(find.byType(PlatformUnreachablePage), findsNothing);
    expect(find.text('app content'), findsOneWidget);
  });

  testWidgets('tells the bloc when the app goes to the background and comes back', (tester) async {
    await pumpGate(tester, const Scaffold(body: Text('platform shell')));
    await checkLiveness(tester);
    verify(() => repository.liveness()).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(PlatformStatusBloc.defaultRecheckAfter + const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    verify(() => repository.liveness()).called(1);
  });
}
