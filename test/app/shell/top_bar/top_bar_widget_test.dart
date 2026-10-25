@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/test_env.dart';
import '../../../support/user_menu.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  // The real app, signed in, on the connection list, after the mock API has answered.
  Future<void> pumpSignedIn(
    WidgetTester tester, {
    Size size = const Size(1600, 1600),
    String language = 'en',
    double textScale = 1.0,
  }) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: language));
    await tester.pumpAndSettle();
  }

  Finder avatar() => find.byKey(profileButtonKey);
  Finder inSheet(Finder finder) => find.descendant(of: find.byType(ProfileSheet), matching: finder);

  group('TopBarWidget - profile sheet', () {
    testWidgets("the avatar opens the profile sheet with the username and role from Studio's /auth/me", (tester) async {
      await pumpSignedIn(tester);

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      // assets/mock/GET_auth_me.json and GET_connections_policy.json.
      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(inSheet(find.text('Administrator')), findsOneWidget);
      expect(inSheet(find.widgetWithText(Chip, 'Governed by LibreDB Platform')), findsOneWidget);
    });

    for (final location in const [
      ApplicationRoutesConstants.connectionList,
      ApplicationRoutesConstants.browse,
      ApplicationRoutesConstants.sql,
    ]) {
      testWidgets('Settings opens the settings on top of $location, and the back arrow returns to it', (tester) async {
        await pumpSignedIn(tester);
        routerOf(tester).go(location);
        await tester.pumpAndSettle();

        await selectFromUserMenu(tester, Icons.settings_outlined);

        expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.settings);
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)));
        await tester.pumpAndSettle();

        expect(routerOf(tester).state.uri.path, location);
      });
    }

    testWidgets('the back arrow of settings opened by a link, with nothing under it, opens the connection list', (
      tester,
    ) async {
      await pumpSignedIn(tester);
      routerOf(tester).go(ApplicationRoutesConstants.settings);
      await tester.pumpAndSettle();
      expect(routerOf(tester).canPop(), isFalse);

      await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
    });

    testWidgets('a tab has no back arrow', (tester) async {
      await pumpSignedIn(tester);

      expect(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)), findsNothing);
    });

    testWidgets('Logout signs the user out and opens the login page with no signed-in page to go back to', (
      tester,
    ) async {
      await pumpSignedIn(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse);
      // The app-scoped answers about the user who signed out are gone before the next user signs in.
      final login = tester.element(find.byType(LoginScreen));
      expect(login.read<StudioIdentityCubit>().state, const StudioIdentityInitial());
      expect(login.read<ConnectionPolicyCubit>().state, const ConnectionPolicyInitial());
    });

    testWidgets('after a sign-out and a new sign-in, the shell asks Studio again who the user is', (tester) async {
      await pumpSignedIn(tester);
      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pumpAndSettle();

      TestEnv.authenticate();
      tester.element(find.byType(LoginScreen)).read<SessionCubit>().markAuthenticated(SessionTarget.studio);
      await tester.pumpAndSettle();
      await tester.tap(avatar());
      await tester.pumpAndSettle();

      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(tester.element(find.byType(ProfileSheet)).read<StudioIdentityCubit>().state, isA<StudioIdentityLoaded>());
    });

    testWidgets('a declined logout keeps the user signed in on the page', (tester) async {
      await pumpSignedIn(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(TextButton, 'No'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
    });
  });

  group('TopBarWidget - mode switch', () {
    Finder switchTile() => inSheet(find.byKey(profileSwitchModeKey));

    /// Waits for the mock's latency of the gate, then for the home the switch opens.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> openSwitch(WidgetTester tester) async {
      await tester.tap(avatar());
      await tester.pumpAndSettle();
      await tester.tap(switchTile());
      await tester.pumpAndSettle();
    }

    testWidgets('to Platform asks with the admin seat note first, then lands on the Platform home', (tester) async {
      await pumpSignedIn(tester);

      await openSwitch(tester);

      expect(find.text('Switch to Platform?'), findsOneWidget);
      expect(find.textContaining('takes one admin seat of the license'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
      await settle(tester);

      expect(find.byType(PlatformShell), findsOneWidget);
      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.homeFor(SessionTarget.platform));
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'platform');
    });

    testWidgets('to Platform, Cancel in the seat note keeps the Studio session and sends nothing', (tester) async {
      await pumpSignedIn(tester);

      await openSwitch(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);

      expect(find.byType(AppShell), findsOneWidget);
      expect(
        tester.element(find.byType(AppShell)).read<SessionTargetSwitchBloc>().state,
        const SessionTargetSwitchIdle(),
      );
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'studio');
    });

    testWidgets('to Studio asks nothing and lands on the Studio home', (tester) async {
      TestEnv.authenticate(target: SessionTarget.platform);
      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
      await settle(tester);
      expect(find.byType(PlatformShell), findsOneWidget);

      await openSwitch(tester);
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.homeFor(SessionTarget.studio));
      expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'studio');
    });

    for (final (code, message) in [
      ('ADMIN_ROLE_REQUIRED', 'This account is not a Platform admin, so it stays in Studio.'),
      ('LICENSE_ADMIN_SEATS', 'The Platform license has no free admin seat for this account.'),
    ]) {
      testWidgets('a Platform 403 $code keeps the Studio session and says why', (tester) async {
        TestEnv.authenticate();
        await tester.pumpWidget(App(dependencies: _RefusingPlatformDependencies(code), language: 'en'));
        await settle(tester);

        await openSwitch(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
        await settle(tester);

        expect(find.text(message), findsOneWidget);
        expect(find.byType(AppShell), findsOneWidget);
        expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
        final shell = tester.element(find.byType(AppShell));
        expect(shell.read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.studio));
        expect(shell.read<StudioIdentityCubit>().state, isA<StudioIdentityLoaded>());
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'studio');
      });
    }

    testWidgets('a build without a Platform target offers no switch', (tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(
        App(
          dependencies: MockSignInDependencies(
            appConfig: const AppConfig(
              environment: Environment.mock,
              apiBaseUrl: null,
              certificatePins: <String>[],
              idleTimeout: null,
            ),
          ),
          language: 'en',
        ),
      );
      await settle(tester);

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      expect(switchTile(), findsNothing);
    });
  });

  // No route of the app registers a form yet, so a page with one is built here, under a router as the shell is.
  group('TopBarWidget - mode switch with unsaved changes', () {
    late MockSessionTargetSwitchBloc switchBloc;
    late MockStudioIdentityCubit identity;
    late MockConnectionPolicyCubit policy;

    setUp(() {
      switchBloc = MockSessionTargetSwitchBloc();
      identity = MockStudioIdentityCubit();
      policy = MockConnectionPolicyCubit();
      when(() => switchBloc.state).thenReturn(const SessionTargetSwitchIdle());
      when(() => identity.state).thenReturn(const StudioIdentityInitial());
      when(() => policy.state).thenReturn(const ConnectionPolicyInitial());
    });

    Future<void> pumpDirtyPage(WidgetTester tester, {required bool dirty}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => UnsavedChangesScope(
              hasUnsavedChanges: () => dirty,
              onBack: () {},
              child: const Scaffold(
                body: TopBarWidget(target: SessionTarget.studio, title: 'Form'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            RepositoryProvider<AppConfig>.value(value: const AppConfig.test()),
            RepositoryProvider<UnsavedChangesRegistry>(
              create: (_) => UnsavedChangesRegistry(isExitForced: (_) => false),
            ),
            BlocProvider<SessionTargetSwitchBloc>.value(value: switchBloc),
            BlocProvider<StudioIdentityCubit>.value(value: identity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
          ),
        ),
      );
      await tester.tap(avatar());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(profileSwitchModeKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The seat note comes first.
      await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('asks the unsaved-changes question once and sends nothing on No', (tester) async {
      await pumpDirtyPage(tester, dirty: true);

      expect(find.text(S.current.unsaved_changes), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'No'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(S.current.unsaved_changes), findsNothing);
      verifyNever(() => switchBloc.add(any()));
    });

    testWidgets('switches on Yes', (tester) async {
      await pumpDirtyPage(tester, dirty: true);

      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => switchBloc.add(const SessionTargetSwitchRequested(SessionTarget.platform))).called(1);
    });

    testWidgets('a clean page switches without the question', (tester) async {
      await pumpDirtyPage(tester, dirty: false);

      expect(find.text(S.current.unsaved_changes), findsNothing);
      verify(() => switchBloc.add(const SessionTargetSwitchRequested(SessionTarget.platform))).called(1);
    });
  });

  group('TopBarWidget - a failed /auth/me', () {
    testWidgets('shows the user as unknown with a retry, keeps the user signed in, and Retry asks Studio again', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      TestEnv.authenticate();
      final studio = _OnceRefusingStudio();
      await tester.pumpWidget(App(dependencies: _StudioIdentityDependencies(studio), language: 'en'));
      await tester.pumpAndSettle();

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Unknown user')), findsOneWidget);
      expect(tester.element(find.byType(ProfileSheet)).read<SessionCubit>().state, isA<SessionAuthenticated>());
      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);

      await tester.tap(inSheet(find.widgetWithText(TextButton, 'Retry')));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(inSheet(find.text('Unknown user')), findsNothing);
      expect(studio.fetches, 2);
    });
  });

  group('TopBarWidget - sign-out progress', () {
    testWidgets('the signed-in shell sits under the sign-out progress barrier', (tester) async {
      await pumpSignedIn(tester);

      expect(
        find.ancestor(of: find.byType(TopBarWidget), matching: find.byType(SignOutProgressBarrier)),
        findsOneWidget,
      );
    });
  });

  group('TopBarWidget - Turkish', () {
    testWidgets('the profile sheet shows its entries and the role in Turkish', (tester) async {
      await pumpSignedIn(tester, language: 'tr');

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      for (final label in ['Ayarlar', 'Çıkış Yap']) {
        expect(inSheet(find.widgetWithText(ListTile, label)), findsOneWidget, reason: label);
      }
      expect(inSheet(find.text('Yönetici')), findsOneWidget);
    });
  });

  group('TopBarWidget - phone width', () {
    // The narrowest phones, at the default text size and with the system text size raised to 130 percent, in both app
    // languages.
    for (final language in const ['en', 'tr']) {
      for (final textScale in const [1.0, 1.3]) {
        for (final size in const [Size(320, 568), Size(360, 640), Size(375, 667)]) {
          testWidgets('the signed-in top bar fits a ${size.width.toInt()}x${size.height.toInt()} phone at text scale '
              '$textScale in $language', (tester) async {
            await pumpSignedIn(tester, size: size, language: language, textScale: textScale);

            expect(tester.takeException(), isNull);
            expect(tester.getRect(avatar()).right, lessThanOrEqualTo(tester.getRect(find.byType(TopBarWidget)).right));
          });
        }
      }
    }

    // A screen reader user has to know what the bare avatar does, in the language of the app.
    for (final (language, label) in const [('en', 'Profile'), ('tr', 'Profil')]) {
      testWidgets('the avatar is announced as $label in $language', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSignedIn(tester, size: const Size(360, 640), language: language);

        expect(tester.getSemantics(avatar()), isSemantics(tooltip: label, isButton: true, hasTapAction: true));
        semantics.dispose();
      });
    }

    // A page title much longer than any of the app's, on the narrowest phone.
    testWidgets('a long page title is shortened instead of overflowing a 320 px bar', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      const title = 'A page title far longer than the narrowest phone has room for';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: TopBarWidget(target: SessionTarget.studio, title: title, onBack: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(avatar()).right, lessThanOrEqualTo(320));
      expect(find.text(title), findsOneWidget);
    });
  });
}

