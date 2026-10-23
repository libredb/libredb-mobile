import 'package:equatable/equatable.dart';

/// Why a text asks for a confirmation before it runs.
enum WriteCheckReason {
  /// The text holds a deny word, or its first keyword is not on the allow list or cannot be found.
  mayWrite,

  /// A `;` is followed by more text, or a line holds only `GO` or only `/`.
  severalStatements,

  /// The connection's engine does not speak SQL, so the check does not read the text.
  notSql,
}

/// The word that made a SQL text ask with [WriteCheckReason.mayWrite], upper-cased, and the 1-based line it is on, as
/// [statementLines] counts lines.
class FlaggedWord extends Equatable {
  const FlaggedWord({required this.word, required this.line});

  final String word;
  final int line;

  @override
  List<Object?> get props => [word, line];
}

/// Whether a text may run without a confirmation. It never carries the text.
sealed class WriteCheckAnswer extends Equatable {
  const WriteCheckAnswer();
}

final class RunsWithoutAsking extends WriteCheckAnswer {
  const RunsWithoutAsking();

  @override
  List<Object?> get props => const [];
}

final class AsksBeforeRunning extends WriteCheckAnswer {
  const AsksBeforeRunning({required this.reasons, this.flaggedWord});

  /// Every reason that applies, never empty.
  final Set<WriteCheckReason> reasons;

  /// With [WriteCheckReason.mayWrite], the first deny word, else the first keyword that is not on the allow list; null
  /// when the text has neither (a leading comment that never closes, or no word at all).
  final FlaggedWord? flaggedWord;

  @override
  List<Object?> get props => [reasons, flaggedWord];
}

/// The lines of [text], split at a line feed, a carriage return and a CRLF pair, so a bare carriage return, which
/// PostgreSQL and SQL Server read as the end of a `--` comment, starts a line of its own.
///
/// [InterimWriteCheck] counts lines this way, and the confirmation sheet lists them this way, so a flagged line number
/// points at the line the sheet shows.
List<String> statementLines(String text) => text.split(_lineBreak);

final _lineBreak = RegExp(r'\r\n|\r|\n');

/// The fail-closed check of the SQL editor: whether a text has to be confirmed before it is sent, read from the raw
/// text alone, without a grammar.
///
/// It reads exactly the text that will be sent. A SQL text runs without asking only when the raw text holds none of
/// [denyWords] (comments and quotes included), when no `;` is followed by more than white space and no line holds only
/// `GO` or only `/`, and when its first keyword, read after leading comments only, is on [allowedFirstKeywords]. Every
/// text of an engine that does not speak SQL asks.
///
/// Comments are not removed before the scan, because the engines disagree about where a comment ends and what it
/// runs: PostgreSQL and SQL Server end `--` at a bare carriage return, MySQL and MariaDB run the body of `/*!` and
/// `/*M!`, and MySQL needs a space after `--` (libredb-studio `src/lib/sql/update-target.ts:187-226`,
/// `src/lib/sql/optimizer-hints.ts:1-44`). So a write word in a comment or a string asks too: a false prompt costs one
/// tap, a missed write costs data.
///
/// It reads keywords, not what a called function or procedure does (`SELECT pg_terminate_backend(42)`), and it misses
/// a T-SQL statement whose keyword is not on the list; `docs/security.md` ('Write confirmation') records both limits.
/// Studio's analysis endpoint (S-06) replaces it, and it stays as that analysis's fallback.
class InterimWriteCheck {
  const InterimWriteCheck();

