import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_grant_repository.dart';
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

/// The production Platform chain, its adapter replaced by [adapter], so every interceptor sees the answer.
PlatformGrantRepository _productionRepository(HttpClientAdapter adapter) {
  final client = PlatformApiClient(
    appConfig: _prodConfig,
    secureStorage: FlutterSecureStorageAdapter(),
    tokenRotation: const RefusingTokenRotation(),
  );
  client.instance.httpClientAdapter = adapter;
  return PlatformGrantRepository(client);
}

/// Answers every request with [statusCode] and [body], or throws [error] when given, and records each request.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = '{"id":"g-1"}', this.error});

  final int statusCode;
  final String body;
  final DioExceptionType? error;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies.add(utf8.decode(await requestStream.expand((chunk) => chunk).toList()));
    }
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

String _envelope(String code, {Map<String, Object?>? fieldErrors}) => jsonEncode({
  'error': {'code': code, 'message': 'The Keycloak user alice is disabled', 'fieldErrors': ?fieldErrors},
});

void main() {
  setUp(() => TestEnv.authenticate(target: SessionTarget.platform));
  tearDown(ResilienceInterceptor.instance.resetAll);

  test('answers the grant id through the mock', () async {
    final result = await PlatformGrantRepository(TestEnv.platformApiClient())
        .put('c1', 'kc-1', level: 'read', expiresAt: null);

    expect(result, isA<Success<String>>().having((s) => s.data, 'id', isNotEmpty));
  });

  test('sends PUT with the subject as one encoded path segment', () async {
    final adapter = _RecordingAdapter();

    await _productionRepository(adapter).put('tenant/c 3', 'f:ldap-1:bob', level: 'read', expiresAt: null);

    expect(adapter.requests.single.method, 'PUT');
    expect(
      adapter.requests.single.uri.toString(),
      '$_platformUrl/v1/connections/tenant%2Fc%203/grants/f%3Aldap-1%3Abob',
    );
  });

  test('sends exactly level and expiresAt, the expiry in UTC ending in Z', () async {
    final adapter = _RecordingAdapter();

    await _productionRepository(adapter).put('c1', 'kc-1', level: 'write', expiresAt: DateTime.utc(2027, 5, 6, 7, 8));

    final body = jsonDecode(adapter.bodies.single) as Map<String, dynamic>;
    expect(body, {'level': 'write', 'expiresAt': '2027-05-06T07:08:00.000Z'});
  });

  test('sends expiresAt as JSON null for a grant that does not expire', () async {
    final adapter = _RecordingAdapter();

    await _productionRepository(adapter).put('c1', 'kc-1', level: 'read', expiresAt: null);

    expect(adapter.bodies.single, '{"level":"read","expiresAt":null}');
  });

  test('is sent once when Platform answers 503', () async {
    final adapter = _RecordingAdapter(statusCode: 503, body: _envelope('DIRECTORY_UNAVAILABLE'));

    final result = await _productionRepository(adapter).put('c1', 'kc-1', level: 'read', expiresAt: null);

    expect(adapter.requests, hasLength(1));
    expect(
      result,
      isA<Failure<String>>().having((f) => f.error.code, 'code', AppErrorCode.platformDirectoryUnavailable.key),
    );
  });

  test('is sent once on a receive timeout', () async {
    final adapter = _RecordingAdapter(error: DioExceptionType.receiveTimeout);

    final result = await _productionRepository(adapter).put('c1', 'kc-1', level: 'read', expiresAt: null);

    expect(adapter.requests, hasLength(1));
    expect(result, isA<Failure<String>>().having((f) => f.error, 'error', isA<TimeoutError>()));
  });

  for (final code in ['LICENSE_USER_SEATS', 'LICENSE_EXPIRED', 'LICENSE_INVALID']) {
    test('a 403 $code is the caller\'s to show and never refuses the signed-in admin', () async {
      final refusals = <AppErrorCode>[];
      final client = PlatformApiClient(
        appConfig: _prodConfig,
        secureStorage: FlutterSecureStorageAdapter(),
        tokenRotation: const RefusingTokenRotation(),
        onAccountRefused: refusals.add,
      );
      client.instance.httpClientAdapter = _RecordingAdapter(statusCode: 403, body: _envelope(code));

      final result = await PlatformGrantRepository(client).put('c1', 'kc-1', level: 'read', expiresAt: null);

      expect(result, isA<Failure<String>>().having((f) => f.error.code, 'code', startsWith('platform.license_')));
      expect(refusals, isEmpty);
    });
  }

  test('a 403 ADMIN_ROLE_REQUIRED on the PUT refuses the signed-in admin, as a control', () async {
    final refusals = <AppErrorCode>[];
    final client = PlatformApiClient(
      appConfig: _prodConfig,
      secureStorage: FlutterSecureStorageAdapter(),
      tokenRotation: const RefusingTokenRotation(),
      onAccountRefused: refusals.add,
    );
    client.instance.httpClientAdapter = _RecordingAdapter(statusCode: 403, body: _envelope('ADMIN_ROLE_REQUIRED'));

    await PlatformGrantRepository(client).put('c1', 'kc-1', level: 'read', expiresAt: null);

    expect(refusals, [AppErrorCode.platformAdminRoleRequired]);
  });

  group('maps a refusal through platformGrantWriteError', () {
    final cases = <String, (int, String, AppErrorCode)>{
      '400 on level': (
        400,
        _envelope('VALIDATION_FAILED', fieldErrors: {'level': 'no write credential'}),
        AppErrorCode.platformGrantLevelRefused,
      ),
      '400 on subject': (
        400,
        _envelope('VALIDATION_FAILED', fieldErrors: {'subject': 'disabled'}),
        AppErrorCode.platformGrantSubjectRefused,
      ),
      '400 on expiresAt': (
        400,
        _envelope('VALIDATION_FAILED', fieldErrors: {'expiresAt': 'past'}),
        AppErrorCode.platformGrantExpiryRefused,
      ),
      '400 on an extra key': (
        400,
        _envelope('VALIDATION_FAILED', fieldErrors: {'': 'unrecognized'}),
        AppErrorCode.platformValidationFailed,
      ),
      '404 NOT_FOUND': (404, _envelope('NOT_FOUND'), AppErrorCode.platformNotFound),
      '403 LICENSE_USER_SEATS': (403, _envelope('LICENSE_USER_SEATS'), AppErrorCode.platformLicenseUserSeats),
      '502 KEYCLOAK_PERMISSION_ERROR': (
        502,
        _envelope('KEYCLOAK_PERMISSION_ERROR'),
        AppErrorCode.platformKeycloakUnavailable,
      ),
      'an unreadable 200': (200, '{"grant":"g-1"}', AppErrorCode.platformUnreadableAnswer),
    };
    for (final MapEntry(key: name, value: (status, body, code)) in cases.entries) {
      test('for $name', () async {
        final result = await _productionRepository(_RecordingAdapter(statusCode: status, body: body))
            .put('c1', 'kc-1', level: 'read', expiresAt: null);

        expect(result, isA<Failure<String>>().having((f) => f.error.code, 'code', code.key));
      });
    }
  });

  // The HTTP layer prints the request path, which carries the encoded subject; the orchestrator tracks that line
  // apart from this feature, so this checks the repository's own lines.
  test('logs the mapped code only, never the subject or Platform message', () async {
    final lines = await printedLines(() async {
      await _productionRepository(_RecordingAdapter()).put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: null);
      await _productionRepository(
        _RecordingAdapter(statusCode: 400, body: _envelope('VALIDATION_FAILED', fieldErrors: {'subject': 'x'})),
      ).put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: null);
    });

    final repositoryLines = lines.where((line) => line.contains('PlatformGrantRepository')).toList();
    expect(repositoryLines, [
      contains('put: saved'),
      allOf(contains('[W]'), contains('put failed: platform.grant_subject_refused')),
    ]);
    expect(repositoryLines.where((line) => line.contains('alice')), isEmpty);
    expect(lines.where((line) => line.contains('disabled')), isEmpty);
  });
}
