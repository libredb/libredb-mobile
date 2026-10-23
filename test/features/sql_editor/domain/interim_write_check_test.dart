import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';

import '../../../support/printed_lines.dart';

const _check = InterimWriteCheck();

WriteCheckAnswer _sql(String text) => _check.check(text, isSql: true);

const _mayWrite = {WriteCheckReason.mayWrite};
const _several = {WriteCheckReason.severalStatements};
const _mayWriteAndSeveral = {WriteCheckReason.mayWrite, WriteCheckReason.severalStatements};

Matcher _asks(Set<WriteCheckReason> reasons, {String? word, int? line}) => equals(
  AsksBeforeRunning(
    reasons: reasons,
    flaggedWord: word == null ? null : FlaggedWord(word: word, line: line!),
  ),
);

void main() {
  group('runs without asking', () {
    for (final text in [
      'SELECT * FROM orders',
      'WITH t AS (SELECT 1) SELECT * FROM t',
      'EXPLAIN SELECT 1',
      'SHOW search_path',
      'SELECT deleted FROM t',
      "SELECT REPLACE(name, 'a', 'b') FROM t",
      "SELECT 'unterminated",
      r'SELECT $$x$$',
      'SELECT 1 # x',
      'select * from orders',
      'DESCRIBE orders',
      'desc orders',
      'VALUES (1), (2)',
      'TABLE orders',
      'SELECT 1;',
      'SELECT 1;  \n\t ',
      '-- a note\nSELECT 1',
      '/* a note */ SELECT 1',
      '/* one */ /* two */\n-- three\r  SELECT 1',
      '/* SELECT * not closed here * / still */SELECT 1',
      'SELECT updated_at, created_by, inserted, sets, intot FROM t',
      'SELECT go FROM t',
      'SELECT 1\n GOTO\n',
      'SELECT 4 / 2',
      'SELECT 1\n//\n',
      // The accepted limits: the check reads keywords, not what a called function does.
      'SELECT pg_terminate_backend(42)',
      "SELECT nextval('s')",
      'SELECT setval(1)',
    ]) {
      test(text.replaceAll('\n', r'\n').replaceAll('\r', r'\r'), () => expect(_sql(text), const RunsWithoutAsking()));
    }
  });

  group('asks with may write and names the first deny word', () {
    final cases = <String, (String, int)>{
      'DELETE FROM orders': ('DELETE', 1),
      'insert into t values (1)': ('INSERT', 1),
      'select 1 -- delete': ('DELETE', 1),
      r'SELECT x$delete FROM t': ('DELETE', 1),
      'SELECT çdelete FROM t': ('DELETE', 1),
      'WITH d AS (DELETE FROM t RETURNING *) SELECT * FROM d': ('DELETE', 1),
      'WITH m AS (MERGE INTO t USING s ON true WHEN MATCHED THEN DELETE) SELECT 1': ('MERGE', 1),
      'WITH u AS (UPDATE t SET a = 1 RETURNING *) SELECT * FROM u': ('UPDATE', 1),
      'WITH i AS (INSERT INTO t VALUES (1) RETURNING *) SELECT * FROM i': ('INSERT', 1),
      'EXPLAIN ANALYZE DELETE FROM t': ('ANALYZE', 1),
      'EXPLAIN (ANALYZE) SELECT 1': ('ANALYZE', 1),
      'EXPLAIN (FORMAT JSON, ANALYZE) SELECT 1': ('ANALYZE', 1),
      'EXPLAIN ANALYSE SELECT 1': ('ANALYSE', 1),
      'explain (analyze true) select 1': ('ANALYZE', 1),
      'SELECT 1 KILL 52': ('KILL', 1),
      "SELECT * FROM t /*!50000 INTO OUTFILE '/tmp/x' */": ('INTO', 1),
      "SELECT 1 /*M!100000 INTO OUTFILE '/tmp/x' */": ('INTO', 1),
      "SELECT 1 --1 INTO OUTFILE '/tmp/f'": ('INTO', 1),
      "SELECT * FROM audit WHERE op = 'DELETE'": ('DELETE', 1),
      'SELECT * FROM t WHERE x = "drop"': ('DROP', 1),
      'SELECT "Delete" FROM t': ('DELETE', 1),
      'SELECT 1 /* update */': ('UPDATE', 1),
      'SELECT 1 /*/ delete /*/': ('DELETE', 1),
      '-- c\nDROP TABLE users': ('DROP', 2),
      'SELECT 1\nFROM t\nWHERE DELETE': ('DELETE', 3),
      'SELECT 1\r\nFROM t\r\n-- DELETE': ('DELETE', 3),
      'SELECT 1\rFROM t\rDELETE': ('DELETE', 3),
      'SeLeCt 1 FrOm t WhErE x In (sElEcT 1) dElEtE': ('DELETE', 1),
      'SELECT * INTO new_t FROM t': ('INTO', 1),
      'SELECT 1 FOR UPDATE': ('UPDATE', 1),
      'SELECT 1 LOCK': ('LOCK', 1),
      r'WITH x AS (SELECT 1) DO $$ BEGIN END $$': ('DO', 1),
      'SELECT pg_sleep(1) EXEC sp_who': ('EXEC', 1),
      'SELECT 1 SHUTDOWN': ('SHUTDOWN', 1),
      'SELECT 1 DBCC CHECKDB': ('DBCC', 1),
    };
    for (final MapEntry(key: text, value: (word, line)) in cases.entries) {
      test(text.replaceAll('\n', r'\n').replaceAll('\r', r'\r'), () {
        expect(_sql(text), _asks(_mayWrite, word: word, line: line));
      });
    }
  });

  group('every deny word asks, in any ASCII case and as a whole word only', () {
    for (final word in InterimWriteCheck.denyWords) {
      test(word, () {
        expect(_sql('SELECT 1 $word'), _asks(_mayWrite, word: word, line: 1));
        expect(_sql('SELECT 1 ${word.toLowerCase()}'), _asks(_mayWrite, word: word, line: 1));
        expect(_sql('SELECT 1 (${word[0]}${word.substring(1).toLowerCase()})'), _asks(_mayWrite, word: word, line: 1));
        expect(_sql('SELECT 1 x${word}x, ${word}_1, _$word, ${word}9'), const RunsWithoutAsking());
      });
    }

    test('holds the deny list of the issue, without REPLACE', () {
      expect(InterimWriteCheck.denyWords, {
        'INSERT', 'UPDATE', 'DELETE', 'MERGE', 'UPSERT', 'TRUNCATE', 'DROP', 'ALTER', 'CREATE', 'GRANT', 'REVOKE', //
        'DENY', 'CALL', 'EXEC', 'EXECUTE', 'DO', 'COPY', 'LOCK', 'SET', 'RESET', 'COMMIT', 'ROLLBACK', 'BEGIN', //
        'VACUUM', 'REINDEX', 'CLUSTER', 'REFRESH', 'INTO', 'ANALYZE', 'ANALYSE', 'KILL', 'SHUTDOWN', 'BACKUP', //
        'RESTORE', 'DBCC', 'RECONFIGURE', 'DISABLE', 'ENABLE', 'SEND', 'RECEIVE', 'WRITETEXT', 'UPDATETEXT', //
        'SETUSER',
      });
      expect(InterimWriteCheck.denyWords, isNot(contains('REPLACE')));
    });

    test('a non-ASCII letter is no part of a word, so it does not hide a deny word', () {
      expect(_sql('SELECT çdeleteç FROM t'), _asks(_mayWrite, word: 'DELETE', line: 1));
      expect(_sql('SELECT ıdrop FROM t'), _asks(_mayWrite, word: 'DROP', line: 1));
    });

    test('a non-ASCII case fold is not read as a deny word', () {
      // `ı` (dotless i) upper-cases to `I` in Turkish, but only ASCII case is folded, so `ınsert` holds no INSERT.
      expect(_sql('SELECT ınsert FROM t'), const RunsWithoutAsking());
    });
  });

  group('the first keyword', () {
    test('a first keyword off the allow list asks and is named with its line', () {
      expect(_sql('PRAGMA user_version = 5'), _asks(_mayWrite, word: 'PRAGMA', line: 1));
      expect(_sql('-- c\n/* d\n*/ pragma user_version'), _asks(_mayWrite, word: 'PRAGMA', line: 3));
      expect(_sql('USE other_db'), _asks(_mayWrite, word: 'USE', line: 1));
      expect(_sql('LOAD DATA'), _asks(_mayWrite, word: 'LOAD', line: 1));
    });

    test('a deny word is named before a first keyword off the allow list', () {
      expect(_sql('PRAGMA x;\n'), _asks(_mayWrite, word: 'PRAGMA', line: 1));
      expect(_sql('RENAME t TO u -- delete'), _asks(_mayWrite, word: 'DELETE', line: 1));
    });

    test('a leading comment that never closes leaves no first keyword and asks without a word', () {
      expect(_sql('/* open comment SELECT 1'), _asks(_mayWrite));
      expect(_sql('/* open comment */ /* SELECT 1'), _asks(_mayWrite));
    });

    test('a text with nothing but comments or white space has no first keyword and asks', () {
      expect(_sql(''), _asks(_mayWrite));
      expect(_sql('  \n\t'), _asks(_mayWrite));
      expect(_sql('-- only a comment'), _asks(_mayWrite));
      expect(_sql('/* only */'), _asks(_mayWrite));
    });

    test('a text that starts with something other than a word or a comment has no first keyword and asks', () {
      expect(_sql('(SELECT 1)'), _asks(_mayWrite));
      expect(_sql('# c\nSELECT 1'), _asks(_mayWrite));
      expect(_sql('"SELECT" 1'), _asks(_mayWrite));
    });

    test('a `--` comment ends at a line feed or a carriage return', () {
      expect(_sql('-- c\rSELECT 1'), const RunsWithoutAsking());
      expect(_sql('-- c\nSELECT 1'), const RunsWithoutAsking());
      expect(_sql('-- c\r\nSELECT 1'), const RunsWithoutAsking());
      expect(_sql('--c\nSELECT 1'), const RunsWithoutAsking());
    });

    test('a `/* */` comment is read flat and ends at the first `*/`', () {
      expect(_sql('/* a /* b */ SELECT 1'), const RunsWithoutAsking());
      expect(_sql('/* a /* b */ c */ SELECT 1'), _asks(_mayWrite, word: 'C', line: 1));
      expect(_sql('/**/SELECT 1'), const RunsWithoutAsking());
    });

    test('a keyword in a leading comment is no first keyword', () {
      expect(_sql('-- SELECT\nPRAGMA x'), _asks(_mayWrite, word: 'PRAGMA', line: 2));
      expect(_sql('/* SELECT */ PRAGMA x'), _asks(_mayWrite, word: 'PRAGMA', line: 1));
    });

    test('a word that only starts with an allowed keyword is not that keyword', () {
      expect(_sql('SELECTX 1'), _asks(_mayWrite, word: 'SELECTX', line: 1));
      expect(_sql('WITHOUT 1'), _asks(_mayWrite, word: 'WITHOUT', line: 1));
      expect(_sql('select_all()'), _asks(_mayWrite, word: 'SELECT_ALL', line: 1));
    });
  });

  group('several statements', () {
    test('a `;` followed by more text asks', () {
      expect(_sql('SELECT 1; DELETE FROM t'), _asks(_mayWriteAndSeveral, word: 'DELETE', line: 1));
      expect(_sql("SELECT 'a;b'; DROP TABLE t"), _asks(_mayWriteAndSeveral, word: 'DROP', line: 1));
      expect(_sql("SELECT 'a;b'"), _asks(_several));
      expect(_sql('SELECT 1; SELECT 2'), _asks(_several));
      expect(_sql('SELECT 1;;'), _asks(_several));
      expect(_sql('SELECT 1; -- done'), _asks(_several));
      expect(_sql('SELECT 1 -- a;b'), _asks(_several));
    });

    test('a bare carriage return ending a `--` comment does not hide a second statement', () {
      expect(_sql('SELECT 1 -- x\r; DELETE FROM t'), _asks(_mayWriteAndSeveral, word: 'DELETE', line: 2));
    });

    test('a line holding only GO or only / asks, trimmed and in any case', () {
      expect(_sql('SELECT 1\nGO\nSELECT 2'), _asks(_several));
      expect(_sql('SELECT 1\n  go  \nSELECT 2'), _asks(_several));
      expect(_sql('SELECT 1\r\nGo\r\n'), _asks(_several));
      expect(_sql('SELECT 1\rGO'), _asks(_several));
      expect(_sql('SELECT 1\n/\nSELECT 2'), _asks(_several));
      expect(_sql('SELECT 1\n\t/ \n'), _asks(_several));
      expect(_sql('SELECT 1\nGO\nDELETE FROM t'), _asks(_mayWriteAndSeveral, word: 'DELETE', line: 3));
    });

    test('GO or / beside other text on its line is not a separator', () {
      expect(_sql('SELECT 1\nGO 2'), const RunsWithoutAsking());
      expect(_sql('SELECT 1 /\n2'), const RunsWithoutAsking());
    });
  });

  group('not SQL', () {
    for (final text in ['GET k', 'KEYS *', 'DEL k', '{"find": "users"}', 'up', '', 'SELECT 1']) {
      test('"$text" asks with not SQL only', () {
        expect(_check.check(text, isSql: false), _asks({WriteCheckReason.notSql}));
      });
    }
  });

  test('the answer names the word and the line, never the statement', () {
    final answer = _sql('SELECT secret_value FROM t\nWHERE x = 1 DELETE');
    expect(answer.toString(), isNot(contains('secret_value')));
    expect(answer, _asks(_mayWrite, word: 'DELETE', line: 2));
  });

  test('a long text is read whole, so a write far down is found', () {
    final text = '${List.filled(19999, 'SELECT 1').join('\n')}\nDELETE FROM t';
    expect(_sql(text), _asks(_mayWrite, word: 'DELETE', line: 20000));
  });

  test('the check logs nothing', () async {
    final lines = await printedLines(() {
      _sql('SELECT 1; DELETE FROM t');
      _sql('SELECT 1');
      _check.check('GET k', isSql: false);
    });
    expect(lines, isEmpty);
  });

  group('statementLines', () {
    test('splits at a line feed, a carriage return and a CRLF pair, as the check counts lines', () {
      expect(statementLines('a\nb\rc\r\nd'), ['a', 'b', 'c', 'd']);
      expect(statementLines(''), ['']);
      expect(statementLines('a\n'), ['a', '']);
      expect(statementLines('a\r\n\r\nb'), ['a', '', 'b']);
    });
  });
}
