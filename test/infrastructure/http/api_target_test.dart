import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiTarget.studio', () {
    test('takes the base URL and the pins of the Studio config with the Studio envelope', () {
      final target = ApiTarget.studio(const AppConfig.prod(apiBaseUrl: 'https://studio.example.org/api'));

      expect(target.baseUrl, 'https://studio.example.org/api');
      expect(target.certificatePins, isEmpty);
      expect(target.envelope, isA<StudioErrorEnvelope>());
    });
  });

  group('StudioErrorEnvelope', () {
    const envelope = StudioErrorEnvelope();

    test('reads a top-level code from text and from a decoded map', () {
      expect(envelope.codeOf('{"code":"AUTH_REQUIRED"}'), 'AUTH_REQUIRED');
      expect(envelope.codeOf({'code': 'QUERY_ERROR'}), 'QUERY_ERROR');
      expect(envelope.codeOf('{"error":{"code":"BEARER_INVALID"}}'), isNull);
      expect(envelope.codeOf('not json'), isNull);
    });

    test('drops the database text from the exception text and keeps the server message', () {
      const body = '{"error":"syntax error at or near \\"selec\\"","code":"QUERY_ERROR","fixStatement":"GRANT x"}';

      expect(envelope.exceptionText(status: 400, data: body, scrubbedBody: body), '{"code":"QUERY_ERROR"}');
      expect(envelope.serverMessageOf(body), 'syntax error at or near "selec"');
      expect(envelope.fixStatementOf(body), 'GRANT x');
      expect(envelope.fieldErrorKeysOf(body), isEmpty);
    });

    test('keeps a body that is not JSON as it is', () {
      expect(envelope.exceptionText(status: 401, data: 'Unauthorized', scrubbedBody: 'Unauthorized'), 'Unauthorized');
    });
  });

  group('PlatformErrorEnvelope', () {
    const envelope = PlatformErrorEnvelope();
    const userMessage = 'The Keycloak user jane.doe@example.org is disabled';
    const validation =
        '{"error":{"code":"VALIDATION_FAILED","message":"$userMessage",'
        '"fieldErrors":{"subject":["$userMessage"],"level":["Invalid enum value"]}}}';

    test('reads error.code from text and from a decoded map', () {
      expect(envelope.codeOf('{"error":{"code":"BEARER_INVALID","message":"x"}}'), 'BEARER_INVALID');
      expect(
        envelope.codeOf({
          'error': {'code': 'ADMIN_ROLE_REQUIRED'},
        }),
        'ADMIN_ROLE_REQUIRED',
      );
    });

    test('reads no code from a Studio body, a plain text body or an error without a string code', () {
      expect(envelope.codeOf('{"code":"AUTH_REQUIRED"}'), isNull);
      expect(envelope.codeOf('Unauthorized'), isNull);
      expect(envelope.codeOf('{"error":"text"}'), isNull);
      expect(envelope.codeOf('{"error":{"code":42}}'), isNull);
      expect(envelope.codeOf(null), isNull);
    });

    test('reads the keys of error.fieldErrors, the root and body included', () {
      expect(envelope.fieldErrorKeysOf(validation), ['subject', 'level']);
      expect(envelope.fieldErrorKeysOf('{"error":{"code":"VALIDATION_FAILED","fieldErrors":{"":["x"]}}}'), ['']);
      expect(envelope.fieldErrorKeysOf('{"error":{"code":"VALIDATION_FAILED","fieldErrors":{"body":["x"]}}}'), [
        'body',
      ]);
      expect(envelope.fieldErrorKeysOf('{"error":{"code":"NOT_FOUND","message":"x"}}'), isEmpty);
    });

    test('builds the exception text from the status, the code and the field keys only', () {
      final text = envelope.exceptionText(status: 400, data: validation, scrubbedBody: validation);

      expect(text, 'Platform answered 400 with VALIDATION_FAILED on fields ["subject","level"]');
      expect(text, isNot(contains('jane.doe')));
      expect(text, isNot(contains('Invalid enum value')));
    });

    test('keeps a body without the envelope out of the exception text', () {
      const html = '<html>Bad gateway for jane.doe@example.org</html>';

      expect(
        envelope.exceptionText(status: 502, data: html, scrubbedBody: html),
        'Platform answered 502 without a code',
      );
    });

    test('has no server message and no fix statement', () {
      expect(envelope.serverMessageOf(validation), isNull);
      expect(envelope.fixStatementOf(validation), isNull);
    });
  });
}
