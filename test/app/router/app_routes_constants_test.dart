import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

void main() {
  group('ApplicationRoutesConstants.belongsTo', () {
    for (final location in [
      '/platform',
      '/platform/connections',
      '/platform/connections/abc',
      '/platform/connections/abc/grant',
      '/platform/settings',
      '/platform/settings?x=1',
    ]) {
      test('$location belongs to Platform only', () {
        expect(ApplicationRoutesConstants.belongsTo(SessionTarget.platform, location), isTrue);
        expect(ApplicationRoutesConstants.belongsTo(SessionTarget.studio, location), isFalse);
      });
    }

    for (final location in [
      '/connections',
      '/connections/unsaved-form',
      '/browse',
      '/browse/seed:pg/kinds?container=public',
      '/sql',
      '/settings',
    ]) {
      test('$location belongs to Studio only', () {
        expect(ApplicationRoutesConstants.belongsTo(SessionTarget.studio, location), isTrue);
        expect(ApplicationRoutesConstants.belongsTo(SessionTarget.platform, location), isFalse);
      });
    }

    for (final location in ['/', '/login', '/not-found', '/unknown', '/platformx', '/settingsx', '/browser']) {
      test('$location belongs to neither', () {
        for (final target in SessionTarget.values) {
          expect(ApplicationRoutesConstants.belongsTo(target, location), isFalse, reason: target.name);
        }
      });
    }
  });

  test('homeFor, tabsFor and settingsFor name each target its own routes', () {
    expect(ApplicationRoutesConstants.homeFor(SessionTarget.studio), '/connections');
    expect(ApplicationRoutesConstants.homeFor(SessionTarget.platform), '/platform');
    expect(ApplicationRoutesConstants.tabsFor(SessionTarget.studio), ['/connections', '/browse', '/sql']);
    expect(ApplicationRoutesConstants.tabsFor(SessionTarget.platform), [
      '/platform',
      '/platform/connections',
      '/platform/audit',
    ]);
    expect(ApplicationRoutesConstants.settingsFor(SessionTarget.studio), '/settings');
    expect(ApplicationRoutesConstants.settingsFor(SessionTarget.platform), '/platform/settings');
  });
}
