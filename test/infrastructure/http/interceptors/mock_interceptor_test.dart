import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/mock_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/printed_lines.dart';

/// Builds a JWT signed nowhere: three base64url parts with the given `exp`, or with no `exp` claim when it is null.
String _jwt(DateTime? exp) {
  String part(Map<String, Object> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final payload = {'sub': 'admin', 'exp': ?(exp == null ? null : exp.millisecondsSinceEpoch ~/ 1000)};
  return '${part({'alg': 'RS256', 'typ': 'JWT'})}.${part(payload)}.c2lnbmF0dXJl';
}

/// The 401 the mock answers to a protected path it does not let through.
final _unauthorized = isA<DioException>()
    .having((e) => e.type, 'type', DioExceptionType.badResponse)
    .having((e) => e.response?.statusCode, 'statusCode', 401)
    .having((e) => e.response?.data, 'data', 'Unauthorized Access');

void main() {
  Dio mockDio() => Dio()..interceptors.add(MockInterceptor(appConfig: const AppConfig.test()));

  Future<Response<dynamic>> getAccount({String? authorization}) =>
      mockDio().get('/auth/me', options: Options(headers: {'Authorization': ?authorization}));

  group('MockInterceptor bearer check', () {
    test('an expired JWT bearer gets a 401', () async {
      final expired = _jwt(DateTime.now().subtract(const Duration(minutes: 1)));

      await expectLater(getAccount(authorization: 'Bearer $expired'), throwsA(_unauthorized));
    });

    test('an unexpired JWT bearer reaches the mock file', () async {
      final valid = _jwt(DateTime.now().add(const Duration(minutes: 5)));

      final response = await getAccount(authorization: 'Bearer $valid');

      expect(response.statusCode, 200);
      expect(response.data, contains('"authenticated": true'));
    });

    test('a 3-part bearer without an exp claim still reaches the mock file', () async {
      final noExp = _jwt(null);
      late Response<dynamic> response;

      final lines = await printedLines(() async => response = await getAccount(authorization: 'Bearer $noExp'));

      expect(response.statusCode, 200);
      expect(response.data, contains('"authenticated": true'));
      expect(lines.where((line) => line.contains('[E]')), isEmpty);
    });

    test('the opaque MOCK_TOKEN still reaches the mock file', () async {
      final response = await getAccount(authorization: 'Bearer MOCK_TOKEN');

      expect(response.statusCode, 200);
      expect(response.data, contains('"authenticated": true'));
    });

    test('a request with no Authorization header still gets a 401', () async {
      await expectLater(getAccount(), throwsA(_unauthorized));
    });
  });

  group('MockInterceptor transaction actions', () {
    Future<Response<dynamic>> transaction(Object? data) => mockDio().post(
      '/db/transaction',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer MOCK_TOKEN'}, extra: {'_basePath': '/db/transaction'}),
    );

    test('each action reads the recorded answer named after it', () async {
      for (final (action, status) in [('begin', 'active'), ('commit', 'committed'), ('rollback', 'rolled_back')]) {
        final response = await transaction({'connectionId': 'seed:sales-db', 'action': action});

        expect(response.statusCode, 201, reason: action);
        expect((jsonDecode(response.data as String) as Map<String, dynamic>)['status'], status, reason: action);
      }
    });

    test('an action without a recorded answer gets a 501 naming its file', () async {
      await expectLater(
        transaction({'connectionId': 'seed:sales-db', 'action': 'unknown'}),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'statusCode', 501)
              .having((e) => e.message, 'message', contains('assets/mock/POST_db_transaction_unknown.json')),
        ),
      );
    });

    test('a request without an action gets a 501, not the answer of some action', () async {
      for (final data in <Object?>[
        {'connectionId': 'seed:sales-db'},
        {'connectionId': 'seed:sales-db', 'action': 1},
        null,
      ]) {
        await expectLater(
          transaction(data),
          throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 501)),
          reason: '$data',
        );
      }
    });
  });
}
