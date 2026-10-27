import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/onboarding/navigation/onboarding_destination.dart';

void main() {
  test('without a pending location, the introduction hands over to the login page with nothing attached', () {
    expect(onboardingDestination(returnUrl: null), ApplicationRoutesConstants.login);
  });

  test('a pending location is carried, so the deep link survives the introduction', () {
    expect(onboardingDestination(returnUrl: '/settings'), '${ApplicationRoutesConstants.login}?returnUrl=%2Fsettings');
  });

  // Encoded once, as a query value: the login page decodes it and validates it through safeReturnPath. A location
  // with its own query would otherwise arrive as two parameters instead of one.
  test('a pending location that carries its own query stays one value', () {
    expect(
      onboardingDestination(returnUrl: '/browse/seed:pg/kinds?container=public'),
      '${ApplicationRoutesConstants.login}?returnUrl=%2Fbrowse%2Fseed%3Apg%2Fkinds%3Fcontainer%3Dpublic',
    );
  });
}
