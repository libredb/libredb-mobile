import 'package:flutter_bloc_advance/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('queryResult', () {
    test('a result inside a script has no paging; warnings and a rolled-back transaction are kept', () {
      final result = SqlEditorJson.queryResult(
        '{"rows":[],"fields":["n"],"rowCount":0,"executionTime":0.5,"openTransaction":"rolled-back",'
        '"warnings":[{"message":"table does not exist, skipping","code":"00000","severity":"NOTICE"},{"code":1}]}',
      );

      expect(result.pagination, isNull);
      expect(result.openTransactionRolledBack, isTrue);
      expect(result.executionTime, const Duration(microseconds: 500));
      expect(result.warnings.single.message, 'table does not exist, skipping');
    });

    test('refuses an answer without fields, rows or a row count', () {
      for (final body in [
        '{"rows":[],"rowCount":0,"executionTime":1}',
        '{"fields":[],"rowCount":0,"executionTime":1}',
        '{"rows":[],"fields":[],"executionTime":1}',
        '{"rows":[1],"fields":[],"rowCount":0,"executionTime":1}',
      ]) {
        expect(() => SqlEditorJson.queryResult(body), throwsFormatException, reason: body);
      }
    });
  });

  test('scriptResult gives a failed statement without a message a generic one', () {
    final script = SqlEditorJson.scriptResult(
      '{"statements":[{"index":0,"sql":"x","startLine":1,"status":"error","executionTime":1}],'
      '"statementCount":1,"executedCount":1,"executionTime":1}',
    );

    expect(script.statements.single.error, 'The statement failed');
    expect(script.hasError, isTrue);
  });

  test('transactionRun reads several statements as a script', () {
    final run = SqlEditorJson.transactionRun(
      '{"inTransaction":false,"multiStatement":true,"statements":[],"statementCount":2,"executedCount":2,'
      '"executionTime":3}',
    );

    expect(run.inTransaction, isFalse);
    expect(run.script?.statementCount, 2);
    expect(run.result, isNull);
  });

  test('transactionBegun is null when the engine never reports its state', () {
    expect(SqlEditorJson.transactionBegun('{"status":"active","stateReported":null}'), isNull);
  });

  test('cancelled refuses an answer without the flag', () {
    expect(() => SqlEditorJson.cancelled('{"error":"x"}'), throwsFormatException);
  });
}
