import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';

void main() {
  test('toString prints the flags and leaves out the statementCapture and the props', () {
    const policy = ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'full');

    expect('$policy', 'ConnectionPolicy(customConnections: false, governance: true)');
  });
}
