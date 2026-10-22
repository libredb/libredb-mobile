@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/community_section_widget.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../support/user_menu.dart';

/// A sign-in that the provider accepts.
final _signedIn = OidcSignedIn(
  tokens: OidcTokens(
    accessToken: 'sso-access-token',
    idToken: 'sso-id-token',
    refreshToken: 'sso-refresh-token',
    accessTokenExpiresAt: DateTime.utc(2100),
  ),
  claims: const {'iss': 'https://id.example.com/realms/demo', 'sub': 'subject-1'},
);

/// The identity provider of an oidc build. Each sign-in answers with the next of [outcomes], and with [_signedIn] once
/// they have run out.
class _ScriptedOidcClient implements IOidcClient {
  _ScriptedOidcClient({List<FutureOr<OidcSignInOutcome>>? outcomes}) : outcomes = outcomes ?? [];

  final List<FutureOr<OidcSignInOutcome>> outcomes;

  /// How many sign-ins were started.
  int signIns = 0;

  @override
  Future<OidcSignInOutcome> signIn() async {
    signIns++;
    return outcomes.isEmpty ? _signedIn : await outcomes.removeAt(0);
  }

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('these tests store no expired session');

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async => const ProviderSessionEnded();
}

/// The test config over [client]: the mocked Studio answers `GET /api/auth/me`, unless [studio] answers it.
class _OidcDependencies extends AppDependencies {
  _OidcDependencies(this.client, {bool autoRedirect = false, this.rotation, this.studio})
    : super(
        appConfig: const AppConfig.test(),
        authMode: OidcAuthMode(
          OidcSettings(
            issuer: Uri.parse('https://id.example.com/realms/demo'),
            clientId: 'app',
            autoRedirect: autoRedirect,
          ),
        ),
      );

  final IOidcClient client;

  /// The token refresh in place of the one through [client], when given.
  final TokenRotation? rotation;

  /// Studio's answer to `GET /api/auth/me` in place of the mocked one, when given.
  final IStudioIdentityRepository? studio;

  @override
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) =>
      studio ?? super.createStudioIdentityRepository(apiClient);

  @override
  IOidcClient createOidcClient(OidcSettings settings) => client;

  @override
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) =>
      rotation ?? super.createOidcTokenRotation(client, secureStorage);
}

/// Studio's `GET /api/auth/me`, failing with [error].
class _RefusingStudio implements IStudioIdentityRepository {
  _RefusingStudio(this.error);

  final AppError error;

  @override
  Future<Result<StudioIdentity>> fetch() async => Failure(error);

  @override
  Future<Result<void>> recordSignOut() => throw UnimplementedError('these tests never sign out');
}

/// A token refresh that fails with an error no rotation expects, so the startup step of an oidc build throws.
class _ThrowingRotation implements TokenRotation {
  @override
  Future<TokenRotationResult> rotate(String refreshToken) async => throw StateError('rotation failed');
}

/// Stores a session whose access token has expired, so the startup step of an oidc build refreshes it.
Future<void> _storeExpiredSession() async {
  final storage = FlutterSecureStorageAdapter();
  await storage.write(SecureStorageKeys.jwtToken.key, 'expired-access-token');
  await storage.write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
  await storage.write(SecureStorageKeys.oidcIdToken.key, 'stored-id-token');
  await storage.write(SecureStorageKeys.accessTokenExpiresAt.key, encodeAccessTokenExpiry(DateTime.utc(2000)));
}

const _discoveryMessage =
    'The identity provider could not be reached. Try again later, or contact your administrator if this continues.';
const _failedMessage = 'Sign-in failed. Please try again.';
const _refusedMessage = 'Studio did not accept this sign-in. Try again, or ask an administrator for access.';
const _noRoleMessage = 'This account has no role in Studio. Ask an administrator to give it one.';
const _insecureConnectionMessage =
    'The connection could not be verified as secure, so it was blocked. Try again later or on another network.';
const _configMessage = 'Single sign-on is not configured correctly in this app. Contact your administrator.';

