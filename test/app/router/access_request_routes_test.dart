import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

void main() {
  test('the access request routes sit under the Studio connection list', () {
    expect(ApplicationRoutesConstants.accessRequests, '/connections/requests');
    expect(ApplicationRoutesConstants.accessRequestNew, '/connections/requests/new');
  });

  for (final route in [ApplicationRoutesConstants.accessRequests, ApplicationRoutesConstants.accessRequestNew]) {
    test('$route belongs to a Studio session and not to a Platform session', () {
      expect(ApplicationRoutesConstants.belongsTo(SessionTarget.studio, route), isTrue);
      expect(ApplicationRoutesConstants.belongsTo(SessionTarget.platform, route), isFalse);
    });
  }

  test('Studio keeps its three tabs', () {
    expect(ApplicationRoutesConstants.tabsFor(SessionTarget.studio), [
      ApplicationRoutesConstants.connectionList,
      ApplicationRoutesConstants.browse,
      ApplicationRoutesConstants.sql,
    ]);
  });
}
