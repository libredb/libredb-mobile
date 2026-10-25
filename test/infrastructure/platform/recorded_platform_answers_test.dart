import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_session_policy.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

/// Reads answers recorded from a real LibreDB Platform, so the Platform readers are held to what Platform sends rather
/// than to the hand-written answers in assets/mock.
///
/// Recorded on 2026-10-25 from the platform profile of tool/studio-dev, image
/// `ghcr.io/libredb/libredb-platform:1.3.0@sha256:e53ca9b82e337bb995a575ac4082de3da092d33c098a020a13292584fbc49ea9`,
/// with the placeholder license (no seat can be added), from a fresh volume, as raw bodies of `GET /api/v1/me`:
/// `me_no_token.json` without a token; `me_not_admin.json` with a libredb-mobile access token of `user`,
/// `me_norole.json` of `norole` (no `libredb_roles` claim), `me_license_invalid.json` of `admin`, and `me_expired.json`
/// of `admin` 95 seconds after it was issued; `me_api_disabled.json` from Platform recreated with
/// `PLATFORM_API_AUDIENCE` empty; `me_idp_unavailable.json` from Platform restarted while Keycloak was stopped, with an
/// `admin` token fetched before the stop. docs/studio.md ("Platform answers") has the command behind each one.
///
/// Each body is answered to a [PlatformApiClient], so it goes through the client's envelope reader and exception path,
/// then through [platformError]; the session predicates read a [DioException] built from the status and the raw body.
void main() {
  String fixture(String name) => File('test/fixtures/platform/$name.json').readAsStringSync();

  DioException answer(int status, String body) {
    final request = RequestOptions(path: '/v1/me');
    return DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: status, data: body),
    );
  }

  late _FixtureAdapter adapter;
  late PlatformApiClient client;
  late int sessionExpiredCalls;
  late List<AppErrorCode> refusals;

  setUp(() async {
    sessionExpiredCalls = 0;
    refusals = [];
    client = PlatformApiClient(
      appConfig: const AppConfig(
        environment: Environment.prod,
        apiBaseUrl: 'https://localhost:9443/api',
        certificatePins: [],
        idleTimeout: null,
        platform: PlatformConfigured(baseUrl: 'https://localhost:9445/api'),
      ),
      secureStorage: FlutterSecureStorageAdapter(),
      tokenRotation: const _RotatingTokens(),
      onSessionExpired: () => sessionExpiredCalls++,
      onAccountRefused: refusals.add,
    );
    adapter = _FixtureAdapter();
    client.instance.httpClientAdapter = adapter;
    TestEnv.authenticate();
    await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'REFRESH_TOKEN');
  });

  tearDown(ResilienceInterceptor.instance.resetAll);

  /// The exception the client throws when Platform answers every request with [status] and [body].
  Future<AppException> thrownFor(int status, String body) async {
    adapter.answer(status, body);
    try {
      await client.get('/v1/me');
    } on AppException catch (error) {
      return error;
    }
    fail('GET /v1/me did not throw');
  }

  for (final (name, status, code, mapped, sessionEnds, refusal) in [
    ('me_no_token', 401, 'BEARER_INVALID', AppErrorCode.authInvalidAccessToken, true, false),
    ('me_expired', 401, 'BEARER_INVALID', AppErrorCode.authInvalidAccessToken, true, false),
    ('me_not_admin', 403, 'ADMIN_ROLE_REQUIRED', AppErrorCode.platformAdminRoleRequired, false, true),
    ('me_norole', 403, 'ADMIN_ROLE_REQUIRED', AppErrorCode.platformAdminRoleRequired, false, true),
    ('me_license_invalid', 403, 'LICENSE_INVALID', AppErrorCode.platformLicenseInvalid, false, false),
    ('me_api_disabled', 404, 'API_DISABLED', AppErrorCode.platformApiDisabled, false, false),
    (
      'me_idp_unavailable',
      503,
      'IDENTITY_PROVIDER_UNAVAILABLE',
      AppErrorCode.platformIdentityProviderUnavailable,
      false,
      false,
    ),
  ]) {
    test('GET /api/v1/me $name: $status $code', () async {
      final body = fixture(name);
      final message = ((jsonDecode(body) as Map)['error'] as Map)['message'] as String;

      final thrown = await thrownFor(status, body);

      expect(thrown.statusCode, status);
      expect(thrown.errorCode, code);
      expect(platformError(thrown).code, mapped.key);
      expect('$thrown', isNot(contains(message)), reason: "Platform's message never reaches an exception");
      expect(platformError(thrown).message, isNot(contains(message)));

      expect(isPlatformSessionExpired(answer(status, body)), sessionEnds);
      expect(isPlatformSessionRefused(answer(status, body)), sessionEnds);
      expect(platformAccountRefusal(answer(status, body)), refusal ? mapped : isNull);
      expect(sessionExpiredCalls, sessionEnds ? 1 : 0, reason: 'only a BEARER_INVALID after the refresh ends it');
      expect(refusals, refusal ? [mapped] : isEmpty, reason: 'only an account refusal opens the refusal page');
    });
  }
}

/// Answers every request with one recorded status and body.
class _FixtureAdapter implements HttpClientAdapter {
  var _status = 500;
  var _body = '';

  void answer(int status, String body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      _body,
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A refresh that always succeeds, so a BEARER_INVALID is sent once more with the new token.
class _RotatingTokens implements TokenRotation {
  const _RotatingTokens();

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async =>
      const TokensRotated(accessToken: 'NEW_JWT', refreshToken: 'NEW_REFRESH');
}