void main() {
  void setViewport(WidgetTester tester, Size size) {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
  }

  // The real app starts unauthenticated after the global reset, so it lands on /login.
  Future<void> pumpLogin(WidgetTester tester, {String language = 'en'}) async {
    await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: language));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  group('LoginScreen community section', () {
    testWidgets('renders once, as the brand panel cards, on a wide surface', (tester) async {
      setViewport(tester, const Size(1600, 1600));
      await pumpLogin(tester);

      expect(find.byType(CommunitySectionWidget), findsOneWidget);
      expect(find.byKey(communityDocsKey), findsOneWidget);
      expect(tester.widget<CommunitySectionWidget>(find.byType(CommunitySectionWidget)).isDesktop, isTrue);
    });

    testWidgets('renders once, as the chips below the form, on a narrow surface', (tester) async {
      setViewport(tester, const Size(390, 844));
      await pumpLogin(tester);

      expect(find.byType(CommunitySectionWidget), findsOneWidget);
      expect(find.byKey(communityDocsKey), findsOneWidget);
      expect(tester.widget<CommunitySectionWidget>(find.byType(CommunitySectionWidget)).isDesktop, isFalse);
    });
  });

  group('LoginScreen brand panel', () {
    // 1024 px is the narrowest width that shows the brand panel. The test font is wider than the real one, which
    // stands in for a larger text scale.
    testWidgets('lays out without overflow at the desktop breakpoint', (tester) async {
      setViewport(tester, const Size(1024, 1600));
      await pumpLogin(tester);

      expect(tester.takeException(), isNull);
    });

    // The panel speaks to someone signing in to LibreDB, not to a developer choosing a starter project.
    testWidgets('describes LibreDB, not the template it grew from', (tester) async {
      setViewport(tester, const Size(1600, 1600));
      await pumpLogin(tester);

      expect(find.text('Your databases,\nin your pocket.'), findsOneWidget);
      expect(find.text('Organization sign-in'), findsOneWidget);
      expect(find.text('No passwords on the phone'), findsOneWidget);
      expect(find.text('Browse and query'), findsOneWidget);
      for (final templateText in ['Flutter 3.47.7', 'Core Layers', 'BLoC Ready', 'Clean Architecture', 'Platforms']) {
        expect(find.text(templateText), findsNothing, reason: templateText);
      }
    });
  });

  group('LoginScreen - Turkish', () {
    testWidgets('shows the single sign-on page and the brand panel in Turkish', (tester) async {
      setViewport(tester, const Size(1440, 900));
      await pumpLogin(tester, language: 'tr');

      for (final text in [
        'Tekrar hoş geldiniz',
        'Kurumsal hesabınızla giriş yapın.',
        'Veritabanlarınız\ncebinizde.',
        "LibreDB Studio'nun size açtığı veritabanlarına telefonunuzdan ulaşın.",
        'Kurum hesabıyla giriş',
        'Telefonda parola yok',
        'Göz atın ve sorgulayın',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byTooltip('Koyu temaya geç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('single sign-on', () {
    final ssoButton = find.byKey(loginButtonSsoKey);

    Future<void> pumpOidcApp(WidgetTester tester, AppDependencies dependencies, {String language = 'en'}) async {
      setViewport(tester, const Size(1600, 1600));
      await tester.pumpWidget(App(language: language, dependencies: dependencies));
      await tester.pumpAndSettle();
    }

    GoRouter routerFromApp(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

    String location(WidgetTester tester) => routerFromApp(tester).state.uri.toString();

    SsoAutoRedirectGate gate(WidgetTester tester) =>
        tester.element(find.byType(MaterialApp)).read<SsoAutoRedirectGate>();

    // Signs out as the user does: Logout in the user menu, then Yes in the confirmation dialog.
    Future<void> logOut(WidgetTester tester) async {
      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
    }

    // Waits until the snack bar that repeats the error has gone, so only the line on the page is left.
    Future<void> waitForSnackBarToGo(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('shows only the single sign-on button', (tester) async {
      await pumpOidcApp(tester, _OidcDependencies(_ScriptedOidcClient()));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in with SSO'), findsOneWidget);
      expect(find.text('Sign in with your organization account.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'no password or code field');
      expect(find.byType(CommunitySectionWidget), findsOneWidget);
    });

    for (final (rejection, outcome, message) in [
      ('an unreachable provider', const OidcSignInFailed(OidcFailure.discovery), _discoveryMessage),
      ('an error answer', const OidcSignInFailed(OidcFailure.failed), _failedMessage),
      (
        'an ID token with no subject',
        OidcSignedIn(tokens: _signedIn.tokens, claims: const {'iss': 'https://id.example.com/realms/demo'}),
        _failedMessage,
      ),
    ]) {
      testWidgets('says why for $rejection and keeps the button', (tester) async {
        final client = _ScriptedOidcClient(outcomes: [outcome]);
        await pumpOidcApp(tester, _OidcDependencies(client));

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();
        await waitForSnackBarToGo(tester);

        expect(client.signIns, 1);
        expect(find.text(message), findsOneWidget);
        expect(tester.widget<FilledButton>(ssoButton).onPressed, isNotNull);
        expect(location(tester), ApplicationRoutesConstants.login);
      });
    }

    // Only Studio decides whether the account may use the app: GET /api/auth/me answers after the provider sign-in.
    for (final (refusal, error, message) in [
      ('a 401 without a code', const AuthError('Unauthorized'), _refusedMessage),
      ('a 403 BEARER_NO_ROLE', AuthError('refused', code: AppErrorCode.studioAccountHasNoRole.key), _noRoleMessage),
      (
        'a certificate that matches no pin',
        NetworkError('blocked', code: AppErrorCode.networkCertInvalid.key),
        _insecureConnectionMessage,
      ),
    ]) {
      testWidgets('says why Studio refused the account for $refusal, stores nothing and keeps the button', (
        tester,
      ) async {
        final client = _ScriptedOidcClient();
        await pumpOidcApp(tester, _OidcDependencies(client, studio: _RefusingStudio(error)));

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();
        await waitForSnackBarToGo(tester);

        expect(client.signIns, 1);
        expect(find.text(message), findsOneWidget);
        expect(tester.widget<FilledButton>(ssoButton).onPressed, isNotNull);
        expect(location(tester), ApplicationRoutesConstants.login);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), isNull);
      });
    }

    // A startup step that throws signs the user out with authOidcFailed, which the router hands to the page.
    testWidgets('shows a startup sign-in error until the first tap, and nothing while the sign-in runs', (
      tester,
    ) async {
      await _storeExpiredSession();
      final answer = Completer<OidcSignInOutcome>();
      final client = _ScriptedOidcClient(outcomes: [answer.future]);
      await pumpOidcApp(tester, _OidcDependencies(client, rotation: _ThrowingRotation()));
      expect(find.text(_failedMessage), findsOneWidget);

      await tester.tap(ssoButton);
      // The spinner runs until the provider answers, so the frames are pumped one by one.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.descendant(of: ssoButton, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.text(_failedMessage), findsNothing);

      answer.complete(const OidcSignInCancelled());
      await tester.pumpAndSettle();

      expect(find.text(_failedMessage), findsNothing);
      expect(tester.widget<FilledButton>(ssoButton).onPressed, isNotNull);
    });

    testWidgets('a misconfigured build says so and shows no button', (tester) async {
      await pumpOidcApp(
        tester,
        const AppDependencies(
          appConfig: AppConfig.test(),
          authMode: OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
        ),
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_configMessage), findsOneWidget);
      expect(ssoButton, findsNothing);
      expect(find.byType(TextField), findsNothing, reason: 'no password sign-in to fall back to');
    });

    testWidgets('shows the button in Turkish', (tester) async {
      await pumpOidcApp(tester, _OidcDependencies(_ScriptedOidcClient()), language: 'tr');

      expect(find.widgetWithText(FilledButton, 'SSO ile giriş yap'), findsOneWidget);
      expect(find.text('Kurumsal hesabınızla giriş yapın.'), findsOneWidget);
    });

    testWidgets('a tap signs in and opens the connection list', (tester) async {
      final client = _ScriptedOidcClient();
      await pumpOidcApp(tester, _OidcDependencies(client));

      await tester.tap(ssoButton);
      await tester.pumpAndSettle();

      expect(client.signIns, 1);
      expect(find.byType(ResponsiveScaffold), findsOneWidget);
      expect(location(tester), ApplicationRoutesConstants.home);
    });

    testWidgets('a safe returnUrl is where the sign-in lands', (tester) async {
      await pumpOidcApp(tester, _OidcDependencies(_ScriptedOidcClient()));
      routerFromApp(tester).go('${ApplicationRoutesConstants.login}?returnUrl=%2Fsettings');
      await tester.pumpAndSettle();

      await tester.tap(ssoButton);
      await tester.pumpAndSettle();

      expect(location(tester), ApplicationRoutesConstants.settings);
    });

    testWidgets('a returnUrl of /login or with a control character lands on /', (tester) async {
      await pumpOidcApp(tester, _OidcDependencies(_ScriptedOidcClient()));

      for (final returnUrl in ['%2Flogin', '%2Fsettings%07']) {
        routerFromApp(tester).go('${ApplicationRoutesConstants.login}?returnUrl=$returnUrl');
        await tester.pumpAndSettle();
        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(location(tester), ApplicationRoutesConstants.home, reason: returnUrl);
        await logOut(tester);
      }
    });

    group('automatic redirect', () {
      testWidgets('signs in once on a cold start', (tester) async {
        final client = _ScriptedOidcClient();
        await pumpOidcApp(tester, _OidcDependencies(client, autoRedirect: true));

        expect(client.signIns, 1);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
        expect(gate(tester).isOpen, isFalse);
      });

      testWidgets('does not run after a startup sign-in error', (tester) async {
        await _storeExpiredSession();
        final client = _ScriptedOidcClient();
        await pumpOidcApp(tester, _OidcDependencies(client, autoRedirect: true, rotation: _ThrowingRotation()));

        expect(client.signIns, 0);
        expect(find.text(_failedMessage), findsOneWidget);
      });

      testWidgets('does not run when it is turned off', (tester) async {
        final client = _ScriptedOidcClient();
        await pumpOidcApp(tester, _OidcDependencies(client));

        expect(client.signIns, 0);
        expect(ssoButton, findsOneWidget);
      });

      testWidgets('does not run when the login page shows again after a logout', (tester) async {
        final client = _ScriptedOidcClient();
        await pumpOidcApp(tester, _OidcDependencies(client, autoRedirect: true));
        expect(find.byType(ResponsiveScaffold), findsOneWidget);

        await logOut(tester);

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(client.signIns, 1);
      });

      testWidgets('after a cancel, keeps the gate closed and the button signs in again', (tester) async {
        final client = _ScriptedOidcClient(outcomes: [const OidcSignInCancelled()]);
        await pumpOidcApp(tester, _OidcDependencies(client, autoRedirect: true));
        expect(client.signIns, 1);
        expect(gate(tester).isOpen, isFalse);
        expect(tester.widget<FilledButton>(ssoButton).onPressed, isNotNull);

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(client.signIns, 2);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
      });

      testWidgets('after an error, keeps the gate closed and the error on the page', (tester) async {
        final client = _ScriptedOidcClient(outcomes: [const OidcSignInFailed(OidcFailure.discovery)]);
        await pumpOidcApp(tester, _OidcDependencies(client, autoRedirect: true));
        await waitForSnackBarToGo(tester);

        expect(client.signIns, 1);
        expect(gate(tester).isOpen, isFalse);
        expect(find.text(_discoveryMessage), findsOneWidget);
      });
    });
  });
}
