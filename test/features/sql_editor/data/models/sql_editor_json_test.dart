import 'package:libredb_mobile/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scriptResult reads the loss notices of each statement strictly', () {
    const page = '"limit":1,"offset":0,"hasMore":false,"totalReturned":1';
    String script(String statementMore, {String scriptMore = ''}) =>
        '{"statements":[{"index":0,"sql":"x","startLine":1,"status":"success","rows":[{"n":1}],"fields":["n"],'
        '"rowCount":1,"executionTime":1$statementMore}],"statementCount":1,"executedCount":1,"executionTime":1'
        '$scriptMore}';

    final malformed = {
      'a wasLimited string': ',"pagination":{$page,"wasLimited":"true"}',
      'a pagination string': ',"pagination":"none"',
      'a warnings object': ',"warnings":{"message":"x"}',
      'a warning without message': ',"warnings":[{"code":1}]',
      'an openTransaction of committed': ',"openTransaction":"committed"',
    };
    for (final MapEntry(key: name, value: more) in malformed.entries) {
      test('$name in a statement fails the read', () {
        expect(() => SqlEditorJson.scriptResult(script(more)), throwsFormatException);
      });
    }

    test('an openTransaction of committed on the script fails the read', () {
      expect(
        () => SqlEditorJson.scriptResult(script('', scriptMore: ',"openTransaction":"committed"')),
        throwsFormatException,
      );
    });

    test('a statement without them reads as before, with its warnings and column types', () {
      final result = SqlEditorJson.scriptResult(
        script(',"warnings":[{"message":"m","severity":"NOTICE"}],"columnTypes":{"n":"int4"}'),
      ).statements.single.result!;

      expect(result.rows, [
        {'n': 1},
      ]);
      expect(result.warnings.single.message, 'm');
      expect(result.columnTypes, {'n': 'int4'});
      expect(result.pagination, isNull);
      expect(SqlEditorJson.scriptResult(script('')).openTransactionRolledBack, isFalse);
      expect(
        SqlEditorJson.scriptResult(script('', scriptMore: ',"openTransaction":"rolled-back"'))
            .openTransactionRolledBack,
        isTrue,
      );
    });
  });

  test('transactionRun of one statement reads its loss notices strictly', () {
    expect(
      () => SqlEditorJson.transactionRun(
        '{"inTransaction":true,"rows":[],"fields":[],"rowCount":0,"executionTime":1,"warnings":"none"}',
      ),
      throwsFormatException,
    );
  });

  test('scriptResult gives a failed statement without a message a generic one', () {
    final script = SqlEditorJson.scriptResult(
      '{"statements":[{"index":0,"sql":"x","startLine":1,"status":"error","executionTime":1}],'
      '"statementCount":1,"executedCount":1,"executionTime":1}',
    );

    expect(script.statements.single.error, 'The statement failed');
    expect(script.hasError, isTrue);
  });

  group('scriptResult reads each statement for its card', () {
    String statement(String fields) =>
        '{"statements":[{"index":2,"sql":"SELECT 3","startLine":4,$fields}],"statementCount":4,"executedCount":3,'
        '"executionTime":9}';

    test('a success with its index, text, line, time, row count and rows', () {
      final script = SqlEditorJson.scriptResult(
        statement('"status":"success","rows":[{"n":3}],"fields":["n"],"rowCount":3,"executionTime":7'),
      );
      final read = script.statements.single;

      expect(read.index, 2);
      expect(read.sql, 'SELECT 3');
      expect(read.startLine, 4);
      expect(read.executionTime, const Duration(milliseconds: 7));
      expect(read.rowCount, 3);
      expect(read.result?.rowCount, 3);
      expect(read.result?.rows, [
        {'n': 3},
      ]);
      expect(read.error, isNull);
      expect(script.statementCount, 4);
      expect(script.executedCount, 3);
      expect(script.executionTime, const Duration(milliseconds: 9));
      expect(script.hasError, isFalse);
    });

    test('a write that answered no rows keeps its row count', () {
      final read = SqlEditorJson.scriptResult(
        statement('"status":"success","rows":[],"fields":[],"rowCount":2,"executionTime":1'),
      ).statements.single;

      expect(read.rowCount, 2);
      expect(read.result?.rows, isEmpty);
    });

    test("a failure with the database's words and no row count", () {
      final read = SqlEditorJson.scriptResult(
        statement('"status":"error","executionTime":2,"error":"relation \\"nope\\" does not exist"'),
      ).statements.single;

      expect(read.error, 'relation "nope" does not exist');
      expect(read.rowCount, isNull);
      expect(read.result, isNull);
    });

    final unreadable = {
      'a string row count': '"rowCount":"3"',
      'a fractional row count': '"rowCount":3.5',
      'a null row count': '"rowCount":null',
      'no row count': '',
    };
    for (final MapEntry(key: name, value: rowCount) in unreadable.entries) {
      test('$name on a success fails the read', () {
        final more = rowCount.isEmpty ? '' : ',$rowCount';
        expect(
          () => SqlEditorJson.scriptResult(
            statement('"status":"success","rows":[{"n":3}],"fields":["n"],"executionTime":7$more'),
          ),
          throwsFormatException,
        );
      });
    }
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

  test('transactionCommitted reads the answer Studio sends after a commit', () {
    expect(
      () => SqlEditorJson.transactionCommitted('{"status":"committed","message":"Transaction committed"}'),
      returnsNormally,
    );
  });

  test('transactionRolledBack reads the answer Studio sends after a rollback', () {
    expect(
      () => SqlEditorJson.transactionRolledBack('{"status":"rolled_back","message":"Transaction rolled back"}'),
      returnsNormally,
    );
  });

  test('transactionCommitted and transactionRolledBack refuse any other status, or none', () {
    for (final body in ['{"message":"Transaction ended"}', '{"status":1}', '{"status":"active"}', '[]', 'not json']) {
      expect(() => SqlEditorJson.transactionCommitted(body), throwsFormatException, reason: body);
      expect(() => SqlEditorJson.transactionRolledBack(body), throwsFormatException, reason: body);
    }
    expect(() => SqlEditorJson.transactionCommitted('{"status":"rolled_back"}'), throwsFormatException);
    expect(() => SqlEditorJson.transactionRolledBack('{"status":"committed"}'), throwsFormatException);
  });
}
