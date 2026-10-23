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

/// The 94 built-ins the #111 body lists as deny words, a closed list.
const _builtInDenyWords = {
  'DBLINK',
  'DBLINK_EXEC',
  'DBLINK_SEND_QUERY',
  'DBLINK_OPEN',
  'QUERY_TO_XML',
  'QUERY_TO_XML_AND_XMLSCHEMA',
  'QUERY_TO_XMLSCHEMA',
  'DBLINK_FETCH',
  'DBLINK_CLOSE',
  'DBLINK_CONNECT',
  'DBLINK_CONNECT_U',
  'DBLINK_DISCONNECT',
  'DBLINK_CANCEL_QUERY',
  'LO_CREAT',
  'LO_CREATE',
  'LO_FROM_BYTEA',
  'LO_PUT',
  'LOWRITE',
  'LO_TRUNCATE',
  'LO_TRUNCATE64',
  'LO_UNLINK',
  'LO_IMPORT',
  'LO_EXPORT',
  'PG_ADVISORY_LOCK',
  'PG_ADVISORY_LOCK_SHARED',
  'PG_ADVISORY_UNLOCK',
  'PG_ADVISORY_UNLOCK_SHARED',
  'PG_ADVISORY_UNLOCK_ALL',
  'PG_ADVISORY_XACT_LOCK',
  'PG_ADVISORY_XACT_LOCK_SHARED',
  'PG_TRY_ADVISORY_LOCK',
  'PG_TRY_ADVISORY_LOCK_SHARED',
  'PG_TRY_ADVISORY_XACT_LOCK',
  'PG_TRY_ADVISORY_XACT_LOCK_SHARED',
  'PG_TERMINATE_BACKEND',
  'PG_CANCEL_BACKEND',
  'SET_CONFIG',
  'SETVAL',
  'NEXTVAL',
  'LOAD_EXTENSION',
  'PG_NOTIFY',
  'PG_RELOAD_CONF',
  'PG_ROTATE_LOGFILE',
  'PG_LOG_BACKEND_MEMORY_CONTEXTS',
  'PG_BACKUP_START',
  'PG_BACKUP_STOP',
  'PG_START_BACKUP',
  'PG_STOP_BACKUP',
  'PG_CREATE_RESTORE_POINT',
  'PG_SWITCH_WAL',
  'PG_PROMOTE',
  'PG_WAL_REPLAY_PAUSE',
  'PG_WAL_REPLAY_RESUME',
  'PG_LOG_STANDBY_SNAPSHOT',
  'PG_CREATE_PHYSICAL_REPLICATION_SLOT',
  'PG_CREATE_LOGICAL_REPLICATION_SLOT',
  'PG_COPY_PHYSICAL_REPLICATION_SLOT',
  'PG_COPY_LOGICAL_REPLICATION_SLOT',
  'PG_DROP_REPLICATION_SLOT',
  'PG_REPLICATION_SLOT_ADVANCE',
  'PG_LOGICAL_SLOT_GET_CHANGES',
  'PG_LOGICAL_SLOT_GET_BINARY_CHANGES',
  'PG_SYNC_REPLICATION_SLOTS',
  'PG_REPLICATION_ORIGIN_CREATE',
  'PG_REPLICATION_ORIGIN_DROP',
  'PG_REPLICATION_ORIGIN_ADVANCE',
  'PG_REPLICATION_ORIGIN_SESSION_SETUP',
  'PG_REPLICATION_ORIGIN_SESSION_RESET',
  'PG_REPLICATION_ORIGIN_XACT_SETUP',
  'PG_REPLICATION_ORIGIN_XACT_RESET',
  'PG_LOGICAL_EMIT_MESSAGE',
  'BRIN_SUMMARIZE_NEW_VALUES',
  'BRIN_SUMMARIZE_RANGE',
  'BRIN_DESUMMARIZE_RANGE',
  'GIN_CLEAN_PENDING_LIST',
  'PG_STAT_RESET',
  'PG_STAT_RESET_SHARED',
  'PG_STAT_RESET_SINGLE_TABLE_COUNTERS',
  'PG_STAT_RESET_SINGLE_FUNCTION_COUNTERS',
  'PG_STAT_RESET_SLRU',
  'PG_STAT_RESET_REPLICATION_SLOT',
  'PG_STAT_RESET_SUBSCRIPTION_STATS',
  'PG_IMPORT_SYSTEM_COLLATIONS',
  'PG_FILE_WRITE',
  'PG_FILE_RENAME',
  'PG_FILE_UNLINK',
  'PG_FILE_SYNC',
  'GET_LOCK',
  'RELEASE_LOCK',
  'RELEASE_ALL_LOCKS',
  r'SYSTEM$ABORT_SESSION',
  r'SYSTEM$ABORT_TRANSACTION',
  r'SYSTEM$CANCEL_QUERY',
  r'SYSTEM$CANCEL_ALL_QUERIES',
};

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
      '/* one */ /* two */\n-- three\r\n  SELECT 1',
      '/***/SELECT 1',
      '/*+ hint */ SELECT 1',
      '-- c\tx\nSELECT 1',
      '/* SELECT * not closed here * / still */SELECT 1',
      'SELECT updated_at, created_by, inserted, sets, intot FROM t',
      'SELECT go FROM t',
      'SELECT 1\n GOTO\n',
      'SELECT 4 / 2',
      'SELECT 1\n//\n',
      // The accepted limit: the check reads words, not what a user-defined function does.
      "SELECT my_func('c', 'DR' || 'OP TABLE t')",
      // A built-in deny word inside a longer name is no deny word.
      'SELECT my_nextval_col, setval_x, xdblink, lo_export_2 FROM t',
      // The read-only dblink helpers are not deny words.
      'SELECT dblink_get_connections()',
      "SELECT IS_FREE_LOCK('m')",
      // A `$` matches only itself inside a SYSTEM$ deny word, so other SYSTEM$ calls and names around them run.
      r"SELECT SYSTEM$TYPEOF(1), SYSTEM$ABORT_SESSIONS, SYSTEM_ABORT_SESSION(1), x_SYSTEM$CANCEL_QUERY",
      // The administration reads are not deny words.
      "SELECT current_setting('x'), pg_current_wal_lsn(), pg_walfile_name('0/0'), pg_is_in_recovery()",
      'SELECT pg_export_snapshot(), pg_stat_clear_snapshot(), pg_size_pretty(1), pg_logdir_ls()',
      "SELECT * FROM pg_logical_slot_peek_changes('s', NULL, NULL)",
      "SELECT pg_replication_origin_progress('o', true), pg_read_file('f')",
      "SELECT dblink_error_message('c'), dblink_is_busy('c'), dblink_get_pkey('t')",
      "SELECT * FROM dblink_get_result('c') AS t(a int)",
      'SELECT * FROM dblink_get_notify()',
      "SELECT dblink_build_sql_insert('t', '1', 1, '{1}', '{1}')",
      // A run that starts with a digit asks only when it holds a deny word.
      'SELECT 0x1F',
      'SELECT 1e5',
      'SELECT 0xDEADBEEF, 12345, 1_000, 3.14e-2',
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
      // A digit does not hide a deny word: T-SQL reads `1DELETE` as the number 1 and a DELETE.
      'SELECT 1DELETE FROM orders': ('DELETE', 1),
      'SELECT 1.0DELETE FROM orders': ('DELETE', 1),
      'SELECT 0x1DELETE FROM orders': ('DELETE', 1),
      'SELECT 1KILL 52': ('KILL', 1),
      'SELECT 1e1drop TABLE t': ('DROP', 1),
      'SELECT x1DELETE FROM t': ('DELETE', 1),
      // In a run that starts with a digit every deny word matches wherever it sits: T-SQL ends a number at the first
      // character that cannot continue it, so `0xKILL` is the empty binary `0x` and KILL.
      'SELECT 0xKILL 52': ('KILL', 1),
      'SELECT 1eKILL 52': ('KILL', 1),
      'SELECT 1xDELETEx FROM t': ('DELETE', 1),
      'SELECT 9_drop_ FROM t': ('DROP', 1),
      'SELECT 1SETUSERx': ('SETUSER', 1),
      'SELECT 0xSET_CONFIGx': ('SET_CONFIG', 1),
      // The built-ins that run statement text, touch server files, end other sessions, change settings or sequences,
      // take locks or load code.
      "SELECT nextval('s')": ('NEXTVAL', 1),
      "SELECT dblink_exec('dbname=app', chr(68) || 'ELETE FROM orders')": ('DBLINK_EXEC', 1),
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
        expect(_sql('SELECT 1 1$word'), _asks(_mayWrite, word: word, line: 1));
        expect(_sql('SELECT 1 0x9$word'), _asks(_mayWrite, word: word, line: 1));
      });
    }

    test('holds the deny list of the issue, without REPLACE', () {
      expect(InterimWriteCheck.denyWords, {
        ..._builtInDenyWords,
        'INSERT', 'UPDATE', 'DELETE', 'MERGE', 'UPSERT', 'TRUNCATE', 'DROP', 'ALTER', 'CREATE', 'GRANT', 'REVOKE', //
        'DENY', 'CALL', 'EXEC', 'EXECUTE', 'DO', 'COPY', 'LOCK', 'SET', 'RESET', 'COMMIT', 'ROLLBACK', 'BEGIN', //
        'VACUUM', 'REINDEX', 'CLUSTER', 'REFRESH', 'INTO', 'ANALYZE', 'ANALYSE', 'KILL', 'SHUTDOWN', 'BACKUP', //
        'RESTORE', 'DBCC', 'RECONFIGURE', 'DISABLE', 'ENABLE', 'SEND', 'RECEIVE', 'WRITETEXT', 'UPDATETEXT', //
        'SETUSER',
      });
      expect(InterimWriteCheck.denyWords, isNot(contains('REPLACE')));
    });

    group('the built-in deny words, one family at a time', () {
      final families = {
        'dblink, which runs statement text on another connection': [
          "SELECT * FROM dblink('c', 'SELECT 1') AS t(a int)",
          "SELECT dblink_exec('c', 'x')",
          "SELECT dblink_send_query('c', 'x')",
          "SELECT dblink_open('cur', 'x')",
        ],
        'the dblink calls that keep or end remote state': [
          "SELECT * FROM dblink_fetch('cur', 5) AS t(a int)",
          "SELECT dblink_close('cur')",
          "SELECT dblink_connect('c', 'dbname=app')",
          "SELECT dblink_connect_u('c', 'dbname=app')",
          "SELECT dblink_disconnect('c')",
          "SELECT dblink_cancel_query('c')",
        ],
        'the large objects, which move data between the database and a server file': [
          "SELECT lo_export(42, '/tmp/f')",
          "SELECT lo_import('/etc/passwd')",
          'SELECT lo_unlink(42)',
          "SELECT lo_put(42, 0, 'x')",
          "SELECT lo_from_bytea(0, 'x')",
          'SELECT lo_create(0)',
          'SELECT lo_creat(-1)',
          'SELECT lo_truncate(3, 0)',
          'SELECT lo_truncate64(3, 0)',
          "SELECT lowrite(3, 'x')",
        ],
        'query_to_xml, which runs statement text': [
          "SELECT query_to_xml('x', true, false, '')",
          "SELECT query_to_xmlschema('x', true, false, '')",
          "SELECT query_to_xml_and_xmlschema('x', true, false, '')",
        ],
        'the backend signals, which end or cancel another session': [
          'SELECT pg_terminate_backend(42)',
          'SELECT pg_cancel_backend(42)',
        ],
        'the advisory locks, taken or released, at session or transaction level': [
          'SELECT pg_advisory_lock(1)',
          'SELECT pg_advisory_lock_shared(1)',
          'SELECT pg_advisory_unlock(1)',
          'SELECT pg_advisory_unlock_shared(1)',
          'SELECT pg_advisory_unlock_all()',
          'SELECT pg_advisory_xact_lock(1)',
          'SELECT pg_advisory_xact_lock_shared(1)',
          'SELECT pg_try_advisory_lock(1)',
          'SELECT pg_try_advisory_lock_shared(1)',
          'SELECT pg_try_advisory_xact_lock(1)',
          'SELECT pg_try_advisory_xact_lock_shared(1)',
        ],
        'the settings and the sequences': [
          "SELECT set_config('x', 'y', false)",
          "SELECT setval('s', 1)",
          "SELECT nextval('s')",
        ],
        'load_extension, which loads code into SQLite': ["SELECT load_extension('x')"],
        'the notifications and the server signals': [
          "SELECT pg_notify('jobs', 'run')",
          'SELECT pg_reload_conf()',
          'SELECT pg_rotate_logfile()',
          'SELECT pg_log_backend_memory_contexts(42)',
        ],
        'backup, recovery and the WAL': [
          "SELECT pg_backup_start('l')",
          'SELECT pg_backup_stop()',
          "SELECT pg_start_backup('l')",
          'SELECT pg_stop_backup()',
          "SELECT pg_create_restore_point('p')",
          'SELECT pg_switch_wal()',
          'SELECT pg_promote()',
          'SELECT pg_wal_replay_pause()',
          'SELECT pg_wal_replay_resume()',
          'SELECT pg_log_standby_snapshot()',
        ],
        'the replication slots and origins': [
          "SELECT pg_create_physical_replication_slot('s')",
          "SELECT pg_create_logical_replication_slot('s', 'pgoutput')",
          "SELECT pg_copy_physical_replication_slot('s', 't')",
          "SELECT pg_copy_logical_replication_slot('s', 't')",
          "SELECT pg_drop_replication_slot('s')",
          "SELECT pg_replication_slot_advance('s', '0/0')",
          "SELECT pg_logical_slot_get_changes('s', NULL, NULL)",
          "SELECT pg_logical_slot_get_binary_changes('s', NULL, NULL)",
          'SELECT pg_sync_replication_slots()',
          "SELECT pg_replication_origin_create('o')",
          "SELECT pg_replication_origin_drop('o')",
          "SELECT pg_replication_origin_advance('o', '0/0')",
          "SELECT pg_replication_origin_session_setup('o')",
          'SELECT pg_replication_origin_session_reset()',
          "SELECT pg_replication_origin_xact_setup('0/0', now())",
          'SELECT pg_replication_origin_xact_reset()',
          "SELECT pg_logical_emit_message(true, 'p', 'm')",
        ],
        'the index maintenance': [
          "SELECT brin_summarize_new_values('i')",
          "SELECT brin_summarize_range('i', 0)",
          "SELECT brin_desummarize_range('i', 0)",
          "SELECT gin_clean_pending_list('i')",
        ],
        'the statistics resets': [
          'SELECT pg_stat_reset()',
          "SELECT pg_stat_reset_shared('io')",
          'SELECT pg_stat_reset_single_table_counters(1)',
          'SELECT pg_stat_reset_single_function_counters(1)',
          "SELECT pg_stat_reset_slru('x')",
          "SELECT pg_stat_reset_replication_slot('s')",
          'SELECT pg_stat_reset_subscription_stats(1)',
        ],
        'the MySQL and MariaDB named locks': [
          "SELECT GET_LOCK('m', 10)",
          "SELECT RELEASE_LOCK('m')",
          'SELECT RELEASE_ALL_LOCKS()',
        ],
        r'the Snowflake SYSTEM$ calls that end or cancel sessions, transactions or queries': [
          r'SELECT SYSTEM$ABORT_SESSION(1065153872298)',
          r'SELECT SYSTEM$ABORT_TRANSACTION(1530042321085)',
          r"SELECT SYSTEM$CANCEL_QUERY('01b2c3d4-0000-0000-0000-000000000001')",
          r'SELECT SYSTEM$CANCEL_ALL_QUERIES(1065153872298)',
        ],
        'the catalog and server file writes': [
          "SELECT pg_import_system_collations('pg_catalog')",
          "SELECT pg_file_write('f', 'x', false)",
          "SELECT pg_file_rename('f', 'g')",
          "SELECT pg_file_unlink('f')",
          "SELECT pg_file_sync('f')",
        ],
      };
      for (final MapEntry(key: family, value: texts) in families.entries) {
        test(family, () {
          for (final text in texts) {
            final name = RegExp(r'([A-Za-z_0-9$]+)\(').firstMatch(text.replaceFirst('SELECT * FROM ', 'SELECT '))![1]!;
            expect(_sql(text), _asks(_mayWrite, word: name.toUpperCase(), line: 1), reason: text);
          }
        });
      }
    });

    test('a non-ASCII letter is no part of a word, so it does not hide a deny word', () {
      expect(_sql('SELECT çdeleteç FROM t'), _asks(_mayWrite, word: 'DELETE', line: 1));
      expect(_sql('SELECT ıdrop FROM t'), _asks(_mayWrite, word: 'DROP', line: 1));
    });

    test(
      r'a SYSTEM$ deny word matches in any ASCII case, beside a digit or a non-letter, and is named with its `$`',
      () {
        expect(_sql(r'select system$cancel_query(1)'), _asks(_mayWrite, word: r'SYSTEM$CANCEL_QUERY', line: 1));
        expect(_sql(r'SELECT 1SYSTEM$ABORT_SESSION(1)'), _asks(_mayWrite, word: r'SYSTEM$ABORT_SESSION', line: 1));
        expect(
          _sql(r'SELECT a$SYSTEM$ABORT_TRANSACTION(1)'),
          _asks(_mayWrite, word: r'SYSTEM$ABORT_TRANSACTION', line: 1),
        );
      },
    );

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

    test('a leading `--` comment ends at a line feed, a CRLF pair included', () {
      expect(_sql('-- c\nSELECT 1'), const RunsWithoutAsking());
      expect(_sql('-- c\r\nSELECT 1'), const RunsWithoutAsking());
      expect(_sql('--\nSELECT 1'), const RunsWithoutAsking());
    });

    // A leading comment counts only when every engine reads it the same way; otherwise the text has no first keyword.
    group('a leading comment the engines read differently leaves no first keyword', () {
      final cases = [
        // PostgreSQL and SQL Server end `--` at a bare carriage return, SQLite, MySQL, MariaDB and DuckDB do not, so
        // either reading may hide the statement's real first keyword (measured on sqlite3 by review#111).
        '-- c\rSELECT 1',
        '-- x\rSELECT 1\nPRAGMA user_version = 5',
        "-- x\rSELECT 1\nATTACH DATABASE 'f' AS f",
        '-- a\r\n-- b\rSELECT 1\nPRAGMA x',
        '/* one */ /* two */\n-- three\r  SELECT 1',
        // PostgreSQL and SQL Server nest block comments, the others end at the first `*/` (both texts ran on
        // PostgreSQL 17.6 without asking before this rule).
        "/* /* */ SELECT 1 */ COMMENT ON TABLE orders IS 'x'",
        '/* /* */ SELECT 1 */ REASSIGN OWNED BY alice TO bob',
        "/* /* */ SELECT 1 */ xp_cmdshell 'whoami'",
        '/* a /* b */ SELECT 1',
        '/* a /* b */ c */ SELECT 1',
        '/*/ x /*/ SELECT 1',
        '-- c\n/* /* */ SELECT 1 */ PRAGMA x',
        // MySQL and MariaDB run the body of `/*!` and `/*M!`.
        '/*!RENAME*/ TABLE a TO b',
        '/*!50000 RENAME*/ TABLE a TO b',
        '/*M!RENAME*/ TABLE a TO b',
        '/*m!100000 RENAME*/ TABLE a TO b',
        '/* c */ /*!RENAME*/ TABLE a TO b',
        // Every other line terminator inside a leading `--` comment counts as a bare carriage return does.
        '-- x\vSELECT 1\nPRAGMA user_version = 5',
        '-- x\fSELECT 1\nPRAGMA user_version = 5',
        '-- x\u0085SELECT 1\nPRAGMA user_version = 5',
        '-- x\u2028SELECT 1\nPRAGMA user_version = 5',
        '-- x\u2029SELECT 1\nPRAGMA user_version = 5',
        // MySQL reads `--` as a comment only when white space follows it.
        '--c\nSELECT 1',
        '--1\nSELECT 1',
      ];
      for (final text in cases) {
        test(text.replaceAll('\n', r'\n').replaceAll('\r', r'\r'), () => expect(_sql(text), _asks(_mayWrite)));
      }
    });

    test('a block comment is read flat to the first `*/` when it holds no other `/*`', () {
      expect(_sql('/**/SELECT 1'), const RunsWithoutAsking());
      expect(_sql('/* a * / b */ SELECT 1'), const RunsWithoutAsking());
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

  group('a Unicode-escaped identifier', () {
    // review#111 deleted 3 rows on PostgreSQL 17.6 through `U&"dblink_exe\0063"`, which spells dblink_exec.
    for (final text in [
      r'''SELECT U&"dblink_exe\0063"('dbname=app', 'x')''',
      'select u&"x" from t',
      r'''SELECT U&"nextva!006c" UESCAPE '!' ('s')''',
      'SELECT 1, U&"a"',
    ]) {
      test(text, () => expect(_sql(text), _asks(_mayWrite, word: 'U&"', line: 1)));
    }

    test('is named by position among the deny words, on its own line', () {
      expect(_sql('SELECT 1\nFROM U&"t" WHERE DELETE'), _asks(_mayWrite, word: 'U&"', line: 2));
      expect(_sql('SELECT 1 DELETE\nFROM U&"t"'), _asks(_mayWrite, word: 'DELETE', line: 1));
    });

    test('U& without a double quote right after it, or a quote after other text, does not ask', () {
      expect(_sql("SELECT U&'d\\0061t\\+000061'"), const RunsWithoutAsking());
      expect(_sql('SELECT U& "x"'), const RunsWithoutAsking());
      expect(_sql('SELECT "U&x"'), const RunsWithoutAsking());
    });
  });

  group('EXPLAIN', () {
    test('asks when its next word is PLAN or ALL, naming that word', () {
      expect(_sql('EXPLAIN PLAN FOR SELECT * FROM t'), _asks(_mayWrite, word: 'PLAN', line: 1));
      expect(_sql('EXPLAIN /* c */ PLAN FOR SELECT 1'), _asks(_mayWrite, word: 'PLAN', line: 1));
      expect(_sql('explain\n-- c\nplan for select 1'), _asks(_mayWrite, word: 'PLAN', line: 3));
      expect(_sql('EXPLAIN ALL FOR SELECT * FROM t'), _asks(_mayWrite, word: 'ALL', line: 1));
      expect(_sql('Explain All for select 1'), _asks(_mayWrite, word: 'ALL', line: 1));
    });

    test('asks when a comment the engines read differently stands before its next word', () {
      for (final text in [
        'EXPLAIN /* /* */ SELECT 1 */ PLAN FOR SELECT 1',
        'EXPLAIN -- x\rSELECT 1\nPLAN FOR SELECT 1',
        'EXPLAIN /*!PLAN*/ SELECT 1',
        'EXPLAIN /* open',
      ]) {
        expect(_sql(text), _asks(_mayWrite), reason: text);
      }
    });

    test('runs when its next word is another word, a parenthesis or nothing', () {
      expect(_sql('EXPLAIN SELECT 1'), const RunsWithoutAsking());
      expect(_sql('EXPLAIN (FORMAT JSON) SELECT 1'), const RunsWithoutAsking());
      expect(_sql('EXPLAIN QUERY PLAN SELECT 1'), const RunsWithoutAsking());
      expect(_sql('EXPLAIN /* PLAN */ SELECT 1'), const RunsWithoutAsking());
      expect(_sql('EXPLAIN PLANS'), const RunsWithoutAsking());
      expect(_sql('EXPLAIN'), const RunsWithoutAsking());
      expect(_sql('SELECT plan, all_rows FROM t'), const RunsWithoutAsking());
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
