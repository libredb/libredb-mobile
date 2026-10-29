import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/data/repositories/access_request_repository.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

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

const _request =
    '{"id":"r1","connection":{"id":"c1","name":"Sales reporting","engine":"postgres","status":"active"},'
    '"requester":{"subject":"kc-1","username":"jane.doe","email":"jane.doe@example.org"},'
    '"level":"read","reason":"I need the October order totals","status":"refused",'
    '"createdAt":"2026-10-29T08:00:00.000Z","decidedAt":"2026-10-29T09:00:00.000Z","decidedBy":null,'
    '"decisionReason":"Ask your team lead first","grantId":null}';

/// The production Platform chain, its adapter replaced by [adapter], with the stored token of a Studio session.
AccessRequestRepository _productionRepository(HttpClientAdapter adapter) {
  final client = PlatformApiClient(
    appConfig: _prodConfig,
    secureStorage: FlutterSecureStorageAdapter(),
    tokenRotation: const RefusingTokenRotation(),
  );
  client.instance.httpClientAdapter = adapter;
  return AccessRequestRepository(client);
}

/// Answers every request with [statusCode] and [body], or throws [error] when given, and records each request as
/// `METHOD uri` with the body it carried.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = '{"requests":[]}', this.error});

  final int statusCode;
  final String body;
  final DioExceptionType? error;
  final requests = <String>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final sent = requestStream == null ? <int>[] : await requestStream.expand((chunk) => chunk).toList();
    bodies.add(utf8.decode(sent));
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

String _envelope(String code, {List<String> fields = const []}) => jsonEncode({
  'error': {
    'code': code,
    'message': 'The Keycloak user jane.doe@example.org cannot do this',
    if (fields.isNotEmpty) 'fieldErrors': {for (final field in fields) field: 'refused'},
  },
});

