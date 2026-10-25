import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
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

/// The production Platform chain, its adapter replaced by [adapter], so every interceptor sees the answer.
PlatformDirectoryRepository _productionRepository(HttpClientAdapter adapter) {
  final client = PlatformApiClient(
    appConfig: _prodConfig,
    secureStorage: FlutterSecureStorageAdapter(),
    tokenRotation: const RefusingTokenRotation(),
  );
  client.instance.httpClientAdapter = adapter;
  return PlatformDirectoryRepository(client);
}

/// Answers every request with [statusCode] and [body], and records each request's uri.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = '{"users":[],"page":1,"total":0}'});

  final int statusCode;
  final String body;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
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

/// Answers every request with [statusCode] and [body] before the client's own chain, and records the requests.
class _StubInterceptor extends Interceptor {
  _StubInterceptor(this.statusCode, this.body);

  final int statusCode;
  final String body;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    final response = Response<String>(requestOptions: options, statusCode: statusCode, data: body);
    if (statusCode >= 200 && statusCode < 300) {
      handler.resolve(response);
    } else {
      handler.reject(DioException(requestOptions: options, response: response, type: DioExceptionType.badResponse));
    }
  }
}

String _envelope(String code, {Map<String, Object?>? fieldErrors}) => jsonEncode({
  'error': {'code': code, 'message': 'The Keycloak user alice@example.com is unknown', 'fieldErrors': ?fieldErrors},
});

PlatformDirectoryRepository _stubbed(_StubInterceptor stub) =>
    PlatformDirectoryRepository(TestEnv.platformApiClient(dio: Dio()..interceptors.add(stub)));

void main() {
  setUp(() => TestEnv.authenticate(target: SessionTarget.platform));
  tearDown(ResilienceInterceptor.instance.resetAll);

  test('reads the mock page: 20 users, page 1 and a total above 20', () async {
    final result = await PlatformDirectoryRepository(TestEnv.platformApiClient()).search(query: '', page: 1);

    final page = (result as Success<DirectoryPage>).data;
    expect(page.users, hasLength(20));
    expect(page.page, 1);
    expect(page.total, greaterThan(20));
    expect(page.users.where((user) => !user.enabled), isNotEmpty);
    expect(page.users.where((user) => user.studioRole == null), isNotEmpty);
    expect(page.users.where((user) => user.studioRole == 'admin'), isNotEmpty);
    expect(page.users.where((user) => user.needsSeat), isNotEmpty);
    expect(page.users.where((user) => user.email == null && user.fullName == null), isNotEmpty);
  });

  test('sends GET /v1/directory/users with page and no q for an empty query', () async {
    final stub = _StubInterceptor(200, '{"users":[],"page":1,"total":0}');

    await _stubbed(stub).search(query: '', page: 1);

    expect(stub.requests.single.method, 'GET');
    expect(stub.requests.single.path, '/v1/directory/users');
    expect(stub.requests.single.queryParameters, {'page': 1});
  });

  test('sends the trimmed query as q, encoded in the URL', () async {
    final adapter = _RecordingAdapter();

    await _productionRepository(adapter).search(query: '  ali ce@x ', page: 2);

    expect(adapter.requests.single.path, '/api/v1/directory/users');
    expect(adapter.requests.single.queryParameters, {'page': '2', 'q': 'ali ce@x'});
  });

  test('sends a whitespace-only query as no q', () async {
    final adapter = _RecordingAdapter();

    await _productionRepository(adapter).search(query: '   ', page: 1);

    expect(adapter.requests.single.queryParameters, {'page': '1'});
  });

  test('sends a 503 DIRECTORY_UNAVAILABLE once and maps it to platformDirectoryUnavailable', () async {
    final adapter = _RecordingAdapter(statusCode: 503, body: _envelope('DIRECTORY_UNAVAILABLE'));

    final result = await _productionRepository(adapter).search(query: 'alice', page: 1);

    expect(adapter.requests, hasLength(1));
    expect(
      result,
      isA<Failure<DirectoryPage>>().having((f) => f.error.code, 'code', AppErrorCode.platformDirectoryUnavailable.key),
    );
  });

  test('never stores the answer in the cache', () async {
    await PlatformDirectoryRepository(TestEnv.platformApiClient()).search(query: '', page: 1);
    await PlatformDirectoryRepository(TestEnv.platformApiClient()).search(query: '', page: 1);

    expect(await SharedPrefsCacheStorage().count(), 0);
  });

  group('maps a refusal through platformError', () {
    final cases = <String, (int, String, AppErrorCode, Type)>{
      '400 VALIDATION_FAILED on q': (
        400,
        _envelope('VALIDATION_FAILED', fieldErrors: {'q': 'too long'}),
        AppErrorCode.platformValidationFailed,
        ValidationError,
      ),
      '502 KEYCLOAK_AUTH_ERROR': (
        502,
        _envelope('KEYCLOAK_AUTH_ERROR'),
        AppErrorCode.platformKeycloakUnavailable,
        ServerError,
      ),
      '404 KEYCLOAK_NOT_FOUND': (
        404,
        _envelope('KEYCLOAK_NOT_FOUND'),
        AppErrorCode.platformKeycloakUnavailable,
        ServerError,
      ),
      '500 INTERNAL_ERROR': (500, _envelope('INTERNAL_ERROR'), AppErrorCode.platformInternalError, ServerError),
      'an unreadable body': (
        200,
        '{"users":[{"id":"kc-1"}],"page":1,"total":1}',
        AppErrorCode.platformUnreadableAnswer,
        ServerError,
      ),
    };
    for (final MapEntry(key: name, value: (status, body, code, type)) in cases.entries) {
      test('for $name', () async {
        final result = await _stubbed(_StubInterceptor(status, body)).search(query: 'a', page: 1);

        expect(
          result,
          isA<Failure<DirectoryPage>>()
              .having((f) => f.error.runtimeType, 'type', type)
              .having((f) => f.error.code, 'code', code.key),
        );
      });
    }
  });

  test('logs the page and the count only, never the query, a username or an e-mail address', () async {
    const body =
        '{"users":[{"id":"kc-alice","username":"alice","email":"alice@example.com","firstName":"Alice",'
        '"lastName":"Stone","enabled":true,"studioRole":"user","needsSeat":false}],"page":1,"total":1}';

    final lines = await printedLines(() async {
      expect(
        await _stubbed(_StubInterceptor(200, body)).search(query: 'alice', page: 1),
        isA<Success<DirectoryPage>>(),
      );
      expect(
        await _stubbed(_StubInterceptor(503, _envelope('DIRECTORY_UNAVAILABLE'))).search(query: 'alice', page: 1),
        isA<Failure<DirectoryPage>>(),
      );
    });

    final repositoryLines = lines.where((line) => line.contains('PlatformDirectoryRepository')).toList();
    expect(repositoryLines, [
      contains('search: page 1, 1 users of 1'),
      allOf(contains('[W]'), contains('search failed: platform.directory_unavailable')),
    ]);
    expect(lines.where((line) => line.contains('alice') || line.contains('Alice')), isEmpty);
  });
}
