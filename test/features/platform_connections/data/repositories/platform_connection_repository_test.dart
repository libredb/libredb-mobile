import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/data/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

import '../../../../support/printed_lines.dart';
import '../../../../support/test_env.dart';

/// Answers every request with [statusCode] and [body], or fails it with [transport] before any answer, and records
/// the requests it saw.
class _StubInterceptor extends Interceptor {
  _StubInterceptor(this.statusCode, this.body, {this.transport});

  final int statusCode;
  final String body;
  final DioExceptionType? transport;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    if (transport case final type?) {
      handler.reject(DioException(requestOptions: options, type: type));
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

String _envelope(String code, [String message = 'Platform text']) => '{"error":{"code":"$code","message":"$message"}}';

void main() {
  PlatformConnectionRepository repositoryWith(_StubInterceptor stub) =>
      PlatformConnectionRepository(TestEnv.platformApiClient(dio: Dio()..interceptors.add(stub)));

  Future<Result<List<PlatformConnection>>> listAnswering(int statusCode, String body) =>
      repositoryWith(_StubInterceptor(statusCode, body)).list();

  test('lists the connections of the mock in server order', () async {
    TestEnv.authenticate();

    final result = await PlatformConnectionRepository(TestEnv.platformApiClient()).list();

    expect(
      result,
      isA<Success<List<PlatformConnection>>>().having((s) => s.data.map((c) => c.engine), 'engines', [
        'redis',
        'mongodb',
        'mysql',
        'postgres',
      ]),
    );
  });

  test('sends exactly GET /v1/connections, with no query and no path params', () async {
    final stub = _StubInterceptor(200, '{"connections":[]}');

    await repositoryWith(stub).list();

    expect(stub.requests, hasLength(1));
    expect(stub.requests.single.method, 'GET');
    expect(stub.requests.single.path, '/v1/connections');
    expect(stub.requests.single.queryParameters, isEmpty);
    expect(stub.requests.single.extra['cachePolicy'], isNull);
  });

  test('never stores the answer in the cache', () async {
    TestEnv.authenticate();

    await PlatformConnectionRepository(TestEnv.platformApiClient()).list();
    await PlatformConnectionRepository(TestEnv.platformApiClient()).list();

    expect(await SharedPrefsCacheStorage().count(), 0);
  });

  group('maps a refusal through platformError', () {
    final cases = <String, (int, String, AppErrorCode, Type)>{
      '401 BEARER_INVALID': (401, _envelope('BEARER_INVALID'), AppErrorCode.authInvalidAccessToken, AuthError),
      '403 ADMIN_ROLE_REQUIRED': (
        403,
        _envelope('ADMIN_ROLE_REQUIRED'),
        AppErrorCode.platformAdminRoleRequired,
        AuthError,
      ),
      '404 API_DISABLED': (404, _envelope('API_DISABLED'), AppErrorCode.platformApiDisabled, NotFoundError),
      '503 IDENTITY_PROVIDER_UNAVAILABLE': (
        503,
        _envelope('IDENTITY_PROVIDER_UNAVAILABLE'),
        AppErrorCode.platformIdentityProviderUnavailable,
        ServerError,
      ),
      '500 INTERNAL_ERROR': (500, _envelope('INTERNAL_ERROR'), AppErrorCode.platformInternalError, ServerError),
      'an unreadable body': (200, '{"connections":[{"id":"c1"}]}', AppErrorCode.platformUnreadableAnswer, ServerError),
    };
    for (final MapEntry(key: name, value: (status, body, code, type)) in cases.entries) {
      test('for $name', () async {
        final result = await listAnswering(status, body);

        expect(
          result,
          isA<Failure<List<PlatformConnection>>>()
              .having((f) => f.error.runtimeType, 'type', type)
              .having((f) => f.error.code, 'code', code.key),
        );
      });
    }
  });

  test('maps a transport failure through the shared transport mapping', () async {
    final result = await repositoryWith(_StubInterceptor(0, '', transport: DioExceptionType.connectionError)).list();

    expect(result, isA<Failure<List<PlatformConnection>>>().having((f) => f.error, 'error', isA<NetworkError>()));
  });

  test("logs the count and the mapped code only, never a connection name or Platform's message", () async {
    const success =
        '{"connections":[{"id":"c1","name":"Payroll Secret","engine":"postgres","status":"active",'
        '"hasWriteCredential":true}]}';

    final lines = await printedLines(() async {
      expect(await listAnswering(200, success), isA<Success<List<PlatformConnection>>>());
      expect(
        await listAnswering(403, _envelope('ADMIN_ROLE_REQUIRED', 'jane.doe lacks the admin role')),
        isA<Failure<List<PlatformConnection>>>(),
      );
    });

    final repositoryLines = lines.where((line) => line.contains('PlatformConnectionRepository')).toList();
    expect(repositoryLines, [
      contains('list: 1 connections'),
      allOf(contains('[W]'), contains('list failed: platform.admin_role_required')),
    ]);
    expect(lines, everyElement(isNot(contains('Payroll'))));
    expect(lines, everyElement(isNot(contains('jane.doe'))));
  });
}
