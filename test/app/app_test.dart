@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/design_system/components/app_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_classes.dart';

/// Device preferences whose stored language arrives only when [language] completes, like a slow device.
class _HeldLanguageStorage implements AppLocalStorage {
  _HeldLanguageStorage(this.language);

  final Future<Object?> language;

  @override
  Future<dynamic> read(String key) => key == StorageKeys.language.key ? language : AppLocalStorage().read(key);
  @override
  Future<bool> save(String key, dynamic value) => AppLocalStorage().save(key, value);
  @override
  Future<bool> remove(String key) => AppLocalStorage().remove(key);
  @override
  Future<void> clear() => AppLocalStorage().clear();
  @override
  void setPreferencesInstance(SharedPreferences prefs) => AppLocalStorage().setPreferencesInstance(prefs);
}

class _LocalStorageDependencies extends LocalSignInDependencies {
  _LocalStorageDependencies(this.localStorage);

  final AppLocalStorage localStorage;

  @override
  AppLocalStorage createLocalStorage() => localStorage;
}

void main() {
  group('App', () {
    testWidgets('shows a loading indicator in place of the router until the stored session is restored', (
      tester,
    ) async {
      final storedToken = Completer<String?>();
      final secureStorage = MockISecureStorage();
      when(() => secureStorage.read(any())).thenAnswer((_) => storedToken.future);
      final analytics = MockAnalyticsService();
      await tester.pumpWidget(
        App(
          dependencies: LocalSignInDependencies(),
          language: 'en',
          secureStorage: secureStorage,
          analytics: analytics,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      verifyNever(
        () => analytics.logScreenView(
          screenName: any(named: 'screenName'),
          screenClass: any(named: 'screenClass'),
        ),
      );

      storedToken.complete(null);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Loading...'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows the login page once secure storage has not answered within the restore time limit', (
      tester,
    ) async {
      final secureStorage = MockISecureStorage();
      when(() => secureStorage.read(any())).thenAnswer((_) => Completer<String?>().future);
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pump(SessionCubit.defaultRestoreTimeLimit - const Duration(milliseconds: 1));

      expect(find.bySemanticsLabel('Loading...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Loading...'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('opens the app when secure storage answers with a stored session after the restore time limit', (
      tester,
    ) async {
      final storedToken = Completer<String?>();
      final secureStorage = MockISecureStorage();
      when(() => secureStorage.read(any())).thenAnswer((_) => storedToken.future);
      when(() => secureStorage.read(SecureStorageKeys.sessionTarget.key)).thenAnswer((_) async => 'studio');
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pump(SessionCubit.defaultRestoreTimeLimit);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      storedToken.complete('MOCK_TOKEN');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(ResponsiveScaffold), findsOneWidget);
    });

    // A deep link starts the app on a page, which the restore time limit replaces with
    // the login page that keeps the page as its returnUrl.
    testWidgets('opens the page the app started on when a stored session answers after the restore time limit', (
      tester,
    ) async {
      tester.platformDispatcher.defaultRouteNameTestValue = ApplicationRoutesConstants.settings;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final storedToken = Completer<String?>();
      final secureStorage = MockISecureStorage();
      when(() => secureStorage.read(any())).thenAnswer((_) => storedToken.future);
      when(() => secureStorage.read(SecureStorageKeys.sessionTarget.key)).thenAnswer((_) async => 'studio');
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pump(SessionCubit.defaultRestoreTimeLimit);
      await tester.pumpAndSettle();
      GoRouter router() => tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      expect(router().state.uri.toString(), '/login?returnUrl=%2Fsettings');

      storedToken.complete('MOCK_TOKEN');
      await tester.pumpAndSettle();

      expect(router().state.uri.toString(), ApplicationRoutesConstants.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('shows a loading indicator in place of the router until the stored language is read', (tester) async {
      final storedLanguage = Completer<Object?>();
      await tester.pumpWidget(
        App(language: 'en', dependencies: _LocalStorageDependencies(_HeldLanguageStorage(storedLanguage.future))),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      storedLanguage.complete('tr');
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Loading...'), findsNothing);
      expect(find.text("Studio'ya giriş yap"), findsOneWidget);
    });

    testWidgets('starts in the language that an earlier run stored', (tester) async {
      await AppLocalStorage().save(StorageKeys.language.key, 'tr');

      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(find.text("Studio'ya giriş yap"), findsOneWidget);
      expect(find.text('Sign in to Studio'), findsNothing);
    });

    // A guard rather than a reproduction: it passed before the stored language was read. It keeps the router mounting
    // when restore ends in the language the app already shows.
    testWidgets('starts in the configured language when no language is stored', (tester) async {
      await AppLocalStorage().remove(StorageKeys.language.key);

      await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: 'tr'));
      await tester.pumpAndSettle();

      expect(find.text("Studio'ya giriş yap"), findsOneWidget);
      expect(find.text('Sign in to Studio'), findsNothing);
    });

    // The task switcher shows this title.
    for (final (language, title) in [('en', 'LibreDB'), ('tr', 'LibreDB')]) {
      testWidgets('names the app in the task switcher in the app language ($language)', (tester) async {
        await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: language));
        await tester.pumpAndSettle();

        expect(tester.widget<Title>(find.byType(Title)).title, title);
      });
    }

    // No maintenance or update gate stands in front of the app: Studio offers neither yet.
    testWidgets('reaches the sign-in page at start with no gate in front of it', (tester) async {
      final secureStorage = MockISecureStorage();
      when(() => secureStorage.read(any())).thenAnswer((_) async => null);
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  // The gate sits in the MaterialApp builder. These tests replace the Studio status repository; the last one reads
  // the answer the mock serves.
  group('App Studio status gate', () {
    const offline = NetworkError('No Internet connection');
    late MockIStudioStatusRepository repository;
    late MockISecureStorage secureStorage;

    setUp(() {
      repository = MockIStudioStatusRepository();
      when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
      secureStorage = MockISecureStorage();
      when(() => secureStorage.read(any())).thenAnswer((_) async => null);
    });

    Future<void> pumpApp(WidgetTester tester, {AppConfig appConfig = const AppConfig.dev()}) async {
      await tester.pumpWidget(
        App(
          language: 'en',
          secureStorage: secureStorage,
          dependencies: _StudioStatusDependencies(repository, appConfig: appConfig),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Airplane mode at start: the session is stored, Studio cannot be reached, and the user must not sign in again.
    testWidgets('shows the unreachable page at start, and Retry opens the app without a new sign-in', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = ApplicationRoutesConstants.settings;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      when(() => secureStorage.read(SecureStorageKeys.jwtToken.key)).thenAnswer((_) async => 'MOCK_TOKEN');
      when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));

      await pumpApp(tester);

      expect(find.byType(StudioUnreachablePage), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      final session = tester.element(find.byType(StudioUnreachablePage)).read<SessionCubit>();
      expect(session.state, isA<SessionAuthenticated>());

      when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      // The shell asks Studio who the user is when it opens, which the mock API answers after its 500 ms delay.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StudioUnreachablePage), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(session.state, isA<SessionAuthenticated>());
    });

    // M10-P: a signed-in Platform session does not need Studio, so the unreachable page does not cover it.
    testWidgets('shows a restored Platform session while Studio is unreachable', (tester) async {
      when(() => secureStorage.read(SecureStorageKeys.jwtToken.key)).thenAnswer((_) async => 'MOCK_TOKEN');
      when(() => secureStorage.read(SecureStorageKeys.sessionTarget.key)).thenAnswer((_) async => 'platform');
      when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));

      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(StudioUnreachablePage), findsNothing);
      expect(find.byType(PlatformShell), findsOneWidget);
    });

    testWidgets('names the configured Studio host on the unreachable page', (tester) async {
      when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));

      await pumpApp(
        tester,
        appConfig: const AppConfig(
          environment: Environment.test,
          apiBaseUrl: 'https://studio.example.test:9443/api',
          certificatePins: [],
          idleTimeout: null,
        ),
      );

      expect(find.textContaining('studio.example.test:9443'), findsOneWidget);
    });

    testWidgets('checks Studio when the app starts, while the stored session is still read', (tester) async {
      final storedToken = Completer<String?>();
      when(() => secureStorage.read(any())).thenAnswer((_) => storedToken.future);
      when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));

      await tester.pumpWidget(
        App(language: 'en', secureStorage: secureStorage, dependencies: _StudioStatusDependencies(repository)),
      );
      await tester.pump();
      await tester.pump();

      verify(() => repository.liveness()).called(1);
      expect(find.byType(StudioUnreachablePage), findsOneWidget);

      storedToken.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('checks Studio again on resume only after more than five minutes in the background', (tester) async {
      await pumpApp(tester);
      verify(() => repository.liveness()).called(1);

      await _sendToBackgroundAndBack(tester, away: StudioStatusBloc.defaultRecheckAfter);
      verifyNever(() => repository.liveness());
      expect(find.byType(LoginScreen), findsOneWidget);

      when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));
      await _sendToBackgroundAndBack(tester, away: StudioStatusBloc.defaultRecheckAfter + const Duration(seconds: 1));

      verify(() => repository.liveness()).called(1);
      expect(find.byType(StudioUnreachablePage), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    // GET /health is a public endpoint, so the mock answers it before sign-in.
    testWidgets('reads the liveness answer from the mock before sign-in', (tester) async {
      await tester.pumpWidget(
        App(dependencies: LocalSignInDependencies(), language: 'en', secureStorage: secureStorage),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(tester.element(find.byType(LoginScreen)).read<StudioStatusBloc>().state, const StudioReachable());
    });
  });
}

/// The app's dependencies with [repository] in place of the Studio status repository that AppDependencies creates.
class _StudioStatusDependencies extends LocalSignInDependencies {
  _StudioStatusDependencies(this.repository, {super.appConfig});

  final IStudioStatusRepository repository;

  @override
  IStudioStatusRepository createStudioStatusRepository(ApiClient apiClient) => repository;
}

/// Sends the app to the background for [away] and back, through every state Flutter reports on the way.
Future<void> _sendToBackgroundAndBack(WidgetTester tester, {Duration away = Duration.zero}) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  if (away > Duration.zero) await tester.pump(away);
  for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}
