import 'dart:convert';
import 'dart:io' show HttpServer, InternetAddress;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/auth_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/cache_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/connectivity_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/dev_console_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/idempotency_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/logging_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/mock_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/loopback_tls_server.dart';
import '../../support/pin_test_certificates.dart';
import '../../support/printed_lines.dart';
import '../../support/test_env.dart';

const _platformUrl = 'https://platform.example.test/api';

AppConfig _prodWith(PlatformTargetConfig platform) => AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: const [],
  idleTimeout: null,
  platform: platform,
);

/// Answers each request with the next queued status code and body, and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  final requests = <String>[];
  final bodies = <String>[];
  final _replies = <(int, String)>[];
  var _transportFailures = 0;

  void reply(int statusCode, [String body = '']) => _replies.add((statusCode, body));

  /// Fails the next request before any answer, as a dropped connection does.
  void failTransport() => _transportFailures++;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final sent = requestStream == null ? <int>[] : await requestStream.expand((chunk) => chunk).toList();
    bodies.add(utf8.decode(sent));
    requests.add('${options.method} ${options.uri} ${options.headers['Authorization']}');
    if (_transportFailures > 0) {
      _transportFailures--;
      throw DioException.connectionError(requestOptions: options, reason: 'connection reset');
    }
    if (_replies.isEmpty) throw StateError('No reply queued for ${options.method} ${options.path}');
    final (statusCode, body) = _replies.removeAt(0);
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

class _CountingRotation implements TokenRotation {
  var rotations = 0;

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async {
    rotations++;
    return const TokensRotated(accessToken: 'NEW_JWT', refreshToken: 'NEW_REFRESH');
  }
}

String _envelope(String code, {String message = 'The Keycloak user jane.doe@example.org is disabled'}) => jsonEncode({
  'error': {'code': code, 'message': message},
});

