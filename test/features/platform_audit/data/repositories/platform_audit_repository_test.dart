import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/data/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
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

const _emptyPage = '{"events":[],"total":0}';

/// One event whose every sensitive value names alice, so a log test can look for one word.
const _aliceEvent =
    '{"eventId":"7","startedAt":"2026-10-25T09:00:00Z","finishedAt":"2026-10-25T09:00:01Z","subject":"kc-alice",'
    '"username":"alice","sessionRole":"user","connectionId":"alice-conn","connectionKnown":true,'
    '"connectionName":"Alice DB","engine":"postgres","accessLevel":"read","source":"studio","statementType":"SELECT",'
    '"explain":null,"statementCapture":"full","statement":"SELECT alice_salary FROM payroll",'
    '"statementTruncated":false,"rowCount":1,"durationMs":3,"status":"error","errorCode":"42501",'
    '"errorMessage":"permission denied for alice_salary","transactionOutcome":null}';

/// Every filter set, each value naming alice.
final _aliceFilter = AuditFilter(
  subject: 'kc-alice',
  connectionId: 'alice-conn',
  source: 'alice-source',
  statementType: 'SELECT',
  status: 'error',
  from: DateTime.utc(2026, 10, 1),
  to: DateTime.utc(2026, 10, 25),
  search: 'alice_salary',
);

/// The production Platform chain, its adapter replaced by [adapter], so every interceptor sees the answer.
PlatformAuditRepository _productionRepository(HttpClientAdapter adapter) {
  final client = PlatformApiClient(
    appConfig: _prodConfig,
    secureStorage: FlutterSecureStorageAdapter(),
    tokenRotation: const RefusingTokenRotation(),
  );
  client.instance.httpClientAdapter = adapter;
  return PlatformAuditRepository(client);
}

/// Answers every request with an empty page, and records each request's uri.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      _emptyPage,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Answers every request with [statusCode] and [body] before the client's own chain, and records the requests; a
/// [statusCode] of 0 rejects it as a connection error, with no answer.
class _StubInterceptor extends Interceptor {
  _StubInterceptor(this.statusCode, [this.body = _emptyPage]);

  final int statusCode;
  final String body;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    if (statusCode == 0) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        ),
      );
      return;
    }
    final response = Response<String>(requestOptions: options, statusCode: statusCode, data: body);
    if (statusCode >= 200 && statusCode < 300) {
      handler.resolve(response);
    } else {
      handler.reject(DioException(requestOptions: options, response: response, type: DioExceptionType.badResponse));
    }
  }
}

String _envelope(String code, {Map<String, Object?>? fieldErrors}) => jsonEncode({
  'error': {'code': code, 'message': 'Invalid audit filters for kc-alice alice_salary', 'fieldErrors': ?fieldErrors},
});

PlatformAuditRepository _stubbed(_StubInterceptor stub) =>
    PlatformAuditRepository(TestEnv.platformApiClient(dio: Dio()..interceptors.add(stub)));

