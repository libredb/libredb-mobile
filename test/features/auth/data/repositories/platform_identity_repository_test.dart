import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/printed_lines.dart';
import '../../../../support/test_env.dart';

/// Answers every request with [statusCode] and [body], and records the paths it saw.
class _StubInterceptor extends Interceptor {
  _StubInterceptor(this.statusCode, this.body);

  final int statusCode;
  final String body;
  final paths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    paths.add(options.path);
    final response = Response<String>(requestOptions: options, statusCode: statusCode, data: body);
    if (statusCode >= 200 && statusCode < 300) {
      handler.resolve(response);
    } else {
      handler.reject(DioException(requestOptions: options, response: response, type: DioExceptionType.badResponse));
    }
  }
}

void main() {
  PlatformIdentityRepository repositoryAnswering(int statusCode, String body, [List<String>? paths]) {
    final stub = _StubInterceptor(statusCode, body);
    final dio = Dio()..interceptors.add(stub);
    if (paths != null) stub.paths.addAll(paths);
    return PlatformIdentityRepository(TestEnv.platformApiClient(dio: dio));
  }

  test('reads the signed-in admin from the mock', () async {
    TestEnv.authenticate();

    final result = await PlatformIdentityRepository(TestEnv.platformApiClient()).fetch();

    expect(
      result,
      isA<Success<PlatformIdentity>>()
          .having((s) => s.data.roles, 'roles', ['PLATFORM_ADMIN'])
          .having((s) => s.data.tenant.slug, 'tenant.slug', 'example-org'),
    );
  });

  test('sends GET /v1/me', () async {
    final stub = _StubInterceptor(200, '{}');
    final dio = Dio()..interceptors.add(stub);

    await PlatformIdentityRepository(TestEnv.platformApiClient(dio: dio)).fetch();

    expect(stub.paths, ['/v1/me']);
  });

  test('maps an answer it cannot read to platformUnreadableAnswer', () async {
    final result = await repositoryAnswering(200, '{"id":"u1"}').fetch();

    expect(
      result,
      isA<Failure<PlatformIdentity>>()
          .having((f) => f.error, 'error', isA<ServerError>())
          .having((f) => f.error.code, 'code', AppErrorCode.platformUnreadableAnswer.key),
    );
  });

  test("maps a refusal through platformError, with Platform's code", () async {
    final result = await repositoryAnswering(
      403,
      '{"error":{"code":"ADMIN_ROLE_REQUIRED","message":"The account lacks the Platform admin role"}}',
    ).fetch();

    expect(result, isA<Failure<PlatformIdentity>>());
    expect((result as Failure<PlatformIdentity>).error.code, AppErrorCode.platformAdminRoleRequired.key);
  });

  test('logs neither the e-mail, the name, nor a Platform message that names a user', () async {
    const success = {
      'id': 'u1',
      'email': 'jane.doe@example.org',
      'name': 'Jane Doe',
      'roles': ['PLATFORM_ADMIN'],
      'permissions': <String>[],
      'tenant': {'id': 't1', 'name': 'Example Org', 'slug': 'example-org'},
    };
    const refusal = '{"error":{"code":"LICENSE_ADMIN_SEATS","message":"No admin seat left for jane.doe@example.org"}}';

    final lines = await printedLines(() async {
      expect(await repositoryAnswering(200, jsonEncode(success)).fetch(), isA<Success<PlatformIdentity>>());
      expect(await repositoryAnswering(403, refusal).fetch(), isA<Failure<PlatformIdentity>>());
    });

    expect(lines, isNotEmpty);
    expect(lines, everyElement(isNot(contains('jane.doe'))));
    expect(lines, everyElement(isNot(contains('Jane Doe'))));
    expect(lines, everyElement(isNot(contains('No admin seat'))));
  });
}
