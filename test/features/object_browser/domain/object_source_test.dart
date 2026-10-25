import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';

void main() {
  test('a SourceStatement prints its id and label and never its statement', () {
    const part = SourceStatement(id: 'body', label: 'Body', statement: 'The engine keeps no body for payroll_view');

    expect('$part', 'SourceStatement(body, Body)');
  });
}
