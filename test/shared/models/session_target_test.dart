import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

void main() {
  test('each target keeps its stored string', () {
    expect(SessionTarget.studio.storedValue, 'studio');
    expect(SessionTarget.platform.storedValue, 'platform');
  });

  test('fromStoredValue reads each stored string back as its target', () {
    for (final target in SessionTarget.values) {
      expect(SessionTarget.fromStoredValue(target.storedValue), target);
    }
  });

  // A stored value this build cannot read must stay unreadable, so the restore ends the session rather than guess.
  for (final value in ['', 'Studio', 'PLATFORM', ' studio', 'studio ', 'admin', 'null']) {
    test('fromStoredValue returns null for "$value"', () {
      expect(SessionTarget.fromStoredValue(value), isNull);
    });
  }
}
