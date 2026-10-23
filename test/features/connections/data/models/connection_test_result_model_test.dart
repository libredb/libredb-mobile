import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_test_result_model.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';

/// `POST /api/db/test-connection` answers `warnings?: QueryWarning[]` on both success shapes (libredb-studio
/// `src/lib/api/test-connection.ts:28-29`), such as Materialize opening a database that does not exist.
void main() {
  group('ConnectionTestResultModel warnings', () {
    test('reads each warning with its message, code and severity', () {
      final result = ConnectionTestResultModel.fromJsonString(
        '{"success":true,"message":"Connection successful","latency":12,"warnings":['
        '{"message":"database \\"nope\\" does not exist","code":"MZ001","severity":"notice"},'
        '{"message":"index not ready","code":4100},'
        '{"message":"checks did not finish"}]}',
      );

      expect(result.warnings, const [
        QueryWarning(message: 'database "nope" does not exist', code: 'MZ001', severity: 'notice'),
        QueryWarning(message: 'index not ready', code: '4100'),
        QueryWarning(message: 'checks did not finish'),
      ]);
    });

    test('reads the warnings of a degraded answer', () {
      final result = ConnectionTestResultModel.fromJsonString(
        '{"success":true,"degraded":true,"message":"no health","warnings":[{"message":"careful"}]}',
      );

      expect(
        result,
        const ConnectionTestResult(
          message: 'no health',
          degraded: true,
          warnings: [QueryWarning(message: 'careful')],
        ),
      );
    });

    test('reads none when Studio sends none', () {
      final result = ConnectionTestResultModel.fromJsonString(
        '{"success":true,"message":"Connection successful","latency":12}',
      );

      expect(result.warnings, isEmpty);
    });

    test('leaves out an entry without a string message, and a code or severity of an unexpected type', () {
      final result = ConnectionTestResultModel.fromJsonString(
        '{"success":true,"message":"Connection successful","latency":12,"warnings":['
        '{"code":"X1"},{"message":7},"not an object",null,'
        '{"message":"kept","code":{"a":1},"severity":3}]}',
      );

      expect(result.warnings, const [QueryWarning(message: 'kept')]);
    });

    test('reads none when warnings is not a list', () {
      final result = ConnectionTestResultModel.fromJsonString(
        '{"success":true,"message":"Connection successful","latency":12,"warnings":"x"}',
      );

      expect(result.warnings, isEmpty);
    });
  });
}
