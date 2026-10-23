import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

// Every expected statement below is what Studio's generateTableQuery and generateCountQuery
// (src/lib/query-generators.ts, libredb-studio c9989a6b5) answer for the same capabilities and path, produced by a bun
// test file beside a tsconfig.json whose paths map "@/*" to libredb-studio's src/*, so nothing is written into the
// Studio checkout:
//   {"compilerOptions": {"baseUrl": ".", "paths": {"@/*": ["<libredb-studio>/src/*"]}}}
//   generateTableQuery(["s", name], {queryLanguage: "sql", defaultPort: port, identifierQuoting, ...})
//   generateCountQuery(path, (await createDatabaseProvider({type: "postgres", ...})).getCapabilities())
//   bun test probe.test.ts
// The engine answers use createDatabaseProvider(...).getCapabilities() from src/lib/db/factory.ts.

const _table = ObjectKind(id: 'table', role: 'relation', label: 'Table', labelPlural: 'Tables', hasColumns: true);

ProviderMeta _sql({
  int? defaultPort = 5432,
  String? identifierQuoting,
  String? statementTerminator,
  List<ContainerLevel> containerLevels = const [_schema],
  List<ObjectKind> objectKinds = const [_table],
  bool catalogSessions = false,
  bool tablesAreDerivedGroupings = false,
  String queryLanguage = 'sql',
  String? queryDialect,
  bool declaresPreviewProjection = false,
  bool declaresPreviewTimeWindow = false,
  bool spellsContainerNamesAsEngine = false,
}) => ProviderMeta(
  queryLanguage: queryLanguage,
  queryDialect: queryDialect,
  schemaRefreshPattern: 'x',
  containerLevels: containerLevels,
  objectKinds: objectKinds,
  defaultPort: defaultPort,
  identifierQuoting: identifierQuoting,
  statementTerminator: statementTerminator,
  catalogSessions: catalogSessions,
  tablesAreDerivedGroupings: tablesAreDerivedGroupings,
  declaresPreviewProjection: declaresPreviewProjection,
  declaresPreviewTimeWindow: declaresPreviewTimeWindow,
  spellsContainerNamesAsEngine: spellsContainerNamesAsEngine,
);

const _schema = ContainerLevel(id: 'schema', label: 'Schema', labelPlural: 'Schemas');
const _catalog = ContainerLevel(id: 'catalog', label: 'Database', labelPlural: 'Databases');

ProviderMeta _fixture(String name) => ProviderMetaJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

/// The meta of a table row's label: `port N` (`undefined` for none) or `declared Q` on port 5432.
ProviderMeta _metaOf(String label) {
  if (label.startsWith('declared ')) return _sql(identifierQuoting: label.substring('declared '.length));
  final port = label.substring('port '.length);
  return _sql(defaultPort: port == 'undefined' ? null : int.parse(port));
}

const _generator = PreviewStatementGenerator();

String _statementOf(PreviewAnswer answer) => switch (answer) {
  PreviewStatement(:final statement) => statement,
  PreviewUnavailable(:final reason) => fail('refused: $reason'),
};

