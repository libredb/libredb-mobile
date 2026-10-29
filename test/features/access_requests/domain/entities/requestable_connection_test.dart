import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';

RequestableConnection _connection({ConnectionAccess? access, String? pendingRequestId}) => RequestableConnection(
  id: 'c1',
  name: 'Sales reporting',
  engine: 'postgres',
  hasWriteCredential: true,
  access: access,
  pendingRequestId: pendingRequestId,
);

void main() {
  group('RequestableConnection', () {
    test('toString prints the id and the level only', () {
      final printed = _connection(
        access: ConnectionAccess(level: 'read', expiresAt: DateTime.utc(2027)),
      ).toString();

      expect(printed, 'RequestableConnection(id: c1, level: read)');
    });

    test('toString prints no level for a connection the user does not hold', () {
      expect(_connection().toString(), 'RequestableConnection(id: c1, level: null)');
    });

    test('toString carries no connection name', () {
      expect(_connection().toString(), isNot(contains('Sales reporting')));
    });

    test('is equal by value', () {
      expect(_connection(), _connection());
      expect(_connection(), isNot(_connection(pendingRequestId: 'r1')));
      expect(
        _connection(access: const ConnectionAccess(level: 'read', expiresAt: null)),
        _connection(access: const ConnectionAccess(level: 'read', expiresAt: null)),
      );
    });
  });

  group('ConnectionAccess', () {
    test('toString prints the level and the expiry', () {
      expect(const ConnectionAccess(level: 'write', expiresAt: null).toString(), contains('write'));
    });
  });
}
