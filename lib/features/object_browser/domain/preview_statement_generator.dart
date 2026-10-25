import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// What the generator answers for an object: a statement to run, or why it writes none.
sealed class PreviewAnswer extends Equatable {
  const PreviewAnswer();
}

/// A statement Studio's generator would write for the object, and the database it runs in on a server-level
/// connection.
final class PreviewStatement extends PreviewAnswer {
  const PreviewStatement({required this.statement, this.catalog});

  final String statement;

  /// The path's segment at the `catalog` level, on a connection that declares `catalogSessions`; null otherwise.
  final String? catalog;

  @override
  List<Object?> get props => [statement, catalog];

  /// Leaves the statement out, which names the user's objects and never goes into a log.
  @override
  String toString() => 'PreviewStatement(catalog: $catalog)';
}

/// The generator writes no statement for the object, because Studio refuses it or writes it in a way the app does not
/// port. [reason] is for the log and the tests, never shown.
final class PreviewUnavailable extends PreviewAnswer {
  const PreviewUnavailable(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

/// The row preview and the row count of an object, as Studio's `generateTableQuery` and `generateCountQuery` write them
/// (`src/lib/query-generators.ts`, libredb-studio c9989a6b5).
///
/// The preview is `SELECT * FROM <path>` with the terminator and no row bound in the text: the bound travels as the
/// run's page limit, so Studio's limiter appends it. The path is always fully qualified, each segment quoted only when
/// it would not round-trip bare (`quoteIdentifier`): by the declared `identifierQuoting` when there is one, else by the
/// default port. MongoDB, the one `json` engine without a dialect, gets its find and count commands.
///
/// It refuses what Studio refuses and what the app does not port: a declared `queryDialect`, `previewProjection`,
/// `previewTimeWindow`, `containerNameSpelling: "engine"`, Couchbase (port 8091), every query language other than
/// `sql` and `json`, a quoting it does not know, an empty path, a kind that is not a relation the object surface lists,
/// and every kind of an engine whose relation kind withholds its names, since Studio's `relationKindIds` throws there.
/// The count is offered only where `offersCountQuery` allows it and the preview is offered too.
class PreviewStatementGenerator {
  const PreviewStatementGenerator();

  static const _couchbasePort = 8091;
  static const _druidPort = 8888;

  /// The preview limit Studio's find command writes, and the page size of a SQL preview (`PREVIEW_PAGE_SIZE`).
  static const pageSize = 50;

  PreviewAnswer preview(ProviderMeta meta, ObjectKind kind, List<String> path) {
    if (_refusal(meta, kind, path) case final refusal?) return refusal;
    if (meta.queryLanguage == 'json') {
      return _json(meta, path, {
        'operation': 'find',
        'filter': <String, Object?>{},
        'options': {'limit': pageSize},
      });
    }
    return PreviewStatement(
      statement: 'SELECT * FROM ${_quotePath(meta, path)}${_terminator(meta)}',
      catalog: _catalogOf(meta, path),
    );
  }

  PreviewAnswer count(ProviderMeta meta, ObjectKind kind, List<String> path) {
    if (_refusal(meta, kind, path) case final refusal?) return refusal;
    // `offersCountQuery` (`src/lib/db/types.ts:572-577`): never for derived groupings; a dialect is refused above.
    if (meta.tablesAreDerivedGroupings) return const PreviewUnavailable('derived groupings offer no count');
    if (meta.queryLanguage == 'json') {
      return _json(meta, path, {'operation': 'count', 'filter': <String, Object?>{}});
    }
    // COUNT returns an int on SQL Server; COUNT_BIG keeps a count past two billion.
    final count = meta.defaultPort == 1433 ? 'COUNT_BIG(*)' : 'COUNT(*)';
    return PreviewStatement(
      statement: 'SELECT $count AS row_count\nFROM ${_quotePath(meta, path)}${_terminator(meta)}',
      catalog: _catalogOf(meta, path),
    );
  }

  PreviewUnavailable? _refusal(ProviderMeta meta, ObjectKind kind, List<String> path) {
    if (kind.role != 'relation' || kind.keyBrowserOnly) return const PreviewUnavailable('not a listed relation kind');
    if (meta.objectKinds.any((k) => k.role == 'relation' && !k.keyBrowserOnly && k.machineNamesWithheld)) {
      return const PreviewUnavailable('a relation kind withholds its names');
    }
    if (path.isEmpty) return const PreviewUnavailable('the path has no segments');
    if (meta.queryDialect != null) return const PreviewUnavailable('a declared query dialect');
    switch (meta.queryLanguage) {
      case 'json':
        return null;
      case 'sql':
        if (meta.defaultPort == _couchbasePort) return const PreviewUnavailable('Couchbase');
        if (meta.declaresPreviewProjection) return const PreviewUnavailable('previewProjection');
        if (meta.declaresPreviewTimeWindow) return const PreviewUnavailable('previewTimeWindow');
        if (meta.spellsContainerNamesAsEngine) return const PreviewUnavailable('containerNameSpelling engine');
        final quoting = meta.identifierQuoting;
        if (quoting != null && !_declaredQuoting.containsKey(quoting)) {
          return const PreviewUnavailable('an unknown identifierQuoting');
        }
        return null;
      default:
        return const PreviewUnavailable('a query language the app does not write');
    }
  }

  /// Studio's `declaredLevels`: at most the first two container levels.
  static List<ContainerLevel> _levels(ProviderMeta meta) => meta.containerLevels.take(2).toList();

  /// Studio's `catalogOfPath`: the path's segment at the `catalog` level, when the engine declares `catalogSessions`.
  static String? _catalogOf(ProviderMeta meta, List<String> path) {
    if (!meta.catalogSessions) return null;
    final index = _levels(meta).indexWhere((level) => level.id == 'catalog');
    return index < 0 || index >= path.length ? null : path[index];
  }

  /// Studio's `jsonCommandAddress` and `JSON.stringify(command, null, 2)`.
  static PreviewAnswer _json(ProviderMeta meta, List<String> path, Map<String, Object?> command) {
    final levels = _levels(meta);
    if (path.length != levels.length + 1) return const PreviewUnavailable('the path is not the declared levels');
    final address = <String, Object?>{};
    if (levels.isNotEmpty) {
      final index = levels.indexWhere((level) => level.id == 'schema');
      if (index < 0) return const PreviewUnavailable('no schema level for the database');
      address['database'] = path[index];
    }
    address['collection'] = path.last;
    return PreviewStatement(
      statement: const JsonEncoder.withIndent('  ').convert({...address, ...command}),
      catalog: _catalogOf(meta, path),
    );
  }

  static String _terminator(ProviderMeta meta) => meta.statementTerminator == 'none' ? '' : ';';

  static String _quotePath(ProviderMeta meta, List<String> path) =>
      path.map((segment) => _quoteIdentifier(meta, segment)).join('.');

  static final _bareBacktick = RegExp(r'^[A-Za-z_][\w$]*$');
  static final _bareDouble = RegExp(r'^[a-z_][a-z0-9_$]*$');
  static final _bareOracle = RegExp(r'^[A-Z_][A-Z0-9_$#]*$');
  static final _bareSqlServer = RegExp(r'^[A-Za-z_]\w*$');

  static String _double(String name) => '"${name.replaceAll('"', '""')}"';
  static String _backtick(String name) => '`${name.replaceAll('`', '``')}`';

  /// Studio's `DECLARED_QUOTING`.
  static final Map<String, String Function(String)> _declaredQuoting = {
    'backtick': (name) => _bareBacktick.hasMatch(name) ? name : _backtick(name),
    'double': (name) => _bareDouble.hasMatch(name) ? name : _double(name),
    'double-always': _double,
    'backtick-always': _backtick,
  };

  /// Studio's `quoteIdentifier` for SQL: the declared quoting, else the rule of the default port.
  static String _quoteIdentifier(ProviderMeta meta, String name) {
    if (meta.identifierQuoting case final quoting?) return _declaredQuoting[quoting]!(name);
    return switch (meta.defaultPort) {
      _druidPort => _double(name),
      1521 => _bareOracle.hasMatch(name) ? name : _double(name),
      1433 => _bareSqlServer.hasMatch(name) ? name : '[${name.replaceAll(']', ']]')}]',
      3306 => _bareBacktick.hasMatch(name) ? name : _backtick(name),
      _ => _bareDouble.hasMatch(name) ? name : _double(name),
    };
  }
}
