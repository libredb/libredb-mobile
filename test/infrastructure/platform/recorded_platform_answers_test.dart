import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/platform_connections/data/models/platform_connections_model.dart';
import 'package:libredb_mobile/features/platform_connections/data/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_target.dart';
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
/// The success and write answers were recorded the same day from the same image with the free localhost dev license
/// (one admin seat, three user seats), from a fresh volume, as `admin` unless named otherwise, after `me.json`, so
/// `admin` held the admin seat; `me_admin_seats.json` is `admin2`'s. The two connections were created by hand in
/// Platform's web console (docs/studio.md, "Success and write answers"); every grant made for the recording was
/// revoked. `directory.json`, `directory_query.json` and `grant_put.json` are read by the directory and grant `PUT`
/// readers of #250 once they merge.
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
    ('me_admin_seats', 403, 'LICENSE_ADMIN_SEATS', AppErrorCode.platformLicenseAdminSeats, false, true),
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

  group('success answers, read by the production repositories', () {
    test('GET /api/v1/me me: the admin holding the admin seat', () async {
      adapter.answer(200, fixture('me'));

      final identity = (await PlatformIdentityRepository(client).fetch()).dataOrNull!;

      expect(adapter.requests, ['GET /v1/me']);
      expect(identity.id, isNotEmpty);
      expect(identity.email, 'admin@example.com');
      expect(identity.name, 'Demo Admin');
      expect(identity.roles, ['PLATFORM_ADMIN']);
      expect(identity.permissions, containsAll(['connection.view', 'user.view', 'audit.view']));
      expect(identity.tenant.slug, 'default');
      expect(identity.tenant.name, 'LibreDB Mobile dev');
    });

    test('GET /api/v1/connections connections: both connections, newest first', () async {
      adapter.answer(200, fixture('connections'));

      final connections = (await PlatformConnectionRepository(client).list()).dataOrNull!;

      expect(adapter.requests, ['GET /v1/connections']);
      expect(
        [for (final c in connections) (c.name, c.engine, c.status, c.hasWriteCredential)],
        [('Dev app (read-only)', 'postgres', 'active', false), ('Dev app (write)', 'postgres', 'active', true)],
      );
    });

    test('GET /api/v1/connections/{id}/grants grants: the read grant of user', () async {
      adapter.answer(200, fixture('grants'));

      final grants = (await PlatformGrantRepository(client).list(_writeConnection)).dataOrNull!;

      expect(adapter.requests, ['GET /v1/connections/$_writeConnection/grants']);
      final grant = grants.single;
      expect(grant.subject, _user);
      expect(grant.subjectUsername, 'user');
      expect(grant.subjectEmail, 'user@example.com');
      expect(grant.level, 'read');
      expect(grant.expiresAt, isNull);
      expect(grant.grantedBy.name, 'Demo Admin');
      expect(grant.grantedBy.email, 'admin@example.com');
      expect(grant.grantedAt.isUtc, isTrue);
    });
  });

  group('refusals of the grant and directory routes', () {
    Future<AppError> failureOf(Future<Result<Object?>> Function() call) async {
      final result = await call();
      expect(result, isA<Failure<Object?>>());
      return (result as Failure<Object?>).error;
    }

    test('GET /api/v1/connections/unknown/grants grants_unknown_connection: 404 NOT_FOUND', () async {
      adapter.answer(404, fixture('grants_unknown_connection'));

      final error = await failureOf(() => PlatformGrantRepository(client).list('unknown'));

      expect(error.code, AppErrorCode.platformNotFound.key);
      expect(error.message, isNot(contains('Connection not found')));
      expect(sessionExpiredCalls, 0);
      expect(refusals, isEmpty);
    });

    test('DELETE /api/v1/connections/{id}/grants/unknown grant_delete_unknown: 404 NOT_FOUND', () async {
      adapter.answer(404, fixture('grant_delete_unknown'));

      final error = await failureOf(() => PlatformGrantRepository(client).revoke(_writeConnection, 'unknown'));

      expect(adapter.requests, ['DELETE /v1/connections/$_writeConnection/grants/unknown'], reason: 'sent once');
      expect(error.code, AppErrorCode.platformNotFound.key);
      expect(error.message, isNot(contains('Grant not found')));
    });

    for (final (name, status, fieldKeys, mapped) in [
      ('grant_put_level', 400, ['level'], AppErrorCode.platformGrantLevelRefused),
      ('grant_put_subject_unknown', 400, ['subject'], AppErrorCode.platformGrantSubjectRefused),
      ('grant_put_subject_disabled', 400, ['subject'], AppErrorCode.platformGrantSubjectRefused),
      ('grant_put_expiry', 400, ['expiresAt'], AppErrorCode.platformGrantExpiryRefused),
      // The strict schema names no field for an extra key: Platform sends the empty key.
      ('grant_put_body', 400, [''], AppErrorCode.platformValidationFailed),
      ('grant_put_user_seats', 403, <String>[], AppErrorCode.platformLicenseUserSeats),
    ]) {
      test('PUT /api/v1/connections/{id}/grants/{subject} $name: $status', () async {
        final body = fixture(name);
        final error = (jsonDecode(body) as Map)['error'] as Map;
        adapter.answer(status, body);

        final thrown = await _thrown(
          () => client.put('/v1/connections', const {'level': 'read', 'expiresAt': null}, pathParams: 'id/grants/s'),
        );

        expect(adapter.requests, ['PUT /v1/connections/id/grants/s'], reason: 'a PUT is never sent again');
        expect(thrown.statusCode, status);
        expect(thrown.errorCode, error['code']);
        expect(thrown is BadRequestException ? thrown.fieldErrorKeys : <String>[], fieldKeys);
        expect(platformGrantWriteError(thrown).code, mapped.key);
        for (final text in [error['message'], ...((error['fieldErrors'] as Map?)?.values.expand((v) => v) ?? [])]) {
          expect('$thrown', isNot(contains('$text')), reason: "Platform's text can name a user");
        }
        expect(platformAccountRefusal(answer(status, body)), isNull, reason: 'a grant refusal never locks the admin');
        expect(sessionExpiredCalls, 0);
        expect(refusals, isEmpty);
      });
    }

    for (final (name, query, status, mapped) in [
      ('directory_bad_page', {'page': 0}, 400, AppErrorCode.platformValidationFailed),
      ('directory_unavailable', {'q': 'zz'}, 503, AppErrorCode.platformDirectoryUnavailable),
    ]) {
      test('GET /api/v1/directory/users $name: $status', () async {
        adapter.answer(status, fixture(name));

        final thrown = await _thrown(() => client.get('/v1/directory/users', queryParams: query));

        expect(adapter.requests, ['GET /v1/directory/users'], reason: 'a coded 503 is sent once');
        expect(thrown.statusCode, status);
        expect(platformError(thrown).code, mapped.key);
        expect(sessionExpiredCalls, 0);
        expect(refusals, isEmpty);
      });
    }

    test('directory_bad_page names the field page', () async {
      adapter.answer(400, fixture('directory_bad_page'));

      final thrown = await _thrown(() => client.get('/v1/directory/users', queryParams: {'page': 0}));

      expect((thrown as BadRequestException).fieldErrorKeys, ['page']);
    });
  });

  // PATCH /api/v1/connections/{id} is M11-P's, which has no client method or reader yet; until then these hold the
  // recorded shape: the 200 is the connection as GET /api/v1/connections lists it.
  group('PATCH /api/v1/connections/{id}, recorded for M11-P', () {
    test('connection_patch: a no-op 200 answers the connection', () {
      final connection = PlatformConnectionsModel.read('{"connections":[${fixture('connection_patch')}]}').single;

      expect(
        (connection.name, connection.status, connection.hasWriteCredential),
        ('Dev app (read-only)', 'active', false),
      );
    });

    for (final (name, status, code, fieldKeys) in [
      ('connection_patch_body', 400, 'VALIDATION_FAILED', ['']),
      ('connection_patch_unknown', 404, 'NOT_FOUND', <String>[]),
    ]) {
      test('$name: $status $code', () {
        final body = fixture(name);

        expect(const PlatformErrorEnvelope().codeOf(body), code);
        expect(const PlatformErrorEnvelope().fieldErrorKeysOf(body), fieldKeys);
      });
    }
  });
}

const _writeConnection = '641ed0ff-6669-41eb-9976-557025a3eb80';
const _user = 'a0000000-0000-4000-8000-000000000002';

Future<AppException> _thrown(Future<Object?> Function() call) async {
  try {
    await call();
  } on AppException catch (error) {
    return error;
  }
  fail('the request did not throw');
}

/// Answers every request with one recorded status and body.
class _FixtureAdapter implements HttpClientAdapter {
  var _status = 500;
  var _body = '';

  /// Each request as `METHOD path`, in the order sent.
  final requests = <String>[];

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
    requests.add('${options.method} ${options.uri.path.replaceFirst('/api', '')}');
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
