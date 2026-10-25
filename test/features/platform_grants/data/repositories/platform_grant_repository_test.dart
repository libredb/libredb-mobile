import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

import '../../../../support/printed_lines.dart';
import '../../../../support/test_env.dart';

const _platformUrl = 'https://platform.example.test/api';

const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
  platform: PlatformConfigured(baseUrl: _platformUrl),
);

/// The production Platform chain, its adapter replaced by [adapter], with the stored token of a Platform session.
PlatformGrantRepository _productionRepository(HttpClientAdapter adapter) {
  final client = PlatformApiClient(
    appConfig: _prodConfig,
    secureStorage: FlutterSecureStorageAdapter(),
    tokenRotation: const RefusingTokenRotation(),
  );
  client.instance.httpClientAdapter = adapter;
  return PlatformGrantRepository(client);
}

/// Answers every request with [statusCode] and [body], or throws [error] when given, and records each request as
/// `METHOD uri`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = '{"grants":[]}', this.error});

  final int statusCode;
  final String body;
  final DioExceptionType? error;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri}');
    if (error != null) throw DioException(requestOptions: options, type: error!);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _envelope(String code) => jsonEncode({
  'error': {'code': code, 'message': 'The Keycloak user jane.doe@example.org cannot do this'},
});

void main() {
  setUp(() => TestEnv.authenticate(target: SessionTarget.platform));
  tearDown(ResilienceInterceptor.instance.resetAll);

  group('list', () {
    test('reads the mock in its order, with no expiry and absent e-mail and name read as null', () async {
      final result = await PlatformGrantRepository(TestEnv.platformApiClient()).list('c1');

      final grants = (result as Success<List<PlatformGrant>>).data;
      expect(grants.map((grant) => grant.subjectUsername), ['alice.reader', 'bob.writer', 'carol', 'dave', 'erin']);
      expect(grants.where((grant) => grant.expiresAt == null && grant.subjectEmail == null), isNotEmpty);
      expect(grants.where((grant) => grant.expiresAt != null && grant.subjectEmail != null), isNotEmpty);
      expect(grants.where((grant) => grant.level == 'write'), isNotEmpty);
      expect(grants.where((grant) => grant.grantedBy.name == null), isNotEmpty);
    });

    test('sends GET /v1/connections/<encoded id>/grants', () async {
      final adapter = _RecordingAdapter();

      await _productionRepository(adapter).list('tenant/c 3');

      expect(adapter.requests, ['GET $_platformUrl/v1/connections/tenant%2Fc%203/grants']);
    });
  });

  group('revoke', () {
    test('sends DELETE /v1/connections/<encoded id>/grants/<encoded grant id> and reads no body', () async {
      final adapter = _RecordingAdapter(statusCode: 204, body: '');

      final result = await _productionRepository(adapter).revoke('tenant/c 3', 'g/1 x');

      expect(result, isA<Success<void>>());
      expect(adapter.requests, ['DELETE $_platformUrl/v1/connections/tenant%2Fc%203/grants/g%2F1%20x']);
    });

    test('succeeds through the mock', () async {
      expect(await PlatformGrantRepository(TestEnv.platformApiClient()).revoke('c1', 'g1'), isA<Success<void>>());
    });

    test('is sent once when Platform answers 503', () async {
      final adapter = _RecordingAdapter(statusCode: 503, body: '');

      final result = await _productionRepository(adapter).revoke('c1', 'g1');

      expect(result, isA<Failure<void>>());
      expect(adapter.requests, hasLength(1));
    });

    test('is sent once on a connection timeout', () async {
      final adapter = _RecordingAdapter(error: DioExceptionType.connectionTimeout);

      final result = await _productionRepository(adapter).revoke('c1', 'g1');

      expect(result, isA<Failure<void>>());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('maps every error through platformError', () {
    final cases = <String, (int, String, AppErrorCode?, Type)>{
      '404 NOT_FOUND': (404, _envelope('NOT_FOUND'), AppErrorCode.platformNotFound, NotFoundError),
      '401 BEARER_INVALID': (401, _envelope('BEARER_INVALID'), AppErrorCode.authInvalidAccessToken, AuthError),
      '403 ADMIN_ROLE_REQUIRED': (
        403,
        _envelope('ADMIN_ROLE_REQUIRED'),
        AppErrorCode.platformAdminRoleRequired,
        AuthError,
      ),
      '503 IDENTITY_PROVIDER_UNAVAILABLE': (
        503,
        _envelope('IDENTITY_PROVIDER_UNAVAILABLE'),
        AppErrorCode.platformIdentityProviderUnavailable,
        ServerError,
      ),
      '500 INTERNAL_ERROR': (500, _envelope('INTERNAL_ERROR'), AppErrorCode.platformInternalError, ServerError),
      'an unreadable body': (200, '{"grants":[{"id":"g1"}]}', AppErrorCode.platformUnreadableAnswer, ServerError),
    };

    for (final MapEntry(key: name, value: (status, body, code, type)) in cases.entries) {
      test('for list: $name', () async {
        final result = await _stubbed(status, body).list('c1');

        expect(result, isA<Failure<List<PlatformGrant>>>());
        final error = (result as Failure<List<PlatformGrant>>).error;
        expect(error.runtimeType, type);
        expect(error.code, code?.key);
      });

      if (status != 200) {
        test('for revoke: $name', () async {
          final result = await _stubbed(status, body).revoke('c1', 'g1');

          expect(result, isA<Failure<void>>());
          final error = (result as Failure<void>).error;
          expect(error.runtimeType, type);
          expect(error.code, code?.key);
        });
      }
    }
  });

  test('logs no username, e-mail address, name or Platform message', () async {
    const body =
        '{"grants":[{"id":"g1","subject":"kc-1","subjectUsername":"jane.doe","subjectEmail":"jane.doe@example.org",'
        '"level":"read","expiresAt":null,"grantedBy":{"id":"u1","name":"Alice Admin","email":"alice@example.org"},'
        '"grantedAt":"2027-01-01T00:00:00.000Z"}]}';

    final lines = await printedLines(() async {
      expect(await _stubbed(200, body).list('c1'), isA<Success<List<PlatformGrant>>>());
      expect(await _stubbed(404, _envelope('NOT_FOUND')).list('c1'), isA<Failure<List<PlatformGrant>>>());
      expect(await _stubbed(404, _envelope('NOT_FOUND')).revoke('c1', 'g1'), isA<Failure<void>>());
    });

    expect(lines, isNotEmpty);
    for (final secret in ['jane.doe', 'alice', 'Alice Admin', 'cannot do this']) {
      expect(lines.where((line) => line.contains(secret)), isEmpty, reason: secret);
    }
  });
}

/// The repository on the mock-backed client, with every request answered by [statusCode] and [body].
PlatformGrantRepository _stubbed(int statusCode, String body) {
  final dio = Dio()..interceptors.add(_StubInterceptor(statusCode, body));
  return PlatformGrantRepository(TestEnv.platformApiClient(dio: dio));
}

class _StubInterceptor extends Interceptor {
  _StubInterceptor(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final response = Response<String>(requestOptions: options, statusCode: statusCode, data: body);
    if (statusCode >= 200 && statusCode < 300) {
      handler.resolve(response);
    } else {
      handler.reject(DioException(requestOptions: options, response: response, type: DioExceptionType.badResponse));
    }
  }
}
