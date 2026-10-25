import 'package:libredb_mobile/features/settings/navigation/settings_routes.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings feature exposes the route at the path and under the name it is given', () {
    final studio = SettingsFeatureRoutes.routes(path: ApplicationRoutesConstants.settings, name: 'settings');
    final platform = SettingsFeatureRoutes.routes(
      path: ApplicationRoutesConstants.platformSettings,
      name: 'platformSettings',
    );

    expect(studio, hasLength(1));
    expect(studio.single.path, ApplicationRoutesConstants.settings);
    expect(studio.single.name, 'settings');
    expect(platform.single.path, ApplicationRoutesConstants.platformSettings);
    expect(platform.single.name, 'platformSettings');
  });
}
