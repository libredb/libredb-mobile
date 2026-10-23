import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/active_connection/default_catalog.dart';

void main() {
  const listed = ['app', 'archive', 'postgres'];

  test('the wanted database while the server still lists it', () {
    expect(defaultCatalog(listed: listed, wanted: 'archive'), 'archive');
  });

  test('the first listed when the server no longer lists the wanted one', () {
    expect(defaultCatalog(listed: listed, wanted: 'gone'), 'app');
  });

  test('the first listed when none is wanted', () {
    expect(defaultCatalog(listed: listed), 'app');
  });

  test('none when the server lists none', () {
    expect(defaultCatalog(listed: const [], wanted: 'archive'), isNull);
    expect(defaultCatalog(listed: const []), isNull);
  });
}
