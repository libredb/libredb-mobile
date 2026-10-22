import 'package:libredb_mobile/shared/utils/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Constants values", () {
    test('appName is LibreDB', () {
      expect(AppConstants.appName, 'LibreDB');
    });
    test('appVersion should be 1.0.0', () {
      expect(AppConstants.appVersion, '1.0.0');
    });
  });
}
