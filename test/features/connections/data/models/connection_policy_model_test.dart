import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_policy_model.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';

void main() {
  for (final capture in ['none', 'redacted', 'full']) {
    test('reads statementCapture $capture under governance', () {
      final policy = ConnectionPolicyModel.fromJsonString(
        '{"customConnections":false,"governance":true,"statementCapture":"$capture"}',
      );

      expect(policy, ConnectionPolicy(customConnections: false, governance: true, statementCapture: capture));
    });
  }

  test('reads no statementCapture without governance', () {
    final policy = ConnectionPolicyModel.fromJsonString('{"customConnections":true}');

    expect(policy, const ConnectionPolicy(customConnections: true, governance: false));
  });

  test('leaves out a statementCapture that is not a string', () {
    final policy = ConnectionPolicyModel.fromJsonString(
      '{"customConnections":false,"governance":true,"statementCapture":1}',
    );

    expect(policy.statementCapture, isNull);
  });

  test('only full records statements in full', () {
    expect(ConnectionPolicy.statementCaptureFull, 'full');
  });

  test('throws a FormatException without customConnections', () {
    expect(() => ConnectionPolicyModel.fromJsonString('{"governance":true}'), throwsFormatException);
  });
}
