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

  test('cancelled refuses an answer without the flag', () {
    expect(() => SqlEditorJson.cancelled('{"error":"x"}'), throwsFormatException);
  });
}