void main() {
  setUp(TestEnv.authenticate);
  tearDown(ResilienceInterceptor.instance.resetAll);

  group('requestableConnections', () {
    test('reads the mock in its order, with and without access and a pending request', () async {
      final result = await AccessRequestRepository(TestEnv.platformApiClient()).requestableConnections();

      final connections = (result as Success<List<RequestableConnection>>).data;
      expect(connections, hasLength(3));
      expect(connections.where((connection) => connection.access == null), isNotEmpty);
      expect(connections.where((connection) => connection.access?.expiresAt != null), isNotEmpty);
      expect(connections.where((connection) => connection.pendingRequestId != null), isNotEmpty);
      expect(connections.where((connection) => !connection.hasWriteCredential), isNotEmpty);
    });

    test('sends GET /v1/requester/connections', () async {
      final adapter = _RecordingAdapter(body: '{"connections":[]}');

      await _productionRepository(adapter).requestableConnections();

      expect(adapter.requests, ['GET $_platformUrl/v1/requester/connections']);
    });
  });

  group('mine', () {
    test('reads the mock in its order, one request per known status', () async {
      final result = await AccessRequestRepository(TestEnv.platformApiClient()).mine();

      final requests = (result as Success<List<MyAccessRequest>>).data;
      expect(requests.map((request) => request.status), [
        AccessRequestStatus.pending,
        AccessRequestStatus.approved,
        AccessRequestStatus.refused,
        AccessRequestStatus.withdrawn,
      ]);
      expect(requests.where((request) => request.grantId != null), isNotEmpty);
      expect(requests.where((request) => request.decisionReason != null), isNotEmpty);
    });

    test('sends GET /v1/requester/access-requests', () async {
      final adapter = _RecordingAdapter();

      await _productionRepository(adapter).mine();

      expect(adapter.requests, ['GET $_platformUrl/v1/requester/access-requests']);
    });
  });

  group('create', () {
    test('sends POST /v1/requester/access-requests with exactly the three keys and a trimmed reason', () async {
      final adapter = _RecordingAdapter(statusCode: 201, body: '{"request":$_request}');

      final result = await _productionRepository(adapter)
          .create(connectionId: 'c1', level: 'read', reason: '  The October report  ');

      expect(result, isA<Success<MyAccessRequest>>());
      expect(adapter.requests, ['POST $_platformUrl/v1/requester/access-requests']);
      expect(adapter.bodies, ['{"connectionId":"c1","level":"read","reason":"The October report"}']);
    });

    test('reads the created request whatever the 2xx status the answer carries', () async {
      final adapter = _RecordingAdapter(statusCode: 200, body: '{"request":$_request}');

      final result = await _productionRepository(adapter).create(connectionId: 'c1', level: 'read', reason: 'why');

      expect((result as Success<MyAccessRequest>).data.id, 'r1');
    });

    test('succeeds through the mock, which answers 201', () async {
      final result = await AccessRequestRepository(TestEnv.platformApiClient())
          .create(connectionId: 'c1', level: 'read', reason: 'The October report');

      expect((result as Success<MyAccessRequest>).data.status, AccessRequestStatus.pending);
    });

    test('is sent once when Platform answers 503', () async {
      final adapter = _RecordingAdapter(statusCode: 503, body: '');

      final result = await _productionRepository(adapter).create(connectionId: 'c1', level: 'read', reason: 'why');

      expect(result, isA<Failure<MyAccessRequest>>());
      expect(adapter.requests, hasLength(1));
    });

    test('is sent once on a connection timeout', () async {
      final adapter = _RecordingAdapter(error: DioExceptionType.connectionTimeout);

      final result = await _productionRepository(adapter).create(connectionId: 'c1', level: 'read', reason: 'why');

      expect(result, isA<Failure<MyAccessRequest>>());
      expect(adapter.requests, hasLength(1));
    });

    for (final (field, expected) in [
      ('reason', AppErrorCode.platformAccessRequestReasonRefused),
      ('level', AppErrorCode.platformGrantLevelRefused),
    ]) {
      test('maps a 400 VALIDATION_FAILED on $field to its own code', () async {
        final result = await _stubbed(
          400,
          _envelope('VALIDATION_FAILED', fields: [field]),
        ).create(connectionId: 'c1', level: 'read', reason: 'why');

        expect((result as Failure<MyAccessRequest>).error.code, expected.key);
      });
    }

    test('maps a 400 VALIDATION_FAILED without a field key to platformValidationFailed', () async {
      final result = await _stubbed(
        400,
        _envelope('VALIDATION_FAILED'),
      ).create(connectionId: 'c1', level: 'read', reason: 'why');

      expect((result as Failure<MyAccessRequest>).error.code, AppErrorCode.platformValidationFailed.key);
    });
  });

  group('withdraw', () {
    test('sends POST /v1/requester/access-requests/<encoded id>/withdraw with an empty object', () async {
      final adapter = _RecordingAdapter(body: '{"request":$_request}');

      final result = await _productionRepository(adapter).withdraw('r/1 x');

      expect(result, isA<Success<MyAccessRequest>>());
      expect(adapter.requests, ['POST $_platformUrl/v1/requester/access-requests/r%2F1%20x/withdraw']);
      expect(adapter.bodies, ['{}']);
    });

    test('succeeds through the mock', () async {
      final result = await AccessRequestRepository(TestEnv.platformApiClient()).withdraw('r1');

      expect((result as Success<MyAccessRequest>).data.status, AccessRequestStatus.withdrawn);
    });

    test('is sent once when Platform answers 503', () async {
      final adapter = _RecordingAdapter(statusCode: 503, body: '');

      final result = await _productionRepository(adapter).withdraw('r1');

      expect(result, isA<Failure<MyAccessRequest>>());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('maps every refusal of the contract', () {
    final cases = <String, (int, String, AppErrorCode?, Type)>{
      '401 BEARER_INVALID': (401, _envelope('BEARER_INVALID'), AppErrorCode.authInvalidAccessToken, AuthError),
      '403 STUDIO_ROLE_REQUIRED': (
        403,
        _envelope('STUDIO_ROLE_REQUIRED'),
        AppErrorCode.platformStudioRoleRequired,
        AuthError,
      ),
      '404 API_DISABLED': (404, _envelope('API_DISABLED'), AppErrorCode.platformApiDisabled, NotFoundError),
      '404 ACCESS_REQUESTS_DISABLED': (
        404,
        _envelope('ACCESS_REQUESTS_DISABLED'),
        AppErrorCode.platformAccessRequestsDisabled,
        NotFoundError,
      ),
      '404 NOT_FOUND': (404, _envelope('NOT_FOUND'), AppErrorCode.platformNotFound, NotFoundError),
      '409 ACCESS_REQUEST_PENDING': (
        409,
        _envelope('ACCESS_REQUEST_PENDING'),
        AppErrorCode.platformAccessRequestPending,
        ValidationError,
      ),
      '409 ACCESS_ALREADY_GRANTED': (
        409,
        _envelope('ACCESS_ALREADY_GRANTED'),
        AppErrorCode.platformAccessAlreadyGranted,
        ValidationError,
      ),
      '409 ACCESS_REQUEST_LIMIT': (
        409,
        _envelope('ACCESS_REQUEST_LIMIT'),
        AppErrorCode.platformAccessRequestLimit,
        ValidationError,
      ),
      '409 ACCESS_REQUEST_DECIDED': (
        409,
        _envelope('ACCESS_REQUEST_DECIDED'),
        AppErrorCode.platformAccessRequestDecided,
        ValidationError,
      ),
      '503 IDENTITY_PROVIDER_UNAVAILABLE': (
        503,
        _envelope('IDENTITY_PROVIDER_UNAVAILABLE'),
        AppErrorCode.platformIdentityProviderUnavailable,
        ServerError,
      ),
      '500 INTERNAL_ERROR': (500, _envelope('INTERNAL_ERROR'), AppErrorCode.platformInternalError, ServerError),
      'an unreadable body': (200, '{"requests":[{"id":"r1"}]}', AppErrorCode.platformUnreadableAnswer, ServerError),
    };

    for (final MapEntry(key: name, value: (status, body, code, type)) in cases.entries) {
      test('for mine: $name', () async {
        final result = await _stubbed(status, body).mine();

        final error = (result as Failure<List<MyAccessRequest>>).error;
        expect(error.runtimeType, type);
        expect(error.code, code?.key);
      });

      if (status != 200) {
        test('for requestableConnections: $name', () async {
          final result = await _stubbed(status, body).requestableConnections();

          final error = (result as Failure<List<RequestableConnection>>).error;
          expect(error.runtimeType, type);
          expect(error.code, code?.key);
        });

        test('for create: $name', () async {
          final result = await _stubbed(status, body).create(connectionId: 'c1', level: 'read', reason: 'why');

          final error = (result as Failure<MyAccessRequest>).error;
          expect(error.runtimeType, type);
          expect(error.code, code?.key);
        });

        test('for withdraw: $name', () async {
          final result = await _stubbed(status, body).withdraw('r1');

          final error = (result as Failure<MyAccessRequest>).error;
          expect(error.runtimeType, type);
          expect(error.code, code?.key);
        });
      }
    }
  });

  group('in a build without a Platform target', () {
    AccessRequestRepository notConfigured() => AccessRequestRepository(
      PlatformApiClient(
        appConfig: const AppConfig(
          environment: Environment.prod,
          apiBaseUrl: 'https://studio.example.test/api',
          certificatePins: [],
          idleTimeout: null,
          platform: PlatformNotConfigured(),
        ),
        secureStorage: FlutterSecureStorageAdapter(),
        tokenRotation: const RefusingTokenRotation(),
      ),
    );

    test('answers platformNotConfigured for every method and sends nothing', () async {
      final repository = notConfigured();

      for (final result in [
        await repository.requestableConnections(),
        await repository.mine(),
        await repository.create(connectionId: 'c1', level: 'read', reason: 'why'),
        await repository.withdraw('r1'),
      ]) {
        expect(result, isA<Failure<Object?>>(), reason: '$result');
        expect((result as Failure<Object?>).error.code, AppErrorCode.platformNotConfigured.key);
      }
    });
  });

  test('logs no reason, decision reason, username, e-mail address or connection name', () async {
    final lines = await printedLines(() async {
      expect(await _stubbed(200, '{"requests":[$_request]}').mine(), isA<Success<List<MyAccessRequest>>>());
      expect(
        await _stubbed(
          200,
          '{"connections":[{"id":"c1","name":"Sales reporting","engine":"postgres","hasWriteCredential":true,'
          '"access":null,"pendingRequestId":null}]}',
        ).requestableConnections(),
        isA<Success<List<RequestableConnection>>>(),
      );
      expect(
        await _stubbed(
          201,
          '{"request":$_request}',
        ).create(connectionId: 'c1', level: 'read', reason: 'I need the October order totals'),
        isA<Success<MyAccessRequest>>(),
      );
      expect(await _stubbed(200, '{"request":$_request}').withdraw('r1'), isA<Success<MyAccessRequest>>());
      expect(
        await _stubbed(
          409,
          _envelope('ACCESS_REQUEST_PENDING'),
        ).create(connectionId: 'c1', level: 'read', reason: 'I need the October order totals'),
        isA<Failure<MyAccessRequest>>(),
      );
      expect(await _stubbed(404, _envelope('NOT_FOUND')).withdraw('r1'), isA<Failure<MyAccessRequest>>());
    });

    expect(lines, isNotEmpty);
    for (final secret in [
      'October order totals',
      'Ask your team lead',
      'jane.doe',
      'Sales reporting',
      'cannot do this',
    ]) {
      expect(lines.where((line) => line.contains(secret)), isEmpty, reason: secret);
    }
  });
}

/// The repository on the mock-backed client, with every request answered by [statusCode] and [body].
AccessRequestRepository _stubbed(int statusCode, String body) {
  final dio = Dio()..interceptors.add(_StubInterceptor(statusCode, body));
  return AccessRequestRepository(TestEnv.platformApiClient(dio: dio));
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
