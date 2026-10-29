import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';

MyAccessRequest _request({
  String id = 'r1',
  AccessRequestStatus status = AccessRequestStatus.refused,
  String rawStatus = 'refused',
}) => MyAccessRequest(
  id: id,
  connectionId: 'c1',
  connectionName: 'Sales reporting',
  connectionEngine: 'postgres',
  connectionStatus: 'active',
  level: 'read',
  reason: 'I need the order totals for the October report',
  status: status,
  rawStatus: rawStatus,
  createdAt: DateTime.utc(2026, 10, 29, 8),
  decidedAt: DateTime.utc(2026, 10, 29, 9),
  decisionReason: 'Ask your team lead first',
  grantId: null,
);

void main() {
  group('MyAccessRequest', () {
    test('toString prints the id, the status and the level only', () {
      expect(_request().toString(), 'MyAccessRequest(id: r1, status: refused, level: read)');
    });

    test('toString carries no reason, decision reason or connection name', () {
      final printed = _request().toString();

      for (final secret in ['October report', 'Ask your team lead', 'Sales reporting']) {
        expect(printed, isNot(contains(secret)), reason: secret);
      }
    });

    test('toString prints the raw status of an unknown one', () {
      final printed = _request(status: AccessRequestStatus.unknown, rawStatus: 'escalated').toString();

      expect(printed, contains('escalated'));
    });

    test('is equal by value', () {
      expect(_request(), _request());
      expect(_request(), isNot(_request(id: 'r2')));
    });
  });

  group('AccessRequestStatus.of', () {
    for (final (raw, expected) in const [
      ('pending', AccessRequestStatus.pending),
      ('approved', AccessRequestStatus.approved),
      ('refused', AccessRequestStatus.refused),
      ('withdrawn', AccessRequestStatus.withdrawn),
      ('expired', AccessRequestStatus.expired),
      ('escalated', AccessRequestStatus.unknown),
      ('PENDING', AccessRequestStatus.unknown),
      ('', AccessRequestStatus.unknown),
    ]) {
      test('reads "$raw" as $expected', () => expect(AccessRequestStatus.of(raw), expected));
    }
  });
}
