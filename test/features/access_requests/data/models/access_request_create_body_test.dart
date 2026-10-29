import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/access_requests/data/models/access_request_create_body.dart';

void main() {
  group('AccessRequestCreateBody.toJson', () {
    test('gives exactly connectionId, level and reason', () {
      const body = AccessRequestCreateBody(connectionId: 'c1', level: 'read', reason: 'The October report');

      expect(body.toJson(), {'connectionId': 'c1', 'level': 'read', 'reason': 'The October report'});
      expect(body.toJson().keys, hasLength(3));
    });

    test('trims a padded reason', () {
      const body = AccessRequestCreateBody(connectionId: 'c1', level: 'write', reason: '   The October report \n ');

      expect(body.toJson()['reason'], 'The October report');
    });
  });
}
