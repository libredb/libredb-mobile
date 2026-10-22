import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';

void main() {
  test("labels the environments as Studio's sidebar does", () {
    expect(StudioEnvironment.label('production'), 'PROD');
    expect(StudioEnvironment.label('staging'), 'STAGING');
    expect(StudioEnvironment.label('development'), 'DEV');
    expect(StudioEnvironment.label('local'), 'LOCAL');
  });

  test('has no badge label for other, which Studio hides', () {
    expect(StudioEnvironment.label('other'), isNull);
  });

  test('shows an environment Studio did not name as it was sent', () {
    expect(StudioEnvironment.label('qa'), 'qa');
  });
}
