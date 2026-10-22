import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

void main() {
  StudioConnection connection({bool readOnly = false, StudioAccess? access}) =>
      StudioConnection(id: 'seed:a', name: 'A', type: 'postgres', readOnly: readOnly, access: access);

  group('readOnlyForUser', () {
    test('is true for a read grant, whatever the seed flag says', () {
      expect(connection(access: StudioAccess.read).readOnlyForUser, isTrue);
      expect(connection(readOnly: true, access: StudioAccess.read).readOnlyForUser, isTrue);
    });

    test('follows the seed flag for a write grant', () {
      expect(connection(access: StudioAccess.write).readOnlyForUser, isFalse);
      expect(connection(readOnly: true, access: StudioAccess.write).readOnlyForUser, isTrue);
    });

    test('follows the seed flag without an access level (no governance, or Studio before libredb-studio#1922)', () {
      expect(connection().readOnlyForUser, isFalse);
      expect(connection(readOnly: true).readOnlyForUser, isTrue);
    });
  });

  test('keeps the access level apart from the seed flag', () {
    expect(connection(access: StudioAccess.read), isNot(connection(readOnly: true)));
    expect(connection(access: StudioAccess.read), isNot(connection()));
    expect(connection(access: StudioAccess.read), connection(access: StudioAccess.read));
  });
}