void main() {
  group('quoting of each segment, as Studio quotes it', () {
    const cases = [
      // port 5432
      ('port 5432', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('port 5432', 'My Table', 'SELECT * FROM s."My Table";'),
      ('port 5432', 'a"b', 'SELECT * FROM s."a""b";'),
      ('port 5432', 'UPPER_NAME', 'SELECT * FROM s."UPPER_NAME";'),
      ('port 5432', 'with space', 'SELECT * FROM s."with space";'),
      ('port 5432', 'x]y', 'SELECT * FROM s."x]y";'),
      ('port 5432', 'a`b', 'SELECT * FROM s."a`b";'),
      ('port 5432', 'İzmir', 'SELECT * FROM s."İzmir";'),
      ('port 5432', '\$x', 'SELECT * FROM s."\$x";'),
      ('port 5432', 'a\$b#c', 'SELECT * FROM s."a\$b#c";'),
      ('port 5432', 'Mixed1', 'SELECT * FROM s."Mixed1";'),
      // port 1521
      ('port 1521', 'lower_name', 'SELECT * FROM "s"."lower_name";'),
      ('port 1521', 'My Table', 'SELECT * FROM "s"."My Table";'),
      ('port 1521', 'a"b', 'SELECT * FROM "s"."a""b";'),
      ('port 1521', 'UPPER_NAME', 'SELECT * FROM "s".UPPER_NAME;'),
      ('port 1521', 'with space', 'SELECT * FROM "s"."with space";'),
      ('port 1521', 'x]y', 'SELECT * FROM "s"."x]y";'),
      ('port 1521', 'a`b', 'SELECT * FROM "s"."a`b";'),
      ('port 1521', 'İzmir', 'SELECT * FROM "s"."İzmir";'),
      ('port 1521', '\$x', 'SELECT * FROM "s"."\$x";'),
      ('port 1521', 'a\$b#c', 'SELECT * FROM "s"."a\$b#c";'),
      ('port 1521', 'Mixed1', 'SELECT * FROM "s"."Mixed1";'),
      // port 1433
      ('port 1433', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('port 1433', 'My Table', 'SELECT * FROM s.[My Table];'),
      ('port 1433', 'a"b', 'SELECT * FROM s.[a"b];'),
      ('port 1433', 'UPPER_NAME', 'SELECT * FROM s.UPPER_NAME;'),
      ('port 1433', 'with space', 'SELECT * FROM s.[with space];'),
      ('port 1433', 'x]y', 'SELECT * FROM s.[x]]y];'),
      ('port 1433', 'a`b', 'SELECT * FROM s.[a`b];'),
      ('port 1433', 'İzmir', 'SELECT * FROM s.[İzmir];'),
      ('port 1433', '\$x', 'SELECT * FROM s.[\$x];'),
      ('port 1433', 'a\$b#c', 'SELECT * FROM s.[a\$b#c];'),
      ('port 1433', 'Mixed1', 'SELECT * FROM s.Mixed1;'),
      // port 3306
      ('port 3306', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('port 3306', 'My Table', 'SELECT * FROM s.`My Table`;'),
      ('port 3306', 'a"b', 'SELECT * FROM s.`a"b`;'),
      ('port 3306', 'UPPER_NAME', 'SELECT * FROM s.UPPER_NAME;'),
      ('port 3306', 'with space', 'SELECT * FROM s.`with space`;'),
      ('port 3306', 'x]y', 'SELECT * FROM s.`x]y`;'),
      ('port 3306', 'a`b', 'SELECT * FROM s.`a``b`;'),
      ('port 3306', 'İzmir', 'SELECT * FROM s.`İzmir`;'),
      ('port 3306', '\$x', 'SELECT * FROM s.`\$x`;'),
      ('port 3306', 'a\$b#c', 'SELECT * FROM s.`a\$b#c`;'),
      ('port 3306', 'Mixed1', 'SELECT * FROM s.Mixed1;'),
      // port 8888
      ('port 8888', 'lower_name', 'SELECT * FROM "s"."lower_name";'),
      ('port 8888', 'My Table', 'SELECT * FROM "s"."My Table";'),
      ('port 8888', 'a"b', 'SELECT * FROM "s"."a""b";'),
      ('port 8888', 'UPPER_NAME', 'SELECT * FROM "s"."UPPER_NAME";'),
      ('port 8888', 'with space', 'SELECT * FROM "s"."with space";'),
      ('port 8888', 'x]y', 'SELECT * FROM "s"."x]y";'),
      ('port 8888', 'a`b', 'SELECT * FROM "s"."a`b";'),
      ('port 8888', 'İzmir', 'SELECT * FROM "s"."İzmir";'),
      ('port 8888', '\$x', 'SELECT * FROM "s"."\$x";'),
      ('port 8888', 'a\$b#c', 'SELECT * FROM "s"."a\$b#c";'),
      ('port 8888', 'Mixed1', 'SELECT * FROM "s"."Mixed1";'),
      // port 8123
      ('port 8123', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('port 8123', 'My Table', 'SELECT * FROM s."My Table";'),
      ('port 8123', 'a"b', 'SELECT * FROM s."a""b";'),
      ('port 8123', 'UPPER_NAME', 'SELECT * FROM s."UPPER_NAME";'),
      ('port 8123', 'with space', 'SELECT * FROM s."with space";'),
      ('port 8123', 'x]y', 'SELECT * FROM s."x]y";'),
      ('port 8123', 'a`b', 'SELECT * FROM s."a`b";'),
      ('port 8123', 'İzmir', 'SELECT * FROM s."İzmir";'),
      ('port 8123', '\$x', 'SELECT * FROM s."\$x";'),
      ('port 8123', 'a\$b#c', 'SELECT * FROM s."a\$b#c";'),
      ('port 8123', 'Mixed1', 'SELECT * FROM s."Mixed1";'),
      // port undefined
      ('port undefined', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('port undefined', 'My Table', 'SELECT * FROM s."My Table";'),
      ('port undefined', 'a"b', 'SELECT * FROM s."a""b";'),
      ('port undefined', 'UPPER_NAME', 'SELECT * FROM s."UPPER_NAME";'),
      ('port undefined', 'with space', 'SELECT * FROM s."with space";'),
      ('port undefined', 'x]y', 'SELECT * FROM s."x]y";'),
      ('port undefined', 'a`b', 'SELECT * FROM s."a`b";'),
      ('port undefined', 'İzmir', 'SELECT * FROM s."İzmir";'),
      ('port undefined', '\$x', 'SELECT * FROM s."\$x";'),
      ('port undefined', 'a\$b#c', 'SELECT * FROM s."a\$b#c";'),
      ('port undefined', 'Mixed1', 'SELECT * FROM s."Mixed1";'),
      // declared double
      ('declared double', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('declared double', 'My Table', 'SELECT * FROM s."My Table";'),
      ('declared double', 'a"b', 'SELECT * FROM s."a""b";'),
      ('declared double', 'UPPER_NAME', 'SELECT * FROM s."UPPER_NAME";'),
      ('declared double', 'with space', 'SELECT * FROM s."with space";'),
      ('declared double', 'x]y', 'SELECT * FROM s."x]y";'),
      ('declared double', 'a`b', 'SELECT * FROM s."a`b";'),
      ('declared double', 'İzmir', 'SELECT * FROM s."İzmir";'),
      ('declared double', '\$x', 'SELECT * FROM s."\$x";'),
      ('declared double', 'a\$b#c', 'SELECT * FROM s."a\$b#c";'),
      ('declared double', 'Mixed1', 'SELECT * FROM s."Mixed1";'),
      // declared backtick
      ('declared backtick', 'lower_name', 'SELECT * FROM s.lower_name;'),
      ('declared backtick', 'My Table', 'SELECT * FROM s.`My Table`;'),
      ('declared backtick', 'a"b', 'SELECT * FROM s.`a"b`;'),
      ('declared backtick', 'UPPER_NAME', 'SELECT * FROM s.UPPER_NAME;'),
      ('declared backtick', 'with space', 'SELECT * FROM s.`with space`;'),
      ('declared backtick', 'x]y', 'SELECT * FROM s.`x]y`;'),
      ('declared backtick', 'a`b', 'SELECT * FROM s.`a``b`;'),
      ('declared backtick', 'İzmir', 'SELECT * FROM s.`İzmir`;'),
      ('declared backtick', '\$x', 'SELECT * FROM s.`\$x`;'),
      ('declared backtick', 'a\$b#c', 'SELECT * FROM s.`a\$b#c`;'),
      ('declared backtick', 'Mixed1', 'SELECT * FROM s.Mixed1;'),
      // declared double-always
      ('declared double-always', 'lower_name', 'SELECT * FROM "s"."lower_name";'),
      ('declared double-always', 'My Table', 'SELECT * FROM "s"."My Table";'),
      ('declared double-always', 'a"b', 'SELECT * FROM "s"."a""b";'),
      ('declared double-always', 'UPPER_NAME', 'SELECT * FROM "s"."UPPER_NAME";'),
      ('declared double-always', 'with space', 'SELECT * FROM "s"."with space";'),
      ('declared double-always', 'x]y', 'SELECT * FROM "s"."x]y";'),
      ('declared double-always', 'a`b', 'SELECT * FROM "s"."a`b";'),
      ('declared double-always', 'İzmir', 'SELECT * FROM "s"."İzmir";'),
      ('declared double-always', '\$x', 'SELECT * FROM "s"."\$x";'),
      ('declared double-always', 'a\$b#c', 'SELECT * FROM "s"."a\$b#c";'),
      ('declared double-always', 'Mixed1', 'SELECT * FROM "s"."Mixed1";'),
      // declared backtick-always
      ('declared backtick-always', 'lower_name', 'SELECT * FROM `s`.`lower_name`;'),
      ('declared backtick-always', 'My Table', 'SELECT * FROM `s`.`My Table`;'),
      ('declared backtick-always', 'a"b', 'SELECT * FROM `s`.`a"b`;'),
      ('declared backtick-always', 'UPPER_NAME', 'SELECT * FROM `s`.`UPPER_NAME`;'),
      ('declared backtick-always', 'with space', 'SELECT * FROM `s`.`with space`;'),
      ('declared backtick-always', 'x]y', 'SELECT * FROM `s`.`x]y`;'),
      ('declared backtick-always', 'a`b', 'SELECT * FROM `s`.`a``b`;'),
      ('declared backtick-always', 'İzmir', 'SELECT * FROM `s`.`İzmir`;'),
      ('declared backtick-always', '\$x', 'SELECT * FROM `s`.`\$x`;'),
      ('declared backtick-always', 'a\$b#c', 'SELECT * FROM `s`.`a\$b#c`;'),
      ('declared backtick-always', 'Mixed1', 'SELECT * FROM `s`.`Mixed1`;'),
    ];

    for (final (label, name, expected) in cases) {
      test('$label quotes "$name" as Studio does', () {
        final answer = _generator.preview(_metaOf(label), _table, ['s', name]);
        expect(_statementOf(answer), expected);
      });
    }
  });

  group('preview', () {
    test('the recorded Postgres answer previews public.customers with no row bound in the text', () {
      final answer = _generator.preview(_fixture('meta_postgres'), _table, ['public', 'customers']);
      expect(answer, const PreviewStatement(statement: 'SELECT * FROM public.customers;'));
    });

    test('the server-level Postgres answer keeps the full path and runs in the catalog of the path', () {
      final answer = _generator.preview(_fixture('meta_postgres_server'), _table, ['app', 'public', 'orders']);
      expect(answer, const PreviewStatement(statement: 'SELECT * FROM app.public.orders;', catalog: 'app'));
    });

    test('catalogSessions without a catalog level, or a catalog level without catalogSessions, names no catalog', () {
      expect(
        _generator.preview(_sql(catalogSessions: true), _table, ['public', 'orders']),
        const PreviewStatement(statement: 'SELECT * FROM public.orders;'),
      );
      expect(
        _generator.preview(_sql(containerLevels: const [_catalog, _schema]), _table, ['app', 'dbo', 'Order Lines']),
        const PreviewStatement(statement: 'SELECT * FROM app.dbo."Order Lines";'),
      );
    });

    test('the hand-written MSSQL answer brackets a name with a space', () {
      final meta = ProviderMetaJson.read(File('test/fixtures/studio/handwritten/mssql/meta.json').readAsStringSync());
      final table = meta.objectKinds.firstWhere((kind) => kind.role == 'relation');
      expect(
        _generator.preview(meta, table, ['app', 'dbo', 'Order Lines']),
        const PreviewStatement(statement: 'SELECT * FROM app.dbo.[Order Lines];'),
      );
    });

    test('the hand-written Oracle answer quotes a lowercase name and ends with no terminator', () {
      final meta = ProviderMetaJson.read(File('test/fixtures/studio/handwritten/oracle/meta.json').readAsStringSync());
      final table = meta.objectKinds.firstWhere((kind) => kind.role == 'relation');
      expect(
        _generator.preview(meta, table, ['APP', 'app_customers']),
        const PreviewStatement(statement: 'SELECT * FROM APP."app_customers"'),
      );
    });

    test('statementTerminator none leaves the terminator out, any other value keeps it', () {
      expect(
        _generator.preview(_sql(defaultPort: 1521, statementTerminator: 'none'), _table, ['s', 't']),
        const PreviewStatement(statement: 'SELECT * FROM "s"."t"'),
      );
      expect(
        _generator.preview(_sql(statementTerminator: 'semicolon'), _table, ['s', 't']),
        const PreviewStatement(statement: 'SELECT * FROM s.t;'),
      );
    });

    test('an engine without container levels previews the path as Studio quotes it', () {
      expect(
        _generator.preview(_sql(defaultPort: null, containerLevels: const []), _table, ['main', 'Users']),
        const PreviewStatement(statement: 'SELECT * FROM main."Users";'),
      );
    });
  });

  group('MongoDB', () {
    final mongo = ProviderMetaJson.read(File('test/fixtures/studio/handwritten/mongodb/meta.json').readAsStringSync());
    final collection = mongo.objectKinds.firstWhere((kind) => kind.id == 'collection');

    test('the preview is the find command with its database, pretty-printed with two spaces', () {
      expect(
        _generator.preview(mongo, collection, ['sample_shop', 'users']),
        const PreviewStatement(
          statement:
              '{\n  "database": "sample_shop",\n  "collection": "users",\n  "operation": "find",\n  "filter": {},\n'
              '  "options": {\n    "limit": 50\n  }\n}',
        ),
      );
    });

    test('the count is the count command with its database', () {
      expect(
        _generator.count(mongo, collection, ['sample_shop', 'users']),
        const PreviewStatement(
          statement:
              '{\n  "database": "sample_shop",\n  "collection": "users",\n  "operation": "count",\n  "filter": {}\n}',
        ),
      );
    });

    test('without a container level the command leaves the database out', () {
      final flat = _sql(queryLanguage: 'json', defaultPort: null, containerLevels: const []);
      expect(
        _generator.preview(flat, collection, ['users']),
        const PreviewStatement(
          statement: '{\n  "collection": "users",\n  "operation": "find",\n  "filter": {},\n  "options": {\n    "limit": 50\n  }\n}',
        ),
      );
      expect(
        _generator.count(flat, collection, ['users']),
        const PreviewStatement(statement: '{\n  "collection": "users",\n  "operation": "count",\n  "filter": {}\n}'),
      );
    });

    test('a name with a quote or a non-ASCII letter is written as JSON writes it', () {
      expect(
        _generator.preview(mongo, collection, ['İzmir', 'a"b']),
        const PreviewStatement(
          statement:
              '{\n  "database": "İzmir",\n  "collection": "a\\"b",\n  "operation": "find",\n  "filter": {},\n'
              '  "options": {\n    "limit": 50\n  }\n}',
        ),
      );
    });

    test('a path that is not the declared levels plus the name is refused, as jsonCommandAddress throws', () {
      expect(_generator.preview(mongo, collection, ['users']), isA<PreviewUnavailable>());
      expect(_generator.preview(mongo, collection, ['a', 'b', 'c']), isA<PreviewUnavailable>());
      expect(_generator.count(mongo, collection, ['users']), isA<PreviewUnavailable>());
    });

    test('levels without a schema level are refused, as jsonCommandAddress throws', () {
      final catalogOnly = _sql(queryLanguage: 'json', defaultPort: null, containerLevels: const [_catalog]);
      expect(_generator.preview(catalogOnly, collection, ['a', 'users']), isA<PreviewUnavailable>());
      expect(_generator.count(catalogOnly, collection, ['a', 'users']), isA<PreviewUnavailable>());
    });
  });

  group('refusals, with no count either', () {
    final refusals = <String, ProviderMeta>{
      'a declared queryDialect (Redis)': _fixture('meta_redis'),
      'a queryDialect beside json': _sql(queryLanguage: 'json', queryDialect: 'kafka', defaultPort: null),
      'previewProjection (Db2)': _sql(defaultPort: 50000, identifierQuoting: 'double', declaresPreviewProjection: true),
      'previewTimeWindow (InfluxDB SQL)': _sql(identifierQuoting: 'double', declaresPreviewTimeWindow: true),
      'containerNameSpelling engine (Spark)': _sql(identifierQuoting: 'backtick', spellsContainerNamesAsEngine: true),
      'Couchbase, port 8091': _sql(defaultPort: 8091),
      'promql': _sql(queryLanguage: 'promql', defaultPort: null),
      'cypher': _sql(queryLanguage: 'cypher', defaultPort: null),
      'influxql': _sql(queryLanguage: 'influxql', defaultPort: null),
      'an unknown query language': _sql(queryLanguage: 'gremlin', defaultPort: null),
      'an unknown declared quoting': _sql(identifierQuoting: 'bracket'),
    };
    for (final MapEntry(key: name, value: meta) in refusals.entries) {
      test(name, () {
        final kind = meta.objectKinds.firstWhere((kind) => kind.role == 'relation', orElse: () => _table);
        expect(_generator.preview(meta, kind, ['s', 't']), isA<PreviewUnavailable>());
        expect(_generator.count(meta, kind, ['s', 't']), isA<PreviewUnavailable>());
      });
    }

    test('an empty path', () {
      expect(_generator.preview(_sql(), _table, const []), isA<PreviewUnavailable>());
      expect(_generator.count(_sql(), _table, const []), isA<PreviewUnavailable>());
    });

    test('a kind that is not a relation, or that only the key browser lists', () {
      const function = ObjectKind(id: 'function', role: 'routine', label: 'Function', labelPlural: 'Functions');
      const key = ObjectKind(id: 'key', role: 'relation', label: 'Key', labelPlural: 'Keys', keyBrowserOnly: true);
      expect(_generator.preview(_sql(), function, ['s', 'f']), isA<PreviewUnavailable>());
      expect(_generator.preview(_sql(), key, ['s', 'k']), isA<PreviewUnavailable>());
      expect(_generator.count(_sql(), function, ['s', 'f']), isA<PreviewUnavailable>());
    });

    test('an engine with a relation kind whose names are withheld, as Studio\'s relationKindIds throws', () {
      const secret = ObjectKind(
        id: 'secret',
        role: 'relation',
        label: 'Secret',
        labelPlural: 'Secrets',
        machineNamesWithheld: true,
      );
      final meta = _sql(objectKinds: const [_table, secret]);
      expect(_generator.preview(meta, secret, ['s', 'x']), isA<PreviewUnavailable>());
      expect(_generator.preview(meta, _table, ['s', 't']), isA<PreviewUnavailable>());
      expect(_generator.count(meta, _table, ['s', 't']), isA<PreviewUnavailable>());
    });
  });

  group('count', () {
    test('Postgres counts with COUNT(*) AS row_count, a newline and FROM the path', () {
      expect(
        _generator.count(_fixture('meta_postgres'), _table, ['public', 'customers']),
        const PreviewStatement(statement: 'SELECT COUNT(*) AS row_count\nFROM public.customers;'),
      );
    });

    test('a server-level path counts in its catalog', () {
      expect(
        _generator.count(_fixture('meta_postgres_server'), _table, ['app', 'public', 'orders']),
        const PreviewStatement(statement: 'SELECT COUNT(*) AS row_count\nFROM app.public.orders;', catalog: 'app'),
      );
    });

    test('port 1433 counts with COUNT_BIG(*)', () {
      expect(
        _generator.count(_sql(defaultPort: 1433), _table, ['app', 'dbo', 'Order Lines']),
        const PreviewStatement(statement: 'SELECT COUNT_BIG(*) AS row_count\nFROM app.dbo.[Order Lines];'),
      );
    });

    test('statementTerminator none, on Oracle', () {
      expect(
        _generator.count(_sql(defaultPort: 1521, statementTerminator: 'none'), _table, ['APP', 'app_customers']),
        const PreviewStatement(statement: 'SELECT COUNT(*) AS row_count\nFROM APP."app_customers"'),
      );
    });

    test('quoted segments, as the preview quotes them', () {
      expect(
        _generator.count(_sql(defaultPort: 3306), _table, ['s', 'a`b']),
        const PreviewStatement(statement: 'SELECT COUNT(*) AS row_count\nFROM s.`a``b`;'),
      );
      expect(
        _generator.count(_sql(identifierQuoting: 'backtick-always'), _table, ['s', 'My Table']),
        const PreviewStatement(statement: 'SELECT COUNT(*) AS row_count\nFROM `s`.`My Table`;'),
      );
    });

    test('derived groupings offer a preview and no count, as offersCountQuery says', () {
      final meta = _sql(tablesAreDerivedGroupings: true);
      expect(_generator.preview(meta, _table, ['s', 't']), const PreviewStatement(statement: 'SELECT * FROM s.t;'));
      expect(_generator.count(meta, _table, ['s', 't']), isA<PreviewUnavailable>());
    });
  });
}
