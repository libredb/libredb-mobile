/// The doubles the login screen's tests sign in through, and the viewports they pump at.
///
/// Extracted from `login_screen_test.dart` because it is no longer the only file that needs them: the accessibility
/// tests and the onboarding tests pump the same dependency graph. A copy would drift, and the drift would be
/// invisible — two files asserting against two different identity providers both pass.
///
/// [kPhoneViewport] is the default the login tests pump at, because the app ships on phones. It is the
/// `kGoldenScreenSize` of `test/support/golden_app.dart`, so a widget test and a golden see the same surface.
/// [kTabletViewport] is passed explicitly, and only by a test that is about the wide layout.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/platform_status/domain/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// The surface the app ships on, and what every login test pumps at unless it says otherwise.
const Size kPhoneViewport = Size(390, 844);

/// A wide surface, for the tests that are about `_desktopLayout`. It is past the 1024 breakpoint
/// (`AppBreakpoints.tablet`), where `login_page.dart` forks.
const Size kTabletViewport = Size(1024, 1366);

/// Sizes the surface [tester] pumps on, and puts it back afterwards.
void setViewport(WidgetTester tester, Size size) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

/// A sign-in that the provider accepts.
final signedIn = OidcSignedIn(
  tokens: OidcTokens(
    accessToken: 'sso-access-token',
    idToken: 'sso-id-token',
    refreshToken: 'sso-refresh-token',
    accessTokenExpiresAt: DateTime.utc(2100),
  ),
  claims: const {'iss': 'https://id.example.com/realms/demo', 'sub': 'subject-1'},
);

/// The identity provider. Each sign-in answers with the next of [outcomes], and with [signedIn] once
/// they have run out.
class ScriptedOidcClient implements IOidcClient {
  ScriptedOidcClient({List<FutureOr<OidcSignInOutcome>>? outcomes}) : outcomes = outcomes ?? [];

  final List<FutureOr<OidcSignInOutcome>> outcomes;

  /// How many sign-ins were started.
  int signIns = 0;

  @override
  Future<OidcSignInOutcome> signIn() async {
    signIns++;
    return outcomes.isEmpty ? signedIn : await outcomes.removeAt(0);
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

/// The test config over [client]: the mocked Studio answers `GET /api/auth/me`, unless [studio] answers it, and the
/// mocked Platform answers `GET /api/v1/me` in a build with a [platform] target, unless [platformIdentity] answers it.
class OidcDependencies extends AppDependencies {
  OidcDependencies(
    this.client, {
    bool autoRedirect = false,
    this.rotation,
    this.studio,
    PlatformTargetConfig platform = const PlatformNotConfigured(),
    this.platformIdentity,
    this.studioStatus,
    this.platformStatus,
  }) : super(
         appConfig: AppConfig(
           environment: Environment.mock,
           apiBaseUrl: null,
           certificatePins: const <String>[],
           idleTimeout: null,
           platform: platform,
         ),
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

  /// Platform's answer to `GET /api/v1/me` in place of the mocked one, when given.
  final IPlatformIdentityRepository? platformIdentity;

  @override
  IPlatformIdentityRepository createPlatformIdentityRepository(PlatformApiClient apiClient) =>
      platformIdentity ?? super.createPlatformIdentityRepository(apiClient);

  /// Studio's liveness in place of the mocked one, when given.
  final IStudioStatusRepository? studioStatus;

  @override
  IStudioStatusRepository createStudioStatusRepository(ApiClient apiClient) =>
      studioStatus ?? super.createStudioStatusRepository(apiClient);

  /// Platform's liveness in place of the mocked one, when given.
  final IPlatformStatusRepository? platformStatus;

  @override
  IPlatformStatusRepository createPlatformStatusRepository(PlatformApiClient apiClient) =>
      platformStatus ?? super.createPlatformStatusRepository(apiClient);

  @override
  IOidcClient createOidcClient(OidcSettings settings) => client;

  @override
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) =>
      rotation ?? super.createOidcTokenRotation(client, secureStorage);
}

/// Studio's `GET /api/auth/me`, failing with [error].
class RefusingStudio implements IStudioIdentityRepository {
  RefusingStudio(this.error);

  final AppError error;

  @override
  Future<Result<StudioIdentity>> fetch({bool probe = false}) async => Failure(error);

  @override
  Future<Result<void>> recordSignOut() => throw UnimplementedError('these tests never sign out');
}

/// Platform's `GET /api/v1/me`, failing with [error]; [fetches] counts the calls.
class RefusingPlatform implements IPlatformIdentityRepository {
  RefusingPlatform(this.error);

  final AppError error;
  int fetches = 0;

  @override
  Future<Result<PlatformIdentity>> fetch() async {
    fetches++;
    return Failure(error);
  }
}

/// A liveness probe that answers [answer], which a test changes, and counts the checks in [checks].
class ScriptedLiveness implements IStudioStatusRepository, IPlatformStatusRepository {
  ScriptedLiveness({this.answer = const Success(null)});

  Result<void> answer;
  int checks = 0;

  @override
  Future<Result<void>> liveness() async {
    checks++;
    return answer;
  }

  @override
  Future<Result<StudioReadiness>> readiness() async => const Success(StudioReadinessReady());
}

/// A liveness answer that fails the way an offline device does.
const networkDown = Failure<void>(NetworkError('No Internet connection'));
const studioDownMessage = 'Studio does not answer.';
const platformDownMessage = 'Platform does not answer.';

/// A token refresh that fails with an error no rotation expects, so the startup step throws.
class ThrowingRotation implements TokenRotation {
  @override
  Future<TokenRotationResult> rotate(String refreshToken) async => throw StateError('rotation failed');
}

/// Stores a session whose access token has expired, so the startup step refreshes it.
Future<void> storeExpiredSession() async {
  final storage = FlutterSecureStorageAdapter();
  await storage.write(SecureStorageKeys.jwtToken.key, 'expired-access-token');
  await storage.write(SecureStorageKeys.refreshToken.key, 'stored-refresh-token');
  await storage.write(SecureStorageKeys.oidcIdToken.key, 'stored-id-token');
  await storage.write(SecureStorageKeys.accessTokenExpiresAt.key, encodeAccessTokenExpiry(DateTime.utc(2000)));
}