  /// Words that ask wherever they stand, matched as whole words in any ASCII case.
  static const denyWords = {
    'INSERT',
    'UPDATE',
    'DELETE',
    'MERGE',
    'UPSERT',
    'TRUNCATE',
    'DROP',
    'ALTER',
    'CREATE',
    'GRANT',
    'REVOKE',
    'DENY',
    'CALL',
    'EXEC',
    'EXECUTE',
    'DO',
    'COPY',
    'LOCK',
    'SET',
    'RESET',
    'COMMIT',
    'ROLLBACK',
    'BEGIN',
    'VACUUM',
    'REINDEX',
    'CLUSTER',
    'REFRESH',
    'INTO',
    // EXPLAIN ANALYZE runs the statement it explains, in every spelling, `EXPLAIN (FORMAT JSON, ANALYZE)` included.
    'ANALYZE',
    'ANALYSE',
    // T-SQL statements that need no separator and change data, rights, sessions or the server.
    'KILL',
    'SHUTDOWN',
    'BACKUP',
    'RESTORE',
    'DBCC',
    'RECONFIGURE',
    'DISABLE',
    'ENABLE',
    'SEND',
    'RECEIVE',
    'WRITETEXT',
    'UPDATETEXT',
    'SETUSER',
    // Built-ins whose call has an effect the check cannot see in the text, so an allowed SELECT that calls one may
    // write; the list of 94 is closed (#111). They are rare as names, and a user-defined function stays unseen
    // (`docs/security.md`).
    // They run statement text.
    'DBLINK',
    'DBLINK_EXEC',
    'DBLINK_SEND_QUERY',
    'DBLINK_OPEN',
    'QUERY_TO_XML',
    'QUERY_TO_XML_AND_XMLSCHEMA',
    'QUERY_TO_XMLSCHEMA',
    // They keep or end remote dblink state, which stays on Studio's shared provider.
    'DBLINK_FETCH',
    'DBLINK_CLOSE',
    'DBLINK_CONNECT',
    'DBLINK_CONNECT_U',
    'DBLINK_DISCONNECT',
    'DBLINK_CANCEL_QUERY',
    // They write, move or remove large objects, a server file included.
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
    // They take or release advisory locks, which can outlive the request on the shared provider.
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
    // They end or cancel another session's work, change a setting or a sequence, or load code.
    'PG_TERMINATE_BACKEND',
    'PG_CANCEL_BACKEND',
    'SET_CONFIG',
    'SETVAL',
    'NEXTVAL',
    'LOAD_EXTENSION',
    // They send a notification, or signal the server or a session.
    'PG_NOTIFY',
    'PG_RELOAD_CONF',
    'PG_ROTATE_LOGFILE',
    'PG_LOG_BACKEND_MEMORY_CONTEXTS',
    // They control backup, recovery and the WAL.
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
    // They create, copy, drop, advance or consume replication slots and origins, or write to the WAL stream.
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
    // They maintain indexes.
    'BRIN_SUMMARIZE_NEW_VALUES',
    'BRIN_SUMMARIZE_RANGE',
    'BRIN_DESUMMARIZE_RANGE',
    'GIN_CLEAN_PENDING_LIST',
    // They reset statistics.
    'PG_STAT_RESET',
    'PG_STAT_RESET_SHARED',
    'PG_STAT_RESET_SINGLE_TABLE_COUNTERS',
    'PG_STAT_RESET_SINGLE_FUNCTION_COUNTERS',
    'PG_STAT_RESET_SLRU',
    'PG_STAT_RESET_REPLICATION_SLOT',
    'PG_STAT_RESET_SUBSCRIPTION_STATS',
    // They write the catalog or server files.
    'PG_IMPORT_SYSTEM_COLLATIONS',
    'PG_FILE_WRITE',
    'PG_FILE_RENAME',
    'PG_FILE_UNLINK',
    'PG_FILE_SYNC',
    // They hold or release a MySQL or MariaDB named lock, which a commit or rollback does not release.
    'GET_LOCK',
    'RELEASE_LOCK',
    'RELEASE_ALL_LOCKS',
    // They end or cancel Snowflake sessions, transactions or queries; the `$` matches only itself.
    r'SYSTEM$ABORT_SESSION',
    r'SYSTEM$ABORT_TRANSACTION',
    r'SYSTEM$CANCEL_QUERY',
    r'SYSTEM$CANCEL_ALL_QUERIES',
  };

  /// The first keywords a text may start with and run without asking.
  static const allowedFirstKeywords = {'SELECT', 'SHOW', 'DESCRIBE', 'DESC', 'EXPLAIN', 'VALUES', 'TABLE', 'WITH'};

  /// A word: a run of ASCII letters, digits and `_`; any other character, a non-ASCII letter included, ends it.
  static final _word = RegExp('[A-Za-z0-9_]+');

