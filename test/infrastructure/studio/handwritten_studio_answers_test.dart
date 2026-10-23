import 'dart:convert';
import 'dart:io';

import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the hand-written Studio answers in test/fixtures/studio/handwritten, the container shapes and edge answers
/// that the SQLite sample of tool/studio-dev cannot record. Their README names the Studio commit and source file each
/// answer follows.
void main() {
  String answer(String name) => File('test/fixtures/studio/handwritten/$name.json').readAsStringSync();

  group('MongoDB', () {
    test('provider-meta has one Database level and the collection and view kinds', () {
      final meta = ProviderMetaJson.read(answer('mongodb/meta'));

      expect(meta.queryLanguage, 'json');
      expect(meta.isSql, isFalse);
      expect(meta.containerLevels.map((l) => (l.id, l.label)), [('schema', 'Database')]);
      expect(meta.objectKinds.map((k) => k.id), ['collection', 'view']);
      expect(meta.objectKinds.map((k) => k.hasSource), [false, true]);
      expect(meta.objectKinds.every((k) => k.hasColumns && k.role == 'relation'), isTrue);
      expect(meta.keyScan, isNull);
    });

    test('provider-meta carries the JSON words, the refresh pattern and the kinds that take writes', () {
      final meta = ProviderMetaJson.read(answer('mongodb/meta'));
      final collection = meta.objectKinds.singleWhere((k) => k.id == 'collection');
      final view = meta.objectKinds.singleWhere((k) => k.id == 'view');

      expect(meta.queryDialect, isNull, reason: 'MongoDB is the plain json language');
      expect(meta.explainFormat, isNull);
      expect(meta.containerPathShapes, 'exact');
      expect(meta.supportsResultPagination, isFalse);
      expect(meta.schemaRefreshPattern, r'"operation"\s*:\s*"(insert|delete|update)');
      expect(meta.refreshesSchema('{"collection": "orders", "operation": "insertOne", "document": {}}'), isTrue);
      expect(meta.refreshesSchema('{"collection": "orders", "operation": "find", "filter": {}}'), isFalse);
      expect((collection.acceptsRowWrites, view.acceptsRowWrites), (true, false));
      expect((collection.sourceLanguage, view.sourceLanguage), (null, 'json'));
      expect(
        meta.labels,
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

    test('containers are the databases, one level deep', () {
      final containers = ObjectBrowserJson.containers(answer('mongodb/containers'));

      expect(containers.map((c) => c.path), [
        ['app'],
        ['reporting'],
      ]);
      expect(containers.every((c) => c.level == 0), isTrue);
      expect(containers.map((c) => c.isSessionDefault), [true, false]);
    });

    test('a collection list addresses each collection under its database', () {
      final objects = ObjectBrowserJson.objects(answer('mongodb/list_collection'));

      expect(objects.map((o) => o.path), [
        ['app', 'customers'],
        ['app', 'orders'],
      ]);
      expect(objects.every((o) => o.kind == 'collection' && o.status == null && o.rowCount == null), isTrue);
    });

    test('a collection described from a document sample carries no provenance and no foreign key', () {
      final detail = ObjectBrowserJson.detail(answer('mongodb/describe_collection'));

      expect(detail.path, ['app', 'customers']);
      expect(detail.columns.map((c) => c.name), ['_id', 'createdAt', 'email', 'name', 'tier']);
      expect(detail.columns.first.isPrimary, isTrue);
      expect(detail.columns.map((c) => c.nullable), [false, false, false, false, true]);
      expect(detail.columns.any((c) => c.sampled), isFalse, reason: 'Studio 02dc26057 marks no MongoDB column sampled');
      expect(detail.indexes?.map((i) => (i.name, i.unique)), [('_id_', false), ('email_1', true)]);
      expect(detail.foreignKeys, isEmpty);
    });

    test('a find answer keys each document by its own fields, the columns their union', () {
      final result = QueryResultJson.read(answer('mongodb/query_find'));

      expect(result.fields, ['_id', 'name', 'address', 'tags', 'created', 'payload', 'visits']);
      expect(result.rowCount, 2);
      expect(result.rows.map((row) => row.keys.length), [5, 5]);
      expect(result.rows.first['address'], isA<Map<String, dynamic>>());
      expect(result.rows.last['payload'], {
        'type': 'Buffer',
        'data': [1, 'two'],
      });
      expect(result.columnTypes, isEmpty);
      expect(result.pagination?.hasMore, isFalse);
    });
  });

  group('Oracle', () {
    test('provider-meta has the package kind as a group of procedures and functions', () {
      final meta = ProviderMetaJson.read(answer('oracle/meta'));
      final package = meta.objectKinds.singleWhere((k) => k.id == 'package');

      expect(meta.isSql, isTrue);
      expect(meta.containerLevels.map((l) => l.id), ['schema']);
      expect(package.role, 'group');
      expect(package.hasSource, isTrue);
      expect(meta.objectKinds.singleWhere((k) => k.id == 'trigger').attachedTo, 'table');
      expect(package.childKinds, ['procedure', 'function']);
      expect(package.sourceLanguage, 'sql');
      expect(meta.objectKinds.where((k) => k.childKinds.isNotEmpty).map((k) => k.id), ['package']);
      expect(meta.objectKinds.where((k) => k.acceptsRowWrites).map((k) => k.id), ['table']);
      expect(meta.containerPathShapes, 'exact');
      expect(meta.schemaRefreshPattern, r'(CREATE|DROP|ALTER|TRUNCATE)\b');
      expect(meta.labels.selectAction, 'Select Top 50');
    });

    test('a package list holds an INVALID package and a valid one without a status', () {
      final objects = ObjectBrowserJson.objects(answer('oracle/list_package'));

      expect(objects.map((o) => o.name), ['APP_BROKEN_PKG', 'APP_ORDERS_PKG']);
      expect(objects.map((o) => o.status), ['INVALID', null]);
      expect(objects.every((o) => o.kind == 'package'), isTrue);
    });

    test('a package source has a specification part and a body part', () {
      final source = ObjectBrowserJson.source(answer('oracle/source_package'));

      expect(source.path, ['APP', 'APP_ORDERS_PKG']);
      expect(source.kind, 'package');
      expect(source.parts.map((p) => (p.id, p.label)), [('spec', 'Package specification'), ('body', 'Package body')]);
      final parts = source.parts.cast<SourceText>();
      expect(parts.every((p) => p.language == 'sql' && p.complete && p.truncated == null), isTrue);
      expect(parts.map((p) => p.origin), everyElement(SourceOrigin.regenerated));
      expect(parts.last.text, contains('PACKAGE BODY "APP"."APP_ORDERS_PKG"'));
    });
  });

  group('MSSQL', () {
    test('provider-meta has two container levels, Database then Schema', () {
      final meta = ProviderMetaJson.read(answer('mssql/meta'));

      expect(meta.containerLevels.map((l) => (l.id, l.label, l.labelPlural)), [
        ('catalog', 'Database', 'Databases'),
        ('schema', 'Schema', 'Schemas'),
      ]);
      expect(meta.supportsTransactions, isTrue);
      expect(meta.containerPathShapes, 'prefixes', reason: 'a database alone and a database and schema both address');
      expect(meta.objectKinds.map((k) => k.sourceLanguage), [null, 'sql', 'sql', 'sql', 'sql', null, null]);
      expect(meta.labels.searchPlaceholder, 'Search tables or columns...');
    });

    test('the first level lists the databases', () {
      final containers = ObjectBrowserJson.containers(answer('mssql/containers_database'));

      expect(containers.map((c) => c.name), ['app', 'master', 'msdb', 'tempdb']);
      expect(containers.every((c) => c.level == 0 && c.path.length == 1), isTrue);
      expect(containers.where((c) => c.isSessionDefault).single.name, 'app');
    });

    test('the second level lists the schemas of one database under its path', () {
      final containers = ObjectBrowserJson.containers(answer('mssql/containers_schema'));

      expect(containers.map((c) => c.path), [
        ['app', 'dbo'],
        ['app', 'guest'],
        ['app', 'sales'],
      ]);
      expect(containers.every((c) => c.level == 1), isTrue);
      expect(containers.where((c) => c.isSessionDefault).single.name, 'dbo');
    });
  });

  group('preview fields of provider-meta', () {
    test('MongoDB declares port 27017 and nothing else the row preview reads', () {
      final meta = ProviderMetaJson.read(answer('mongodb/meta'));
      expect(meta.defaultPort, 27017);
      expect(meta.statementTerminator, isNull);
      expect(meta.declaresPreviewProjection, isFalse);
      expect(meta.declaresPreviewTimeWindow, isFalse);
      expect(meta.spellsContainerNamesAsEngine, isFalse);
    });

    test('Oracle declares port 1521 and statementTerminator none', () {
      final meta = ProviderMetaJson.read(answer('oracle/meta'));
      expect(meta.defaultPort, 1521);
      expect(meta.statementTerminator, 'none');
      expect(meta.declaresPreviewProjection, isFalse);
      expect(meta.declaresPreviewTimeWindow, isFalse);
    });

    test('MSSQL declares port 1433 and the default terminator', () {
      final meta = ProviderMetaJson.read(answer('mssql/meta'));
      expect(meta.defaultPort, 1433);
      expect(meta.statementTerminator, isNull);
      expect(meta.identifierQuoting, isNull);
    });
  });

  group('edge answers', () {
    test('counts in all three states', () {
      final counts = ObjectBrowserJson.counts(answer('rabbitmq/counts'));

      expect(counts.keys, ['stream', 'queue', 'exchange']);
      expect(counts['stream'], isA<KindCountUnavailable>());
      expect((counts['stream']! as KindCountUnavailable).reason, startsWith('Other queue types fill'));
      expect(
        counts['queue'],
        const KindCounted(380, sampledFrom: 'one 500-name page of 1,200 queues and streams, by name'),
      );
      expect((counts['queue']! as KindCounted).isFloor, isTrue);
      expect(counts['exchange'], const KindCounted(7));
    });

    test('columns inferred from a document sample are marked sampled', () {
      final detail = ObjectBrowserJson.detail(answer('firestore/describe_collection'));

      expect(detail.columns.first.name, '__name__');
      expect(detail.columns.first.sampled, isFalse, reason: "a document's name is not sampled");
      expect(detail.columns.skip(1).every((c) => c.sampled), isTrue);
      expect(detail.columns.map((c) => c.type), ['reference', 'string', 'mixed(double|integer)', 'null', 'string']);
      expect(detail.indexes, isEmpty);
    });

    test('a detail whose indexes are unavailable keeps its columns and the engine sentence', () {
      final detail = ObjectBrowserJson.detail(answer('clickhouse/describe_indexes_unavailable'));

      expect(detail.columns.map((c) => c.name), ['event_id', 'day', 'user_id', 'channel']);
      expect(detail.columns.last.defaultValue, "'web'");
      expect(detail.indexes, isNull);
      expect(detail.indexesUnavailable, contains('Not enough privileges'));
    });

    test('a detail with an exclusion constraint reads its columns and indexes', () {
      final detail = ObjectBrowserJson.detail(answer('postgres/describe_exclusion'));

      expect(detail.path, ['public', 'reservations']);
      expect(detail.columns.map((c) => c.name), ['id', 'table_id', 'starts_at', 'ends_at', 'status']);
      expect(detail.indexes?.map((i) => i.name), ['reservations_no_overlapping_active', 'reservations_pkey']);
      expect(detail.foreignKeys, isEmpty);
      expect(detail.columns.map((c) => c.declaredType), [
        'integer',
        'integer',
        'timestamp without time zone',
        'timestamp without time zone',
        'text',
      ]);
      expect(detail.exclusionConstraints.single.name, 'reservations_no_overlapping_active');
      expect(
        detail.exclusionConstraints.single.definition,
        startsWith('EXCLUDE USING gist (table_id WITH =, tsrange('),
      );
    });

    test('a source whose truncated part counts collection ids, named only by Studio\'s reason', () {
      final source = ObjectBrowserJson.source(answer('firestore/source_document'));

      expect(source.parts.map((p) => p.id), ['data', 'document', 'subcollections']);
      final parts = source.parts.cast<SourceText>();
      expect(parts.map((p) => p.truncated), [
        null,
        null,
        const SourceTruncation(limit: 20, reason: 'Studio stopped listing collection ids after 10 requests'),
      ]);
      expect(parts.every((p) => p.language == 'json' && p.complete && p.origin == SourceOrigin.rendered), isTrue);
    });

    test('a source with a neutral statement part', () {
      final source = ObjectBrowserJson.source(answer('firestore/source_document_colon_id'));
      final statement = source.parts.last;

      expect(source.path, ['reports/2026:Q3']);
      expect(source.parts.take(2), everyElement(isA<SourceText>()));
      expect(statement, isA<SourceStatement>());
      expect((statement as SourceStatement).statement, startsWith('Studio cannot list the subcollections'));
    });
  });

  group('key scan', () {
    test('Firestore provider-meta declares level pages over a prefix walk with no total and no container level', () {
      final meta = ProviderMetaJson.read(answer('firestore/meta'));

      expect(meta.containerLevels, isEmpty);
      expect(
        meta.keyScan,
        const KeyScanSpec(
          defaultCount: 100,
          maxCount: 1000,
          separator: '/',
          cursor: 'opaque',
          pattern: 'prefix',
          totalScope: 'none',
          levels: KeyScanLevels(rootKind: 'collection'),
        ),
      );
      expect(meta.objectKinds.singleWhere((k) => k.id == 'document').keyBrowserOnly, isTrue);
    });

    test('etcd provider-meta declares a counted prefix walk with an opaque cursor and no levels', () {
      final meta = ProviderMetaJson.read(answer('etcd/meta'));

      expect(meta.containerLevels, isEmpty);
      expect(
        meta.keyScan,
        const KeyScanSpec(
          defaultCount: 500,
          maxCount: 1000,
          separator: '/',
          cursor: 'opaque',
          pattern: 'prefix',
          totalScope: 'walk',
        ),
      );
      expect(meta.objectKinds.singleWhere((k) => k.id == 'key').keyBrowserOnly, isTrue);
    });

    test('a Firestore level page carries its folders, the keys it left out and why the read is short', () {
      final page = ObjectBrowserJson.keyScanPage(answer('firestore/keyscan_level'));

      expect(page.keys, isEmpty);
      expect(page.prefixes, ['audit_log/', 'carts/', 'coupons/']);
      expect(page.isLast, isFalse);
      expect(page.cursor, startsWith('fsk1.'), reason: 'an opaque cursor, sent back as it came');
      expect(page.skipped?.count, 1);
      expect(page.skipped?.reason, startsWith("Ids that break Firestore's id rules"));
      expect(page.readOutcome?.isIncomplete, isTrue);
      expect(page.readOutcome?.endReason, startsWith('Studio stops after 10 id listing requests'));
      expect(page.readOutcome?.provenLoss, isEmpty);
      expect(page.clustered, isNull);
    });

    test('a Redis page from one node of a cluster says so', () {
      final page = ObjectBrowserJson.keyScanPage(answer('redis/keyscan_clustered'));

      expect(page.clustered, isTrue);
      expect(page.total, 2093);
      expect(page.keys, ['user:1', 'user:2', 'user:2:roles', 'session:9f2c']);
      expect(page.types['user:2'], 'hash');
      expect(page.prefixes, isNull);
      expect(page, isA<KeyScanPage>().having((p) => p.isLast, 'isLast', isFalse));
    });
  });

  // A field Studio sends in a hand-written answer that today's readers drop, with the issue that reads it.
  // That issue asserts the field in a reader test above and removes its line here.
  group('known gaps', () {
    dynamic json(String name) => jsonDecode(answer(name));

    final gaps = <(String issue, String answer, String field, Object? Function(dynamic json) sent)>[];

    for (final (issue, name, field, sent) in gaps) {
      test('$issue reads $field of $name', () {
        expect(sent(json(name)), isNotNull, reason: 'the answer must carry the field the gap names');
      });
    }
  });
}
