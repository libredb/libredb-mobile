import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_grants/data/models/grant_put_body.dart';
import 'package:libredb_mobile/features/platform_grants/data/models/grant_put_answer_json.dart';

void main() {
  group('GrantPutBody', () {
    test('has exactly level and expiresAt, the expiry in UTC ISO 8601 ending in Z', () {
      final body = GrantPutBody(level: 'read', expiresAt: DateTime.utc(2027, 3, 4, 5, 6)).toJson();

      expect(body.keys, unorderedEquals(['level', 'expiresAt']));
      expect(body['level'], 'read');
      expect(body['expiresAt'], '2027-03-04T05:06:00.000Z');
    });

    test('converts a local time to UTC', () {
      final local = DateTime(2027, 3, 4, 5, 6);

      final expiresAt = GrantPutBody(level: 'write', expiresAt: local).toJson()['expiresAt']! as String;

      expect(expiresAt, endsWith('Z'));
      expect(DateTime.parse(expiresAt), local.toUtc());
    });

    test('keeps the expiresAt key with JSON null for a grant that does not expire', () {
      final body = GrantPutBody(level: 'read', expiresAt: null).toJson();

      expect(body.containsKey('expiresAt'), isTrue);
      expect(jsonEncode(body), '{"level":"read","expiresAt":null}');
    });
  });

  group('GrantPutAnswerJson', () {
    test('reads the grant id', () {
      expect(GrantPutAnswerJson.read('{"id":"g-9"}'), 'g-9');
    });

    for (final body in ['{}', '{"id":9}', '{"id":null}', '[]', '"g-9"']) {
      test('throws a FormatException for $body', () {
        expect(() => GrantPutAnswerJson.read(body), throwsFormatException);
      });
    }
  });
}
