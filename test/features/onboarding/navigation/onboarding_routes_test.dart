import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_routes.dart';

void main() {
  test('the introduction route is named, so analytics logs it by name and M16 can follow it', () {
    expect(OnboardingFeatureRoutes.routes.map((route) => (route.name, route.path)), [
      ('welcome', ApplicationRoutesConstants.welcome),
    ]);
  });

  test('the location carries no value', () {
    expect(ApplicationRoutesConstants.welcome, '/welcome');
  });
}
