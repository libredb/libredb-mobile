import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';

void main() {
  const secret = "SELECT * FROM customers WHERE email = 'ada@example.com'";
  const request = EditorOpenRequest(connectionId: 'seed:dev-postgres-server', text: secret, catalog: 'archive');

  test('prints the length of the statement, never the statement', () {
    expect(request.toString(), isNot(contains('customers')));
    expect(request.toString(), contains('${secret.length} characters'));
  });

  test('a delivery hands its request over once', () {
    final delivery = EditorOpenDelivery(request);

    expect(delivery.take(), request);
    expect(delivery.take(), isNull);
  });

  // go_router encodes the extra of every location it goes to for state restoration; the statement stays in memory.
  test('a delivery encodes as null, so the statement is never saved for state restoration', () {
    final delivery = EditorOpenDelivery(request);

    expect(json.encode(delivery), 'null');
    expect(delivery.toString(), isNot(contains('customers')));
    expect(delivery.take(), request);
  });
}
