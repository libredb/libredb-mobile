import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';

void main() {
  late Dio dio;
  late List<AppErrorCode> refusals;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://studio.example.com/api'));
    refusals = [];
  });

  void answerWith(int status, String body) {
    dio.interceptors.addAll([
      AccountRefusalInterceptor(refusalOf: studioAccountRefusal, onRefused: refusals.add),
      _ServerStub(status, body),
    ]);
  }

  Future<void> expectStatus(String path, int status) => expectLater(
    dio.get<String>(path),
    throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', status)),
  );

  // From libredb-studio#1922 on, Studio refuses a verified token whose account it does not accept on every route, so
  // the refusal is reported whichever request met it, and the error still reaches the caller.
  for (final (code, expected) in [
    ('BEARER_NO_ROLE', AppErrorCode.studioAccountHasNoRole),
    ('BEARER_NO_IDENTITY', AppErrorCode.studioAccountHasNoIdentity),
  ]) {
    for (final path in ['/auth/me', '/connections/managed']) {
      test('reports a 403 $code on $path and passes the error on', () async {
        answerWith(403, '{"error":"refused","code":"$code"}');

        await expectStatus(path, 403);

        expect(refusals, [expected]);
      });
    }
  }

  for (final (status, body) in [
    (401, '{"error":"Invalid access token","code":"AUTH_REQUIRED"}'),
    (401, '{"authenticated":false}'),
    (403, '{"error":"Access denied","code":"AUTH_ERROR"}'),
    (403, '{"error":"Not permitted","code":"PERMISSION_DENIED"}'),
    (403, '{"error":"Admin access required","code":"ADMIN_REQUIRED"}'),
    (403, '{"error":"Origin mismatch","code":"ORIGIN_MISMATCH"}'),
    (403, '{"error":"Forbidden"}'),
    (403, 'Forbidden'),
    (403, ''),
    (503, '{"error":"The identity provider could not be reached.","code":"IDENTITY_PROVIDER_UNAVAILABLE"}'),
  ]) {
    test('reports nothing for $status $body', () async {
      answerWith(status, body);

      await expectStatus('/connections/managed', status);

      expect(refusals, isEmpty);
    });
  }

  test('reports nothing for a request that fails before any answer', () async {
    dio.interceptors.addAll([
      AccountRefusalInterceptor(refusalOf: studioAccountRefusal, onRefused: refusals.add),
      _NoAnswerStub(),
    ]);

    await expectLater(dio.get<String>('/connections/managed'), throwsA(isA<DioException>()));

    expect(refusals, isEmpty);
  });
}

/// Answers every request with [status] and [body], as Studio would.
class _ServerStub extends Interceptor {
  _ServerStub(this.status, this.body);

  final int status;
  final String body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: status, data: body),
      ),
      true,
    );
  }
}

/// Fails every request as an unreachable server does, with no response.
class _NoAnswerStub extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError), true);
  }
}
