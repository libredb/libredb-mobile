import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_session_startup.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// A connection list reload and a Studio sign-out at once (#277), over the production interceptor chain with only the
/// network, the identity provider and the startup refresh replaced: the stored session, its wipe, Studio's sign-out
/// record and the connection list are the app's own.
///
/// Seen on a phone: a reload that started while the sign-out cleared the session went out without a token, Studio
/// answered 401, and its refresh found no refresh token and ran the session expired callback for a session the user had
/// already ended.
void main() {
  late _StudioAdapter studio;
  late SsoSignOutAuthRepository signOut;
  late ConnectionListBloc list;
  late int sessionExpiredCalls;

  setUp(() async {
    ResilienceInterceptor.instance.resetAll();
    final secureStorage = FlutterSecureStorageAdapter();
    await secureStorage.write(SecureStorageKeys.sessionTarget.key, SessionTarget.studio.storedValue);
    await secureStorage.write(SecureStorageKeys.jwtToken.key, 'access-1');
    await secureStorage.write(SecureStorageKeys.refreshToken.key, 'refresh-1');
    await secureStorage.write(
      SecureStorageKeys.accessTokenExpiresAt.key,
      encodeAccessTokenExpiry(DateTime.now().add(const Duration(hours: 1))),
    );

    sessionExpiredCalls = 0;
    studio = _StudioAdapter();
    final client = ApiClient(
      appConfig: _prodConfig,
      secureStorage: secureStorage,
      tokenRotation: const RefusingTokenRotation(),
      onSessionExpired: () => sessionExpiredCalls++,
    );
    client.instance.httpClientAdapter = studio;

    signOut = SsoSignOutAuthRepository(
      inner: LoginRepository(sessionRepository: AuthSessionRepository(secureStorage: secureStorage)),
      client: const _NoProviderLogoutClient(),
      secureStorage: secureStorage,
      settings: OidcSettings(issuer: Uri.parse('https://id.example.test/realms/demo'), clientId: 'app'),
      studioIdentity: StudioIdentityRepository(client),
      sessionRefresh: const _StoredSessionStartup(),
    );
    list = ConnectionListBloc(
      listManagedConnectionsUseCase: ListManagedConnectionsUseCase(
        ConnectionRepository(client, ConnectionQueryTimeouts()),
      ),
    );
  });

  tearDown(() async {
    await list.close();
    ResilienceInterceptor.instance.resetAll();
  });

  test('a reload while the sign-out waits for Studio\'s record sends no request', () async {
    studio.holdLogout = Completer<void>();
    final signedOut = signOut.signOut();
    await studio.logoutArrived.future;

    final failed = list.stream.firstWhere(_settled);
    list.add(const ConnectionListRefreshed());
    final state = await failed;
    studio.holdLogout!.complete();
    final result = await signedOut;

    expect(result.cleared, isA<Success<void>>());
    expect(studio.requests, ['POST /auth/logout (bearer)']);
    expect(
      state,
      isA<ConnectionListFailure>().having((s) => s.errorCode, 'errorCode', AppErrorCode.authInvalidAccessToken),
    );
    expect(sessionExpiredCalls, 0);
  });

  test('a reload right after the sign-out wiped the session sends no request and ends no session again', () async {
    final result = await signOut.signOut();
    expect(result.cleared, isA<Success<void>>());

    final failed = list.stream.firstWhere(_settled);
    list.add(const ConnectionListRefreshed());
    final state = await failed;

    expect(sessionExpiredCalls, 0);
    expect(studio.requests, ['POST /auth/logout (bearer)']);
    expect(
      state,
      isA<ConnectionListFailure>().having((s) => s.errorCode, 'errorCode', AppErrorCode.authInvalidAccessToken),
    );
  });
}

/// Whether the list load ended, with a list or a failure.
bool _settled(ConnectionListState state) => state is ConnectionListLoaded || state is ConnectionListFailure;

const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
);

/// Studio as the phone met it: a request without a bearer gets 401 `AUTH_REQUIRED`, the sign-out record is accepted
/// (once [holdLogout] completes, when set), and the connection list answers one connection. Each request is noted in
/// [requests] with whether it carried a bearer.
class _StudioAdapter implements HttpClientAdapter {
  final requests = <String>[];
  final logoutArrived = Completer<void>();
  Completer<void>? holdLogout;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bearer = (options.headers['Authorization'] as String?)?.startsWith('Bearer ') ?? false;
    final path = options.uri.path.replaceFirst('/api', '');
    requests.add('${options.method} $path (${bearer ? 'bearer' : 'no bearer'})');
    if (!bearer) return _json(401, '{"error":"Authentication required","code":"AUTH_REQUIRED"}');
    if (path == '/auth/logout') {
      if (!logoutArrived.isCompleted) logoutArrived.complete();
      await holdLogout?.future;
      return _json(200, '{"success":true}');
    }
    if (path == '/connections/managed') {
      return _json(200, '{"connections":[{"id":"seed:sales-postgres","name":"Sales","type":"postgres"}]}');
    }
    return _json(404, '{"error":"Not found"}');
  }

  static ResponseBody _json(int status, String body) => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// A provider without an end-session endpoint: the sign-out ends with the local wipe.
class _NoProviderLogoutClient implements IOidcClient {
  const _NoProviderLogoutClient();

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) async => const NoProviderLogout();

  @override
  Future<OidcSignInOutcome> signIn() => throw UnimplementedError('a sign-out never signs in');

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('the startup refresh is replaced');
}

/// The startup refresh, which finds the stored access token still valid.
class _StoredSessionStartup implements ISsoSessionStartup {
  const _StoredSessionStartup();

  @override
  Future<SsoStartupResult> run() async => const SsoStartupUseStoredSession();

  @override
  void giveUp() {}
}
