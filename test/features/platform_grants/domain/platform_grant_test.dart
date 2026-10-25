import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';

void main() {
  final grant = PlatformGrant(
    id: 'g1',
    subject: 'kc-user-1',
    subjectUsername: 'bob',
    subjectEmail: 'bob@example.org',
    level: 'read',
    expiresAt: null,
    grantedBy: const PlatformGrantGranter(id: 'u1', name: 'Alice', email: 'alice@example.org'),
    grantedAt: DateTime.utc(2027),
  );

  test('prints no e-mail address, username or name, so it can reach a log', () {
    final text = '$grant';

    expect(text, contains('g1'));
    expect(text, isNot(contains('bob')));
    expect(text, isNot(contains('alice')));
    expect(text, isNot(contains('Alice')));
  });

  test('isExpiredAt holds at and after expiresAt, and never without one', () {
    final expiring = grant.copyWithExpiry(DateTime.utc(2027, 2));

    expect(expiring.isExpiredAt(DateTime.utc(2027, 1, 31)), isFalse);
    expect(expiring.isExpiredAt(DateTime.utc(2027, 2)), isTrue);
    expect(expiring.isExpiredAt(DateTime.utc(2027, 3)), isTrue);
    expect(grant.isExpiredAt(DateTime.utc(2099)), isFalse);
  });
}

extension on PlatformGrant {
  PlatformGrant copyWithExpiry(DateTime expiresAt) => PlatformGrant(
    id: id,
    subject: subject,
    subjectUsername: subjectUsername,
    subjectEmail: subjectEmail,
    level: level,
    expiresAt: expiresAt,
    grantedBy: grantedBy,
    grantedAt: grantedAt,
  );
}