void main() {
  tearDown(ResilienceInterceptor.instance.resetAll);

  group('PlatformApiClient', () {
    late _CountingRotation rotation;
    late _FakeAdapter adapter;
    late PlatformApiClient client;
    late int sessionExpiredCalls;
    late List<AppErrorCode> refusals;

    setUp(() async {
      rotation = _CountingRotation();
      sessionExpiredCalls = 0;
      refusals = [];
      client = PlatformApiClient(
        appConfig: _prodWith(const PlatformConfigured(baseUrl: _platformUrl)),
        secureStorage: FlutterSecureStorageAdapter(),
        tokenRotation: rotation,
        onSessionExpired: () => sessionExpiredCalls++,
        onAccountRefused: refusals.add,
      );
      adapter = _FakeAdapter();
      client.instance.httpClientAdapter = adapter;
      TestEnv.authenticate();
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'REFRESH_TOKEN');
    });

    test("sends to Platform's base URL with the bearer, never to Studio's", () async {
      adapter.reply(200, '{}');

      await client.get('/v1/me');

      expect(adapter.requests, ['GET $_platformUrl/v1/me Bearer MOCK_TOKEN']);
    });

    test('builds the same interceptor chain as the Studio client, with the account refusal and without the mock', () {
      // Dio puts its own ImplyContentTypeInterceptor first.
      expect(client.instance.interceptors.map((i) => i.runtimeType).skip(1), [
        ConnectivityInterceptor,
        AuthInterceptor,
        TokenRefreshInterceptor,
        AccountRefusalInterceptor,
        IdempotencyInterceptor,
        ResilienceInterceptor,
        CacheInterceptor,
        DevConsoleInterceptor,
        LoggingInterceptor,
      ]);
      expect(client.instance.options.followRedirects, isFalse);
    });

    test('a 400 VALIDATION_FAILED keeps the code and the field keys and never the messages', () async {
      const message = 'The Keycloak user jane.doe@example.org is disabled';
      adapter.reply(
        400,
        jsonEncode({
          'error': {
            'code': 'VALIDATION_FAILED',
            'message': message,
            'fieldErrors': {
              'subject': [message],
            },
          },
        }),
      );

      Object? thrown;
      final lines = await printedLines(() async {
        try {
          await client.put('/v1/connections/c1/grants', {'level': 'read', 'expiresAt': null}, pathParams: 'jane');
        } on Object catch (error) {
          thrown = error;
        }
      });

      expect(
        thrown,
        isA<BadRequestException>()
            .having((e) => e.errorCode, 'errorCode', 'VALIDATION_FAILED')
            .having((e) => e.fieldErrorKeys, 'fieldErrorKeys', ['subject'])
            .having((e) => e.serverMessage, 'serverMessage', isNull),
      );
      expect('$thrown', isNot(contains('jane.doe')));
      expect('$thrown', contains('VALIDATION_FAILED'));
      expect(platformError(thrown!).message, isNot(contains('jane.doe')));
      expect(platformGrantWriteError(thrown!).code, AppErrorCode.platformGrantSubjectRefused.key);
      expect(lines, isNotEmpty);
      expect(lines, everyElement(isNot(contains('jane.doe'))));
      expect(lines, everyElement(isNot(contains('is disabled'))));
    });

    test('a 401 BEARER_INVALID refreshes once, and a second one after it ends the session', () async {
      adapter
        ..reply(401, _envelope('BEARER_INVALID'))
        ..reply(401, _envelope('BEARER_INVALID'));

      await expectLater(client.get('/v1/me'), throwsA(isA<UnauthorizedException>()));

      expect(rotation.rotations, 1);
      expect(sessionExpiredCalls, 1);
      expect(adapter.requests, ['GET $_platformUrl/v1/me Bearer MOCK_TOKEN', 'GET $_platformUrl/v1/me Bearer NEW_JWT']);
    });

    test('a 401 BEARER_INVALID that the refresh fixes keeps the session', () async {
      adapter
        ..reply(401, _envelope('BEARER_INVALID'))
        ..reply(200, '{}');

      final response = await client.get('/v1/me');

      expect(response.statusCode, 200);
      expect(rotation.rotations, 1);
      expect(sessionExpiredCalls, 0);
    });

    test('a 401 without the envelope starts no refresh, keeps the session and reaches the caller', () async {
      adapter.reply(401, 'Unauthorized');

      await expectLater(
        client.get('/v1/me'),
        throwsA(isA<UnauthorizedException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      expect(rotation.rotations, 0);
      expect(sessionExpiredCalls, 0);
      expect(adapter.requests, hasLength(1));
    });

    for (final (status, code) in [
      (503, 'IDENTITY_PROVIDER_UNAVAILABLE'),
      (503, 'DIRECTORY_UNAVAILABLE'),
      (502, 'KEYCLOAK_AUTH_ERROR'),
    ]) {
      test('a $status $code never ends the session and is sent once, not counted by its breaker', () async {
        adapter.reply(status, _envelope(code));

        await expectLater(
          client.get('/v1/directory/users', queryParams: {'q': 'jane'}),
          throwsA(isA<FetchDataException>().having((e) => e.errorCode, 'errorCode', code)),
        );

        expect(adapter.requests, hasLength(1), reason: 'a coded Platform answer is not retried');
        expect(ResilienceInterceptor.instance.circuitBreakers['/v1/directory/users']?.failureCount ?? 0, 0);
        expect(rotation.rotations, 0);
        expect(sessionExpiredCalls, 0);
      });
    }

    test(
      'a 403 ADMIN_ROLE_REQUIRED or LICENSE_ADMIN_SEATS reports the refusal, and LICENSE_EXPIRED does not',
      () async {
        adapter
          ..reply(403, _envelope('ADMIN_ROLE_REQUIRED'))
          ..reply(403, _envelope('LICENSE_ADMIN_SEATS'))
          ..reply(403, _envelope('LICENSE_EXPIRED'));

        for (var call = 0; call < 3; call++) {
          await expectLater(client.get('/v1/me'), throwsA(isA<UnauthorizedException>()));
        }

        expect(refusals, [AppErrorCode.platformAdminRoleRequired, AppErrorCode.platformLicenseAdminSeats]);
        expect(sessionExpiredCalls, 0);
      },
    );

    test('a /v1/ GET never reaches the cache store', () async {
      adapter
        ..reply(200, '{"id":"u1"}')
        ..reply(200, '{"id":"u1"}');

      await client.get('/v1/me');
      await client.get('/v1/connections');

      expect(await SharedPrefsCacheStorage().count(), 0);
    });

    test('a PUT and a DELETE answering 503 without a code are sent once', () async {
      adapter
        ..reply(503)
        ..reply(503);

      await expectLater(
        client.put('/v1/connections/c1/grants', const {}, pathParams: 'k'),
        throwsA(isA<AppException>()),
      );
      await expectLater(client.delete('/v1/connections/c1/grants', pathParams: 'g1'), throwsA(isA<AppException>()));

      expect(adapter.requests, hasLength(2));
    });

    test('a PATCH sends its JSON body to the path with the path params appended', () async {
      adapter.reply(200, '{}');

      await client.patch('/v1/connections', {'active': false}, pathParams: 'c%2F1');

      expect(adapter.requests, ['PATCH $_platformUrl/v1/connections/c%2F1 Bearer MOCK_TOKEN']);
      expect(adapter.bodies, ['{"active":false}']);
    });

    test('a PATCH answering 503 with a code, 503 without one, or a transport error is sent once', () async {
      adapter
        ..reply(503, _envelope('INTERNAL_ERROR'))
        ..reply(503);

      for (var call = 0; call < 2; call++) {
        await expectLater(
          client.patch('/v1/connections', const {'active': true}, pathParams: 'c1'),
          throwsA(isA<AppException>()),
        );
      }
      expect(adapter.requests, hasLength(2));

      adapter.failTransport();
      await expectLater(
        client.patch('/v1/connections', const {'active': true}, pathParams: 'c1'),
        throwsA(isA<AppException>()),
      );
      expect(adapter.requests, hasLength(3), reason: 'a PATCH is never retried');
    });
  });

  group('PlatformApiClient in a build without a Platform target', () {
    test('fails every call with PlatformNotConfiguredException and sends no request', () async {
      final client = PlatformApiClient(
        appConfig: _prodWith(const PlatformNotConfigured()),
        secureStorage: FlutterSecureStorageAdapter(),
        tokenRotation: const RefusingTokenRotation(),
      );
      TestEnv.authenticate();

      await expectLater(client.get('/v1/me'), throwsA(isA<PlatformNotConfiguredException>()));
      await expectLater(client.put('/v1/x', const {}), throwsA(isA<PlatformNotConfiguredException>()));
      await expectLater(client.delete('/v1/x'), throwsA(isA<PlatformNotConfiguredException>()));
      await expectLater(client.patch('/v1/x', const {}), throwsA(isA<PlatformNotConfiguredException>()));
      expect(() => client.instance, throwsA(isA<PlatformNotConfiguredException>()));
      expect(platformError(PlatformNotConfiguredException()).code, AppErrorCode.platformNotConfigured.key);
    });
  });

  group('PlatformApiClient transport', () {
    test("checks Platform's host against PLATFORM_CERT_PINS", () async {
      await withRealSockets(() async {
        final server = await startLoopbackTlsServer(body: '{"id":"u1"}');
        addTearDown(() => server.close(force: true));
        PlatformApiClient clientWith(List<String> pins) => PlatformApiClient(
          appConfig: _prodWith(
            PlatformConfigured(baseUrl: 'https://127.0.0.1:${server.port}/api', certificatePins: pins),
          ),
          secureStorage: FlutterSecureStorageAdapter(),
          tokenRotation: const RefusingTokenRotation(),
        );
        TestEnv.authenticate();

        final matching = clientWith([CertificatePinner.computePin(loopbackCertificateDer), rsaCertificatePin]);
        expect((await matching.get('/v1/me')).data, '{"id":"u1"}');

        await expectLater(
          clientWith([rsaCertificatePin, ecCertificatePin]).get('/v1/me'),
          throwsA(isA<UntrustedCertificateException>()),
        );
      });
    });

    for (final status in [302, 307]) {
      test('a $status to http is not followed', () async {
        await withRealSockets(() async {
          var plainRequests = 0;
          final plain = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => plain.close(force: true));
          plain.listen((request) {
            plainRequests++;
            request.response.close();
          });
          final platform = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, loopbackServerContext());
          addTearDown(() => platform.close(force: true));
          platform.listen((request) {
            request.response
              ..statusCode = status
              ..headers.set('location', 'http://127.0.0.1:${plain.port}/api/v1/me')
              ..close();
          });
          final client = PlatformApiClient(
            appConfig: _prodWith(PlatformConfigured(baseUrl: 'https://127.0.0.1:${platform.port}/api')),
            secureStorage: FlutterSecureStorageAdapter(),
            tokenRotation: const RefusingTokenRotation(),
          );
          client.instance.httpClientAdapter = loopbackTrustingAdapter();
          TestEnv.authenticate();

          await expectLater(
            client.get('/v1/me'),
            throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', status)),
          );
          expect(plainRequests, 0);
        });
      });
    }
  });

  group('PlatformApiClient against the mock', () {
    // A request without a stored token is not sent at all (#277), so the unauthenticated /v1/me carries an expired one.
    test('answers an unauthenticated /v1/me with 401 BEARER_INVALID in the envelope', () async {
      await FlutterSecureStorageAdapter().write(SecureStorageKeys.jwtToken.key, _expiredJwt());
      final client = TestEnv.platformApiClient();

      await expectLater(
        client.get('/v1/me'),
        throwsA(
          isA<UnauthorizedException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.errorCode, 'errorCode', 'BEARER_INVALID'),
        ),
      );
    });

    test('builds the chain with the mock last', () {
      expect(TestEnv.platformApiClient().instance.interceptors.last, isA<MockInterceptor>());
    });
  });
}

/// A JWT signed nowhere whose `exp` has passed, which MockInterceptor answers with 401 as an expired bearer.
String _expiredJwt() {
  String part(Map<String, Object> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'RS256', 'typ': 'JWT'})}.${part({'sub': 'admin', 'exp': exp})}.c2lnbmF0dXJl';
}