void main() {
  setUp(() => TestEnv.authenticate(target: SessionTarget.platform));
  tearDown(ResilienceInterceptor.instance.resetAll);

  test('reads the mock page: each status, a truncated statement, an unknown connection, a total above it', () async {
    final result = await PlatformAuditRepository(TestEnv.platformApiClient())
        .list(filter: const AuditFilter(), offset: 0);

    final page = (result as Success<AuditPage>).data;
    expect(page.events.length, greaterThanOrEqualTo(5));
    expect(page.total, greaterThan(page.events.length));
    expect(page.offset, 0);
    expect(page.hasMore, isTrue);
    expect(page.events.map((event) => event.status).toSet(), containsAll(['success', 'error', 'cancelled', 'refused']));
    expect(page.events.where((event) => event.statementCapture == 'none' && event.statement == null), isNotEmpty);
    expect(page.events.where((event) => event.statementTruncated), isNotEmpty);
    expect(
      page.events.where((event) => event.connectionKnown == false && event.connectionName == 'unknown connection'),
      isNotEmpty,
    );
  });

  test('sends GET /v1/audit with limit and offset only for no filter', () async {
    final stub = _StubInterceptor(200);

    await _stubbed(stub).list(filter: const AuditFilter(), offset: 0);

    expect(stub.requests.single.method, 'GET');
    expect(stub.requests.single.path, '/v1/audit');
    expect(stub.requests.single.queryParameters, {'limit': 50, 'offset': 0});
  });

  test('sends every set filter under its Platform name, the times in UTC', () async {
    final stub = _StubInterceptor(200);

    await _stubbed(stub).list(
      filter: AuditFilter(
        subject: ' kc-1 ',
        connectionId: 'c1',
        source: 'studio',
        statementType: 'DELETE',
        status: 'refused',
        from: DateTime.utc(2026, 10, 1, 6),
        to: DateTime.parse('2026-10-25T12:30:00+03:00'),
        search: 'orders',
      ),
      offset: 100,
      limit: 25,
    );

    expect(stub.requests.single.queryParameters, {
      'limit': 25,
      'offset': 100,
      'subject': 'kc-1',
      'connectionId': 'c1',
      'source': 'studio',
      'statementType': 'DELETE',
      'status': 'refused',
      'from': '2026-10-01T06:00:00.000Z',
      'to': '2026-10-25T09:30:00.000Z',
      'search': 'orders',
    });
  });

  test('sends a local time as UTC with Z', () async {
    final stub = _StubInterceptor(200);
    final local = DateTime(2026, 10, 1, 8);

    await _stubbed(stub).list(filter: AuditFilter(from: local), offset: 0);

    expect(stub.requests.single.queryParameters['from'], local.toUtc().toIso8601String());
    expect(stub.requests.single.queryParameters['from'], endsWith('Z'));
  });

  test('sends no empty search', () async {
    final stub = _StubInterceptor(200);

    await _stubbed(stub).list(
      filter: AuditFilter(search: '   ', status: 'error'),
      offset: 0,
    );

    expect(stub.requests.single.queryParameters, {'limit': 50, 'offset': 0, 'status': 'error'});
  });

  test('encodes the filters in the URL of the production chain', () async {
    final adapter = _RecordingAdapter();

    await _productionRepository(adapter).list(filter: AuditFilter(search: 'a&b c'), offset: 0);

    expect(adapter.requests.single.path, '/api/v1/audit');
    expect(adapter.requests.single.queryParameters, {'limit': '50', 'offset': '0', 'search': 'a&b c'});
  });

  test('asserts a limit from 1 to 200 and an offset of 0 or more', () async {
    final stub = _StubInterceptor(200);
    final repository = _stubbed(stub);

    for (final (offset, limit) in [(0, 0), (0, 201), (-1, 50)]) {
      await expectLater(
        repository.list(filter: const AuditFilter(), offset: offset, limit: limit),
        throwsA(isA<AssertionError>()),
      );
    }
    expect(stub.requests, isEmpty);
    await repository.list(filter: const AuditFilter(), offset: 0, limit: 200);
    expect(stub.requests.single.queryParameters['limit'], 200);
  });

  test('returns the offset it asked for on the page', () async {
    final result = await _stubbed(_StubInterceptor(200, '{"events":[$_aliceEvent],"total":80}'))
        .list(filter: const AuditFilter(), offset: 50);

    final page = (result as Success<AuditPage>).data;
    expect(page.offset, 50);
    expect(page.total, 80);
    expect(page.hasMore, isTrue);
  });

  test('never stores the answer in the cache', () async {
    await PlatformAuditRepository(TestEnv.platformApiClient()).list(filter: const AuditFilter(), offset: 0);
    await PlatformAuditRepository(TestEnv.platformApiClient()).list(filter: const AuditFilter(), offset: 0);

    expect(await SharedPrefsCacheStorage().count(), 0);
  });

  group('maps a refusal through platformError', () {
    final cases = <String, (int, String, AppErrorCode, Type)>{
      '403 PLAN_FEATURE_REQUIRED': (
        403,
        _envelope('PLAN_FEATURE_REQUIRED'),
        AppErrorCode.platformPlanFeatureRequired,
        AuthError,
      ),
      '403 PERMISSION_DENIED': (403, _envelope('PERMISSION_DENIED'), AppErrorCode.platformPermissionDenied, AuthError),
      '500 INTERNAL_ERROR': (500, _envelope('INTERNAL_ERROR'), AppErrorCode.platformInternalError, ServerError),
      'a body without events': (200, '{"total":0}', AppErrorCode.platformUnreadableAnswer, ServerError),
    };
    for (final MapEntry(key: name, value: (status, body, code, type)) in cases.entries) {
      test('for $name', () async {
        final result = await _stubbed(_StubInterceptor(status, body)).list(filter: const AuditFilter(), offset: 0);

        expect(
          result,
          isA<Failure<AuditPage>>()
              .having((f) => f.error.runtimeType, 'type', type)
              .having((f) => f.error.code, 'code', code.key),
        );
      });
    }
  });

  test('maps 400 VALIDATION_FAILED on search to platformValidationFailed naming search, without a value', () async {
    final result = await _stubbed(
      _StubInterceptor(
        400,
        _envelope(
          'VALIDATION_FAILED',
          fieldErrors: {
            'search': ['Too big: alice_salary'],
          },
        ),
      ),
    ).list(filter: AuditFilter(search: 'alice_salary'), offset: 0);

    final error = (result as Failure<AuditPage>).error;
    expect(error, isA<ValidationError>());
    expect(error.code, AppErrorCode.platformValidationFailed.key);
    expect(error.message, contains('search'));
    expect(error.message, isNot(contains('alice')));
    expect('$error', isNot(contains('alice')));
  });

  test('maps a transport failure through platformError, without a value of the filter', () async {
    final result = await _stubbed(_StubInterceptor(0)).list(filter: _aliceFilter, offset: 0);

    final error = (result as Failure<AuditPage>).error;
    expect(error, isA<NetworkError>());
    expect(error.message, isNot(contains('alice')));
  });

  test(
    'logs the counts, the offset and the set filter names only, never a filter value, statement or subject',
    () async {
      final lines = await printedLines(() async {
        expect(
          await _stubbed(_StubInterceptor(200, '{"events":[$_aliceEvent],"total":1}'))
              .list(filter: _aliceFilter, offset: 0),
          isA<Success<AuditPage>>(),
        );
        expect(
          await _stubbed(_StubInterceptor(400, _envelope('VALIDATION_FAILED', fieldErrors: {'search': 'x'})))
              .list(filter: _aliceFilter, offset: 0),
          isA<Failure<AuditPage>>(),
        );
      });

      final repositoryLines = lines.where((line) => line.contains('PlatformAuditRepository')).toList();
      expect(repositoryLines, [
        allOf(contains('list: 1 events of 1 from offset 0'), contains('subject'), contains('search')),
        allOf(contains('[W]'), contains('list failed: platform.validation_failed')),
      ]);
      expect(lines.where((line) => line.contains('alice') || line.contains('Alice')), isEmpty);
      expect(lines.where((line) => line.contains('payroll') || line.contains('permission denied')), isEmpty);
    },
  );

  test('the request line of the whole client chain keeps the filter names and masks their values', () async {
    final lines = await printedLines(() async {
      expect(
        await PlatformAuditRepository(TestEnv.platformApiClient()).list(filter: _aliceFilter, offset: 0),
        isA<Success<AuditPage>>(),
      );
    });

    expect(lines.where((line) => line.contains('GET') && line.contains('/v1/audit?')), [
      allOf(contains('subject=[REDACTED]'), contains('search=[REDACTED]'), contains('limit=[REDACTED]')),
    ]);
    expect(lines.where((line) => line.contains('alice')), isEmpty);
  });
}
