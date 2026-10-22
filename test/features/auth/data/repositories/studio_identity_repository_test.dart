import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/models/studio_identity_model.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/printed_lines.dart';
import '../../../../support/test_env.dart';

void main() {
  group('StudioIdentityRepository.fetch', () {
    test('reads the session of GET /auth/me', () async {
      TestEnv.authenticate();

      final result = await StudioIdentityRepository(TestEnv.apiClient()).fetch();

      expect(
        result,
        isA<Success<StudioIdentity>>().having(
          (s) => s.data,
          'data',
          StudioIdentity(
            username: 'admin@example.com',
            role: StudioRole.admin,
            subject: '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10',
            issuer: 'https://localhost:8443/realms/libredb',
            expiresAt: DateTime.fromMillisecondsSinceEpoch(1792620060 * 1000, isUtc: true),
            viaBearer: true,
          ),
        ),
      );
    });

    test('fails with an AuthError without a session', () async {
      final result = await StudioIdentityRepository(TestEnv.apiClient()).fetch();

      expect(result, isA<Failure<StudioIdentity>>().having((f) => f.error, 'error', isA<AuthError>()));
    });
  });

  group('StudioIdentityRepository.recordSignOut', () {
    test('posts an empty JSON object to POST /auth/logout with the bearer and succeeds on its answer', () async {
      TestEnv.authenticate();
      final client = TestEnv.apiClient();
      final sent = <RequestOptions>[];
      client.instance.interceptors.insert(client.instance.interceptors.length - 1, _RequestRecorder(sent));

      final result = await StudioIdentityRepository(client).recordSignOut();

      expect(result, const Success<void>(null));
      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/logout');
      expect(request.data, <String, Object?>{});
      expect(request.contentType, startsWith('application/json'));
      expect(request.headers['Authorization'], startsWith('Bearer '));
    });

    for (final status in [401, 500]) {
      test('fails when Studio answers $status, and logs it at debug level without the body', () async {
        final client = TestEnv.apiClient();
        client.instance.interceptors.insert(0, _StatusInterceptor(status));
        late Result<void> result;

        final lines = await printedLines(() async => result = await StudioIdentityRepository(client).recordSignOut());

        expect(result, isA<Failure<void>>());
        final repositoryLines = lines.where((line) => line.contains('StudioIdentityRepository')).toList();
        expect(repositoryLines, [allOf(contains('[D]'), contains('recordSignOut failed'))]);
        expect(lines.where((line) => line.contains('refused-body-text')), isEmpty);
      });
    }

    test('fails on an answer that does not say the sign-out was recorded', () async {
      TestEnv.authenticate();
      final client = TestEnv.apiClient();
      client.instance.interceptors.insert(0, _AnswerInterceptor('{"success":false}'));

      final result = await StudioIdentityRepository(client).recordSignOut();

      expect(result, isA<Failure<void>>().having((f) => f.error, 'error', isA<ServerError>()));
    });
  });

  group('StudioIdentityModel.fromJsonString', () {
    test('reads a cookie session, which has no channel and no identity provider fields', () {
      final identity = StudioIdentityModel.fromJsonString(
        '{"authenticated":true,"user":{"role":"user","username":"user","iat":1,"exp":2}}',
      );

      expect(identity.role, StudioRole.user);
      expect(identity.viaBearer, isFalse);
      expect(identity.subject, isNull);
    });

    test('refuses an answer that is not signed in, or names an unknown role', () {
      for (final body in [
        '{"authenticated":false}',
        '{"authenticated":true}',
        '{"authenticated":true,"user":{"role":"owner","username":"x"}}',
        '{"authenticated":true,"user":{"role":"user"}}',
      ]) {
        expect(() => StudioIdentityModel.fromJsonString(body), throwsFormatException, reason: body);
      }
    });
  });
}

/// Records every request it sees, after the token is attached and before the mock answers it.
class _RequestRecorder extends Interceptor {
  _RequestRecorder(this._sent);

  final List<RequestOptions> _sent;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _sent.add(options);
    handler.next(options);
  }
}

/// Fails every request with an error response of [statusCode] whose body must never be logged.
class _StatusInterceptor extends Interceptor {
  _StatusInterceptor(this.statusCode);

  final int statusCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: statusCode, data: '{"error":"refused-body-text"}'),
      ),
    );
  }
}

/// Answers every request with 200 and [body].
class _AnswerInterceptor extends Interceptor {
  _AnswerInterceptor(this.body);

  final String body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: body));
  }
}