  /// A deny word in any ASCII case (a `$` in one matches only itself) whose left neighbour is not an ASCII letter or `_` and whose right neighbour is not
  /// an ASCII letter, digit or `_`. A digit on the left does not hide it, since T-SQL reads `1DELETE` as the number 1
  /// and a DELETE. Each letter is spelled as its two ASCII cases, so no other script's case folding can match.
  static final _denyWord = RegExp(
    '(?<![A-Za-z_])(?:${[
      for (final word in denyWords) [for (final c in word.split('')) '[$c${c.toLowerCase()}]'].join(),
    ].join('|')})(?![A-Za-z0-9_])',
  );

  /// A maximal run of ASCII letters, digits and `_` that starts with a digit; T-SQL ends a number at the first
  /// character that cannot continue it, so every deny word inside such a run counts (`0xKILL` is `0x` and KILL).
  static final _numberLedRun = RegExp('(?<![A-Za-z0-9_])[0-9][A-Za-z0-9_]*');

  /// The deny words longest first, so the longest of several that start at one place is the one named.
  static final _denyWordsLongestFirst = denyWords.toList()..sort((a, b) => b.length.compareTo(a.length));

  /// The characters that end a `--` comment on some engines but not on others: a carriage return (when no line feed
  /// follows it), a vertical tab, a form feed, NEL, the line separator and the paragraph separator.
  static final _otherLineTerminator = RegExp('\r(?!\n)|[\x0B\x0C\u0085\u2028\u2029]');

  /// The white space MySQL needs after `--` to read a comment.
  static const _dashCommentSpace = {' ', '\t', '\n', '\r'};

  /// Whether [text] runs without asking on an engine that speaks SQL ([isSql], `ProviderMeta.isSql`) or not.
  WriteCheckAnswer check(String text, {required bool isSql}) {
    if (!isSql) return const AsksBeforeRunning(reasons: {WriteCheckReason.notSql});

    final reasons = <WriteCheckReason>{};
    var flagged = _firstDenyWord(text);
    if (flagged != null) reasons.add(WriteCheckReason.mayWrite);

    final first = _firstKeyword(text);
    if (first == null || !allowedFirstKeywords.contains(first.word)) {
      reasons.add(WriteCheckReason.mayWrite);
      flagged ??= first;
    }

    if (_hasSeveralStatements(text)) reasons.add(WriteCheckReason.severalStatements);

    if (reasons.isEmpty) return const RunsWithoutAsking();
    return AsksBeforeRunning(reasons: reasons, flaggedWord: flagged);
  }

  static FlaggedWord? _firstDenyWord(String text) {
    final bounded = _denyWord.firstMatch(text);
    var start = bounded?.start;
    var word = bounded?[0]!.toUpperCase();
    for (final run in _numberLedRun.allMatches(text)) {
      if (start != null && run.start > start) break;
      final upper = run[0]!.toUpperCase();
      for (final deny in _denyWordsLongestFirst) {
        final at = upper.indexOf(deny);
        if (at < 0) continue;
        final position = run.start + at;
        if (start == null || position < start || (position == start && deny.length > word!.length)) {
          start = position;
          word = deny;
        }
      }
    }
    if (start == null) return null;
    return FlaggedWord(word: word!, line: _lineOf(text, start));
  }

  /// The first word after leading white space and comments, or null when no word follows them.
  ///
  /// A leading comment counts only when every engine reads it the same way, so the text has no first keyword when a
  /// leading comment never closes, when a `--` comment holds a bare carriage return or another line terminator but
  /// the line feed (PostgreSQL and SQL Server end it at a bare carriage return, SQLite, MySQL, MariaDB and DuckDB at the
  /// line feed) or is not followed by white space (MySQL reads no
  /// comment then), when a `/* */` comment holds another `/*` (PostgreSQL and SQL Server nest them, the others end it
  /// at the first `*/`), and when it starts with `/*!` or `/*M!` (MySQL and MariaDB run its body).
  static FlaggedWord? _firstKeyword(String text) {
    var i = 0;
    while (i < text.length) {
      final char = text[i];
      if (char.trim().isEmpty) {
        i++;
      } else if (text.startsWith('--', i)) {
        if (i + 2 >= text.length || !_dashCommentSpace.contains(text[i + 2])) return null;
        final end = text.indexOf('\n', i + 2);
        if (end < 0) return null;
        if (_otherLineTerminator.hasMatch(text.substring(i + 2, end + 1))) return null;
        i = end + 1;
      } else if (text.startsWith('/*', i)) {
        if (text.startsWith('/*!', i) || text.startsWith('/*M!', i) || text.startsWith('/*m!', i)) return null;
        final end = text.indexOf('*/', i + 2);
        if (end < 0) return null;
        if (text.substring(i + 2, end + 2).contains('/*')) return null;
        i = end + 2;
      } else {
        final match = _word.matchAsPrefix(text, i);
        if (match == null) return null;
        return FlaggedWord(word: match[0]!.toUpperCase(), line: _lineOf(text, i));
      }
    }
    return null;
  }

  static bool _hasSeveralStatements(String text) {
    final semicolon = text.indexOf(';');
    if (semicolon >= 0 && text.substring(semicolon + 1).trim().isNotEmpty) return true;
    return statementLines(text).any((line) {
      final trimmed = line.trim();
      return trimmed == '/' || trimmed.toUpperCase() == 'GO';
    });
  }

  /// The 1-based line of [offset], counted as [statementLines] splits lines.
  static int _lineOf(String text, int offset) => statementLines(text.substring(0, offset)).length;
}
