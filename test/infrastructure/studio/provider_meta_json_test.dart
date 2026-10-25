import 'dart:convert';
import 'dart:io';

import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// An answer with [capabilities] merged over the two required fields, and [labels] when given.
String _answer({Map<String, Object?> capabilities = const {}, Object? labels}) => jsonEncode({
  'capabilities': {'queryLanguage': 'sql', 'schemaRefreshPattern': r'(CREATE|DROP|ALTER|TRUNCATE)\b', ...capabilities},
  'labels': ?labels,
});

/// An answer whose one object kind is `table` with [fields] merged over its required ones.
String _kindAnswer(Map<String, Object?> fields) => _answer(
  capabilities: {
    'objectKinds': [
      {'id': 'table', 'role': 'relation', 'label': 'Table', 'labelPlural': 'Tables', ...fields},
    ],
  },
);

ObjectKind _kind(Map<String, Object?> fields) => ProviderMetaJson.read(_kindAnswer(fields)).objectKinds.single;

/// An answer whose key scan has [fields] merged over its two page sizes.
KeyScanSpec _keyScan(Map<String, Object?> fields) => ProviderMetaJson.read(
  _answer(
    capabilities: {
      'keyScan': {'defaultCount': 100, 'maxCount': 1000, ...fields},
    },
  ),
).keyScan!;

/// Collects the lines logged at warn level until the test ends.
List<String> _recordWarnings() {
  final warnings = <String>[];
  void record(OutputEvent event) {
    if (event.level == Level.warning) warnings.addAll(event.lines);
  }

  Logger.addOutputListener(record);
  addTearDown(() => Logger.removeOutputListener(record));
  return warnings;
}