/// Studio's `GET /api/auth/me`, refusing the first request as Studio main does when it cannot check the token (a 401
/// without a code, which the ApiClient has already tried once more after a token refresh), then answering an admin.
class _OnceRefusingStudio implements IStudioIdentityRepository {
  int fetches = 0;

  @override
  Future<Result<StudioIdentity>> fetch() async {
    fetches++;
    if (fetches == 1) return const Failure(AuthError('The session answer is not signed in'));
    return const Success(StudioIdentity(username: 'admin@example.com', role: StudioAdminRole(), viaBearer: true));
  }

  @override
  Future<Result<void>> recordSignOut() async => const Success(null);
}

class _StudioIdentityDependencies extends MockSignInDependencies {
  _StudioIdentityDependencies(this.studio);

  final IStudioIdentityRepository studio;

  @override
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) => studio;
}

/// Platform's `GET /api/v1/me`, refusing the account with a 403 [code] through the mapping of the Platform repository.
class _RefusingPlatformIdentity implements IPlatformIdentityRepository {
  _RefusingPlatformIdentity(this.code);

  final String code;

  @override
  Future<Result<PlatformIdentity>> fetch() async =>
      Failure(platformError(UnauthorizedException('Platform answered 403', statusCode: 403, errorCode: code)));
}

class _RefusingPlatformDependencies extends MockSignInDependencies {
  _RefusingPlatformDependencies(this.code);

  final String code;

  @override
  IPlatformIdentityRepository createPlatformIdentityRepository(PlatformApiClient apiClient) =>
      _RefusingPlatformIdentity(code);
}