void main() {
  test('an engine without containers or kinds, with a key browser', () {
    final meta = ProviderMetaJson.read(
      _answer(
        capabilities: {
          'queryLanguage': 'json',
          'keyScan': {'defaultCount': 500, 'maxCount': 1000, 'pattern': 'glob'},
        },
      ),
    );

    expect(meta.isSql, isFalse);
    expect(meta.containerLevels, isEmpty);
    expect(meta.objectKinds, isEmpty);
    expect(meta.keyScan, const KeyScanSpec(defaultCount: 500, maxCount: 1000));
    expect(meta.supportsTransactions, isFalse);
  });

  test('a kind listed only by the key browser', () {
    expect(_kind({'enumeratedBy': 'key-browser'}).keyBrowserOnly, isTrue);
  });

  test('refuses an answer without capabilities, a query language or a schema refresh pattern', () {
    for (final body in [
      '{}',
      '[]',
      '{"capabilities":{}}',
      '{"capabilities":{"schemaRefreshPattern":"x"}}',
      '{"capabilities":{"queryLanguage":"sql"}}',
      '{"capabilities":{"queryLanguage":"sql","schemaRefreshPattern":7}}',
    ]) {
      expect(() => ProviderMetaJson.read(body), throwsFormatException, reason: body);
    }
  });

  group('capabilities', () {
    ProviderMeta read(Map<String, Object?> capabilities) => ProviderMetaJson.read(_answer(capabilities: capabilities));

    test('schemaRefreshPattern is kept as Studio wrote it', () {
      expect(read({}).schemaRefreshPattern, r'(CREATE|DROP|ALTER|TRUNCATE)\b');
    });

    test('queryDialect is read as an opaque string beside the json language', () {
      expect(read({'queryLanguage': 'json', 'queryDialect': 'redis'}).queryDialect, 'redis');
      expect(
        read({'queryLanguage': 'json', 'queryDialect': 'a-dialect-of-tomorrow'}).queryDialect,
        'a-dialect-of-tomorrow',
      );
      expect(read({}).queryDialect, isNull);
      expect(read({'queryDialect': 3}).queryDialect, isNull);
    });

    test('explainFormat is read, absent when the engine has no explain', () {
      expect(read({'explainFormat': 'postgres-json'}).explainFormat, 'postgres-json');
      expect(read({}).explainFormat, isNull);
      expect(read({'explainFormat': true}).explainFormat, isNull);
    });

    test('maskingExemptColumns is the one exempt column and why', () {
      expect(
        read({
          'maskingExemptColumns': {'column': 'key', 'reason': 'the key names the value'},
        }).maskingExemptColumns,
        const MaskingExemptColumn(column: 'key', reason: 'the key names the value'),
      );
      expect(read({}).maskingExemptColumns, isNull);
      expect(read({'maskingExemptColumns': 'key'}).maskingExemptColumns, isNull);
      expect(
        () => read({
          'maskingExemptColumns': {'column': 'key'},
        }),
        throwsFormatException,
      );
    });

    test('supportsResultPagination is unsupported unless Studio says true', () {
      expect(read({'supportsResultPagination': true}).supportsResultPagination, isTrue);
      expect(read({'supportsResultPagination': false}).supportsResultPagination, isFalse);
      expect(read({}).supportsResultPagination, isFalse);
      expect(read({'supportsResultPagination': 'yes'}).supportsResultPagination, isFalse);
    });

    test('resumesBilledCompute is true only when Studio declares the literal true', () {
      expect(read({'resumesBilledCompute': true}).resumesBilledCompute, isTrue);
      expect(read({}).resumesBilledCompute, isFalse);
      expect(read({'resumesBilledCompute': false}).resumesBilledCompute, isFalse);
      expect(read({'resumesBilledCompute': 'yes'}).resumesBilledCompute, isFalse);
    });

    test('supportsColumnProfiling can only withhold profiling; absent keeps the language rule', () {
      expect(read({'supportsColumnProfiling': false}).supportsColumnProfiling, isFalse);
      expect(read({}).supportsColumnProfiling, isNull);
      expect(read({'supportsColumnProfiling': true}).supportsColumnProfiling, isNull);
      expect(read({'supportsColumnProfiling': 'no'}).supportsColumnProfiling, isNull);
    });

    test('supportsSqlFormat can only withhold Format; absent keeps the language rule', () {
      expect(read({'supportsSqlFormat': false}).supportsSqlFormat, isFalse);
      expect(read({}).supportsSqlFormat, isNull);
      expect(read({'supportsSqlFormat': true}).supportsSqlFormat, isNull);
    });

    test('tablesAreDerivedGroupings is false unless Studio says true', () {
      expect(read({'tablesAreDerivedGroupings': true}).tablesAreDerivedGroupings, isTrue);
      expect(read({}).tablesAreDerivedGroupings, isFalse);
      expect(read({'tablesAreDerivedGroupings': 1}).tablesAreDerivedGroupings, isFalse);
    });

    test('identifierQuoting is read as an opaque string', () {
      for (final quoting in ['double', 'backtick', 'double-always', 'backtick-always', 'bracket']) {
        expect(read({'identifierQuoting': quoting}).identifierQuoting, quoting);
      }
      expect(read({}).identifierQuoting, isNull);
      expect(read({'identifierQuoting': false}).identifierQuoting, isNull);
    });

    test('defaultPort is the whole number Studio declares, absent for a null or another type', () {
      expect(read({'defaultPort': 5432}).defaultPort, 5432);
      expect(read({}).defaultPort, isNull);
      expect(read({'defaultPort': null}).defaultPort, isNull, reason: 'SQLite declares defaultPort: null');
      expect(read({'defaultPort': '5432'}).defaultPort, isNull);
      expect(read({'defaultPort': 5432.5}).defaultPort, isNull);
    });

    test('statementTerminator is read as an opaque string', () {
      expect(read({'statementTerminator': 'none'}).statementTerminator, 'none');
      expect(read({'statementTerminator': 'semicolon'}).statementTerminator, 'semicolon');
      expect(read({}).statementTerminator, isNull);
      expect(read({'statementTerminator': false}).statementTerminator, isNull);
    });

    test('previewProjection and previewTimeWindow are declared when Studio sends any value', () {
      final projected = read({
        'previewProjection': {'rules': <Object>[]},
      });
      expect(projected.declaresPreviewProjection, isTrue);
      expect(projected.declaresPreviewTimeWindow, isFalse);
      final windowed = read({
        'previewTimeWindow': {'column': 'time'},
      });
      expect(windowed.declaresPreviewTimeWindow, isTrue);
      expect(windowed.declaresPreviewProjection, isFalse);
      expect(read({'previewProjection': null, 'previewTimeWindow': null}).declaresPreviewProjection, isFalse);
      expect(read({'previewProjection': null, 'previewTimeWindow': null}).declaresPreviewTimeWindow, isFalse);
    });

    test('containerNameSpelling is declared only as the literal engine', () {
      expect(read({'containerNameSpelling': 'engine'}).spellsContainerNamesAsEngine, isTrue);
      expect(read({}).spellsContainerNamesAsEngine, isFalse);
      expect(read({'containerNameSpelling': 'plain'}).spellsContainerNamesAsEngine, isFalse);
      expect(read({'containerNameSpelling': true}).spellsContainerNamesAsEngine, isFalse);
    });

    test('the recorded Postgres answers declare port 5432 and no terminator, projection, window or spelling', () {
      for (final name in ['meta_postgres', 'meta_postgres_server']) {
        final meta = ProviderMetaJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());
        expect(meta.defaultPort, 5432, reason: name);
        expect(meta.statementTerminator, isNull, reason: name);
        expect(meta.declaresPreviewProjection, isFalse, reason: name);
        expect(meta.declaresPreviewTimeWindow, isFalse, reason: name);
        expect(meta.spellsContainerNamesAsEngine, isFalse, reason: name);
      }
    });

    test('containerPathShapes is read as an opaque string, exact when absent', () {
      expect(read({'containerPathShapes': 'prefixes'}).containerPathShapes, 'prefixes');
      expect(read({'containerPathShapes': 'exact'}).containerPathShapes, 'exact');
      expect(read({'containerPathShapes': 'trees'}).containerPathShapes, 'trees');
      expect(read({}).containerPathShapes, 'exact');
      expect(read({'containerPathShapes': 2}).containerPathShapes, 'exact');
    });

    test('rowActions are read with their kinds and whether they run on activation', () {
      final meta = read({
        'rowActions': [
          {
            'id': 'describe',
            'label': 'Describe',
            'kinds': ['pod', 'deployment'],
            'activates': true,
          },
          {
            'id': 'logs',
            'label': 'Logs',
            'kinds': ['pod'],
          },
        ],
      });

      expect(meta.rowActions, const [
        KindRowAction(id: 'describe', label: 'Describe', kinds: ['pod', 'deployment'], activates: true),
        KindRowAction(id: 'logs', label: 'Logs', kinds: ['pod']),
      ]);
      expect(read({}).rowActions, isEmpty);
      expect(read({'rowActions': 'describe'}).rowActions, isEmpty);
      expect(
        () => read({
          'rowActions': [
            {'id': 'describe', 'kinds': <String>[]},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('object kinds', () {
    test('sourceLanguage is the language the source renders in', () {
      expect(_kind({'sourceLanguage': 'sql'}).sourceLanguage, 'sql');
      expect(_kind({}).sourceLanguage, isNull);
      expect(_kind({'sourceLanguage': 1}).sourceLanguage, isNull);
    });

    test('acceptsSourceEdits is false unless Studio says true', () {
      expect(_kind({'acceptsSourceEdits': true}).acceptsSourceEdits, isTrue);
      expect(_kind({}).acceptsSourceEdits, isFalse);
    });

    test('childKinds are the kinds nested under one object', () {
      expect(
        _kind({
          'childKinds': ['procedure', 'function'],
        }).childKinds,
        ['procedure', 'function'],
      );
      expect(_kind({}).childKinds, isEmpty);
      expect(_kind({'childKinds': 'procedure'}).childKinds, isEmpty);
    });

    test('acceptsRowWrites is false unless Studio says true', () {
      expect(_kind({'acceptsRowWrites': true}).acceptsRowWrites, isTrue);
      expect(_kind({}).acceptsRowWrites, isFalse);
    });

    // The mock build answers from this mock; Studio's Postgres provider declares the flag on its table kind, as the
    // recorded test/fixtures/studio/meta_postgres.json does.
    test('the local provider-meta mock declares acceptsRowWrites on its table kind, as Studio\'s Postgres does', () {
      final meta = ProviderMetaJson.read(File('assets/mock/POST_db_provider_meta.json').readAsStringSync());

      expect(meta.objectKinds.where((k) => k.acceptsRowWrites).map((k) => k.id), ['table']);
    });

    test('countIsListing is false unless Studio says true', () {
      expect(_kind({'countIsListing': true}).countIsListing, isTrue);
      expect(_kind({}).countIsListing, isFalse);
    });

    test('machineNames withheld is read, any other value leaves the names shown', () {
      expect(_kind({'machineNames': 'withheld'}).machineNamesWithheld, isTrue);
      expect(_kind({}).machineNamesWithheld, isFalse);
      expect(_kind({'machineNames': 'shown'}).machineNamesWithheld, isFalse);
    });

    test('group is the folder the kind is drawn in', () {
      expect(
        _kind({
          'group': {'id': 'workloads', 'label': 'Workloads'},
        }).group,
        const ObjectKindGroup(id: 'workloads', label: 'Workloads'),
      );
      expect(_kind({}).group, isNull);
      expect(_kind({'group': 'workloads'}).group, isNull);
      expect(
        () => _kind({
          'group': {'id': 'workloads'},
        }),
        throwsFormatException,
      );
    });
  });

  group('key scan', () {
    test("an absent shape field is Redis's walk, as Studio's keyScanShape reads it", () {
      final keyScan = _keyScan({});

      expect(keyScan.separator, ':');
      expect(keyScan.cursor, 'decimal');
      expect(keyScan.pattern, 'glob');
      expect(keyScan.totalScope, 'database');
      expect(keyScan.levels, isNull);
    });

    test('separator', () {
      expect(_keyScan({'separator': '/'}).separator, '/');
      expect(_keyScan({'separator': 1}).separator, ':');
    });

    test('cursor', () {
      expect(_keyScan({'cursor': 'opaque'}).cursor, 'opaque');
      expect(_keyScan({'cursor': false}).cursor, 'decimal');
    });

    test('pattern', () {
      expect(_keyScan({'pattern': 'prefix'}).pattern, 'prefix');
      expect(_keyScan({'pattern': null}).pattern, 'glob');
    });

    test('totalScope', () {
      expect(_keyScan({'totalScope': 'walk'}).totalScope, 'walk');
      expect(_keyScan({'totalScope': 'none'}).totalScope, 'none');
      expect(_keyScan({'totalScope': 0}).totalScope, 'database');
    });

    test('levels, with and without a root kind', () {
      expect(
        _keyScan({
          'levels': {'rootKind': 'collection'},
        }).levels,
        const KeyScanLevels(rootKind: 'collection'),
      );
      expect(_keyScan({'levels': <String, Object?>{}}).levels, const KeyScanLevels());
      expect(_keyScan({'levels': true}).levels, isNull);
      expect(
        _keyScan({
          'levels': {'rootKind': 4},
        }).levels,
        const KeyScanLevels(),
      );
    });
  });

  group('labels', () {
    ProviderLabels labels(Object? labels) => ProviderMetaJson.read(_answer(labels: labels)).labels;

    test('the engine words a screen shows', () {
      expect(
        labels({
          'entityName': 'Collection',
          'entityNamePlural': 'Collections',
          'rowName': 'document',
          'rowNamePlural': 'documents',
          'selectAction': 'Find Documents',
          'generateAction': 'Generate Find',
          'searchPlaceholder': 'Search collections or fields...',
          'analyzeAction': 'Validate Collection',
        }),
        const ProviderLabels(
          entityName: 'Collection',
          entityNamePlural: 'Collections',
          rowName: 'document',
          rowNamePlural: 'documents',
          selectAction: 'Find Documents',
          generateAction: 'Generate Find',
          searchPlaceholder: 'Search collections or fields...',
        ),
      );
    });

    test('every label is optional, and one of an unexpected type is left out', () {
      expect(labels(null), const ProviderLabels());
      expect(labels('Table'), const ProviderLabels());
      expect(labels({'entityName': 1, 'rowName': 'row'}), const ProviderLabels(rowName: 'row'));
    });
  });

  group('refreshesSchema', () {
    ProviderMeta withPattern(String pattern) =>
        ProviderMetaJson.read(_answer(capabilities: {'schemaRefreshPattern': pattern}));

    test("Postgres's default pattern", () {
      final meta = withPattern(r'(CREATE|DROP|ALTER|TRUNCATE)\b');

      expect(meta.refreshesSchema('CREATE TABLE t (id int)'), isTrue);
      expect(meta.refreshesSchema('select 1;\nDROP VIEW v'), isTrue);
      expect(meta.refreshesSchema('SELECT * FROM orders'), isFalse);
      expect(meta.refreshesSchema('SELECT created_at FROM orders'), isFalse, reason: r'CREATED has no \b after CREATE');
    });

    test("Redis's pattern", () {
      final meta = withPattern(r'(DEL|FLUSHDB|FLUSHALL|RENAME)\b');

      expect(meta.refreshesSchema('DEL session:1'), isTrue);
      expect(meta.refreshesSchema('FLUSHALL'), isTrue);
      expect(meta.refreshesSchema('GET session:1'), isFalse);
    });

    test('is case-insensitive, as Studio compiles it with the i flag', () {
      final meta = withPattern(r'(CREATE|DROP|ALTER|TRUNCATE)\b');

      expect(meta.refreshesSchema('create table t (id int)'), isTrue);
      expect(meta.refreshesSchema('Alter Table t Add c int'), isTrue);
    });

    test('the never pattern never refreshes', () {
      expect(withPattern('(?!)').refreshesSchema('CREATE TABLE t (id int)'), isFalse);
    });

    test('an uncompilable pattern answers false twice and warns once, naming the pattern and no statement', () {
      final warnings = _recordWarnings();
      // A pattern no other test uses, since the warning is written once per distinct pattern in the run.
      const pattern = '(CREATE|DROP[ uncompilable in refreshesSchema test';
      const statement = 'CREATE TABLE secret_payroll (salary int)';
      final meta = withPattern(pattern);

      expect(meta.refreshesSchema(statement), isFalse);
      expect(withPattern(pattern).refreshesSchema(statement), isFalse);

      final lines = warnings.where((line) => line.contains(pattern)).toList();
      expect(lines, hasLength(1));
      expect(warnings.join('\n'), isNot(contains('secret_payroll')));
    });
  });
}
