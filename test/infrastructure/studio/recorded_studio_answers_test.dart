import 'dart:convert';
import 'dart:io';

import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/data/models/studio_identity_model.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_policy_model.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_test_result_model.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:libredb_mobile/features/studio_status/data/models/studio_status_json.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads answers recorded from a real Studio, so the readers are held to what Studio sends rather than to the
/// hand-written answers in assets/mock.
///
/// Recorded from Studio main at dbfea263 in tool/studio-dev, as user admin with a libredb-mobile access token, on the
/// built-in SQLite sample connection. SQLite has no transactions, so test/fixtures/studio/txstatus.json is Studio's
/// refusal of one. Record again after a Studio change to these routes.
///
/// The governed fixtures (`*_governed.json`, `governance_unavailable.json`, `admin_governance.json`) come from the
/// governed profile of tool/studio-dev, Studio main at dbfea263 in governance mode, recorded with a libredb-mobile access
/// token: as user, who holds a write grant on sales-dev and a read grant on sales-prod, and as admin for the governance
/// status. docs/studio.md describes the profile and how the unavailable source was produced.
/// The governed seed was generated from Studio 02dc26057, which has the same governance contract as dbfea263.
/// `health.json`, `ready.json`, `ready_governed.json` and `ready_degraded.json` (the governed Studio with its source
/// stopped) were recorded without a token, as the app sends them.
/// The Postgres fixtures (`*_postgres*.json`, and `txbegin.json`, `txquery.json` and `txcommit.json` on one database
/// of the server-level seed) come from the Postgres seeds of tool/studio-dev, Studio main at c9989a6b5, as user admin
/// with a libredb-mobile access token; docs/studio.md lists the seeds and the command that recorded each one.
/// The Redis fixtures (`*_redis*.json` and `keyscan_*.json`) come from seed:dev-redis of tool/studio-dev the same way;
/// `keyscan_requests.json` holds the body each recorded key-scan page was requested with.
void main() {
  String fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

  test('GET /api/auth/me of a bearer session', () {
    final identity = StudioIdentityModel.fromJsonString(fixture('me'));

    expect(identity.role, const StudioAdminRole());
    expect(identity.username, 'admin@example.com');
    expect(identity.viaBearer, isTrue);
  });

  test('POST /api/auth/logout of a bearer session', () {
    expect(() => StudioIdentityModel.readSignOutAccepted(fixture('logout')), returnsNormally);
  });

  test('GET /api/connections/managed', () {
    final managed = ManagedConnectionsModel.read(fixture('managed'));
    final connections = managed.connections;

    expect(connections.map((c) => c.id), ['seed:sqlite-embedded-sample', 'seed:libredb-embedded-sample']);
    expect(connections.map((c) => c.seedId), ['sqlite-embedded-sample', 'libredb-embedded-sample']);
    expect(connections.first.database, 'data/sample-employees.db');
    expect(connections.every((c) => !c.managed && !c.readOnly && c.color == null), isTrue);
    expect(managed.cacheHint, const Duration(minutes: 1));
  });

  test('GET /api/connections/policy without governance', () {
    final policy = ConnectionPolicyModel.fromJsonString(fixture('policy'));

    expect(policy.governance, isFalse);
  });

  test('GET /api/connections/managed under governance lists the granted connections', () {
    final managed = ManagedConnectionsModel.read(fixture('managed_governed'));
    final connections = managed.connections;

    expect(connections.map((c) => c.id), ['seed:sales-dev', 'seed:sales-prod']);
    expect(connections.map((c) => c.environment), ['development', 'production']);
    expect(connections.map((c) => c.group), ['Sales', 'Sales']);
    expect(connections.first.type, 'postgres');
    final raw = (jsonDecode(fixture('managed_governed')) as Map<String, dynamic>)['connections'] as List;
    expect(raw.map((c) => (c as Map)['user']), [
      'sales_writer',
      'sales_reader',
    ], reason: 'sales-prod is bound for read');
  });

  test('GET /api/connections/managed under governance reads the fields of a governed connection', () {
    final managed = ManagedConnectionsModel.read(fixture('managed_governed'));
    final connections = managed.connections;

    expect(connections.map((c) => c.color), ['#16a34a', '#dc2626']);
    expect(connections.map((c) => c.seedId), ['sales-dev', 'sales-prod']);
    expect(connections.every((c) => c.managed), isTrue);
    expect(
      connections.every((c) => !c.readOnly),
      isTrue,
      reason: 'a read grant is not the seed flag; the recorded Studio sends no access field',
    );
    expect(managed.cacheHint, const Duration(seconds: 10));
    final text = connections.map((c) => '$c ${c.props}').join();
    expect(text, isNot(contains('sales_writer')));
    expect(text, isNot(contains('sales_reader')));
  });

  test('GET /api/connections/policy under governance', () {
    final policy = ConnectionPolicyModel.fromJsonString(fixture('policy_governed'));

    expect(policy.customConnections, isFalse);
    expect(policy.governance, isTrue);
    expect(policy.statementCapture, 'full');
  });

  test('GET /api/connections/managed while the governance source is unavailable', () {
    final body = fixture('governance_unavailable');
    final error = studioError(FetchDataException(body, statusCode: 503, errorCode: ApiClient.errorCodeOf(body)));

    expect(error.code, AppErrorCode.studioGovernanceUnavailable.key);
  });

  test('GET /api/admin/governance of a loaded snapshot', () {
    // The app has no reader of this route yet; the test pins the fields an admin screen would show.
    final governance = (jsonDecode(fixture('admin_governance')) as Map<String, dynamic>)['governance'] as Map;

    expect(governance['source'], 'postgres');
    expect(governance['freshness'], 'ok');
    expect(governance['admittedConnections'], 2);
    expect(governance['skipped'], isEmpty);
    expect((governance['canary'] as Map).values, everyElement('ok'));
    expect(governance['settings'], contains(equals({'key': 'queryLog.statementCapture', 'source': 'runtime'})));
  });

  test('POST /api/db/test-connection', () {
    expect(ConnectionTestResultModel.fromJsonString(fixture('test')).latency, isNotNull);
  });

  test('POST /api/db/provider-meta of SQLite', () {
    final meta = ProviderMetaJson.read(fixture('meta'));

    expect(meta.isSql, isTrue);
    expect(meta.containerLevels, isEmpty, reason: 'SQLite has no container level');
    expect(meta.supportsTransactions, isFalse);
    expect(meta.objectKinds.map((k) => k.id), containsAll(['table', 'view']));
    expect(meta.schemaRefreshPattern, r'(CREATE|DROP|ALTER|TRUNCATE)\b');
    expect(meta.explainFormat, 'sqlite-queryplan');
    expect(meta.containerPathShapes, 'exact');
    expect(meta.supportsResultPagination, isTrue);
    expect(meta.objectKinds.where((k) => k.acceptsRowWrites).map((k) => k.id), ['table']);
    expect(meta.objectKinds.every((k) => k.sourceLanguage == 'sql'), isTrue);
    expect(meta.labels.entityNamePlural, 'Tables');
    expect(meta.labels.searchPlaceholder, 'Search tables or columns...');
  });

  test('POST /api/db/objects/containers of an engine without containers', () {
    expect(ObjectBrowserJson.containers(fixture('containers')), isEmpty);
  });

  test('POST /api/db/objects/counts', () {
    expect(ObjectBrowserJson.counts(fixture('counts')).keys, containsAll(['table', 'view']));
  });

  test('POST /api/db/objects/list and search', () {
    expect(ObjectBrowserJson.objects(fixture('list')).map((o) => o.name), contains('employee'));
    expect(ObjectBrowserJson.objects(fixture('search')), isNotEmpty);
  });

  test('POST /api/db/objects/describe', () {
    expect(ObjectBrowserJson.detail(fixture('describe')).columns, isNotEmpty);
  });

  test('POST /api/db/query with a page that has more rows', () {
    final result = SqlEditorJson.queryResult(fixture('query'));

    expect(result.rows, hasLength(2));
    expect(result.fields.first, 'emp_no');
    expect(result.columnTypes['emp_no'], 'INTEGER');
    expect(result.pagination?.hasMore, isTrue);
  });

  test('POST /api/db/query with a bind value', () {
    expect(SqlEditorJson.queryResult(fixture('queryparams')).rows.single['answer'], 42);
  });

  test('POST /api/db/multi-query that stops at a failed statement', () {
    final script = SqlEditorJson.scriptResult(fixture('multi'));

    expect(script.statementCount, 3);
    expect(script.executedCount, 2);
    expect(script.statements.last.error, contains('syntax error'));
  });

  test('POST /api/db/cancel of a run that is not running', () {
    expect(SqlEditorJson.cancelled(fixture('cancel')), isFalse);
  });

  test("a database error keeps the database's words", () {
    final error = studioError(
      BadRequestException(
        fixture('queryerror'),
        statusCode: 400,
        errorCode: ApiClient.errorCodeOf(fixture('queryerror')),
        serverMessage: 'near "FORM": syntax error',
      ),
    );

    expect(error.code, AppErrorCode.studioQueryError.key);
  });

  test('a transaction on an engine without transactions is a 400 without a code', () {
    expect(ApiClient.errorCodeOf(fixture('txstatus')), isNull);
  });

  group('the Postgres seeds of tool/studio-dev', () {
    test('GET /api/connections/managed lists the Postgres seeds without their password', () {
      final managed = ManagedConnectionsModel.read(fixture('managed_postgres'));
      final postgres = managed.connections.where((c) => c.type == 'postgres').toList();

      expect(postgres.map((c) => c.id), [
        'seed:dev-postgres',
        'seed:dev-postgres-server',
        'seed:dev-postgres-readonly',
      ]);
      expect(postgres.map((c) => c.environment), ['development', 'staging', 'development']);
      expect(postgres.map((c) => c.group), everyElement('Dev databases'));
      expect(postgres.map((c) => c.database), ['app', null, 'app']);
      expect(postgres.every((c) => c.managed), isTrue);
      expect(managed.connections.map((c) => c.id), contains('seed:sqlite-embedded-sample'));
      final raw = (jsonDecode(fixture('managed_postgres')) as Map<String, dynamic>)['connections'] as List;
      for (final connection in raw.cast<Map<String, dynamic>>().where((c) => c['type'] == 'postgres')) {
        expect(connection, isNot(contains('password')), reason: 'Studio keeps a managed seed\'s secrets');
      }
      expect(fixture('managed_postgres'), isNot(contains('-dev-not-for-production')));
    });

    test('POST /api/db/provider-meta of a database-level seed', () {
      final meta = ProviderMetaJson.read(fixture('meta_postgres'));

      expect(meta.isSql, isTrue);
      expect(meta.containerLevels.map((l) => l.id), ['schema']);
      expect(meta.catalogSessions, isFalse);
      expect(meta.supportsTransactions, isTrue);
      expect(
        meta.objectKinds.map((k) => k.id),
        containsAll(['table', 'view', 'materialized_view', 'sequence', 'function', 'procedure', 'trigger']),
      );
      expect(meta.objectKinds.where((k) => k.hasSource).map((k) => k.id), containsAll(['view', 'function']));
    });

    test('POST /api/db/provider-meta of a server-level seed', () {
      final meta = ProviderMetaJson.read(fixture('meta_postgres_server'));

      expect(meta.containerLevels.map((l) => l.id), ['catalog', 'schema']);
      expect(meta.catalogSessions, isTrue);
    });

    for (final name in ['meta_postgres', 'meta_postgres_server']) {
      test('POST /api/db/provider-meta of $name reads the labels and the schema refresh rule', () {
        final meta = ProviderMetaJson.read(fixture(name));

        expect(meta.schemaRefreshPattern, r'(CREATE|DROP|ALTER|TRUNCATE)\b');
        expect(meta.refreshesSchema('alter table public.orders add column x int'), isTrue);
        expect(meta.refreshesSchema('SELECT * FROM public.orders'), isFalse);
        expect(
          meta.labels,
          const ProviderLabels(
            entityName: 'Table',
            entityNamePlural: 'Tables',
            rowName: 'row',
            rowNamePlural: 'rows',
            selectAction: 'Select Top 50',
            generateAction: 'Generate Query',
            searchPlaceholder: 'Search tables or columns...',
          ),
        );
      });

      test('POST /api/db/provider-meta of $name reads the capability and kind fields', () {
        final meta = ProviderMetaJson.read(fixture(name));
        ObjectKind kind(String id) => meta.objectKinds.singleWhere((k) => k.id == id);

        expect(meta.explainFormat, 'postgres-json');
        expect(meta.queryDialect, isNull);
        expect(meta.maskingExemptColumns, isNull);
        expect(meta.supportsColumnProfiling, isNull);
        expect(meta.supportsSqlFormat, isNull);
        expect(meta.tablesAreDerivedGroupings, isFalse);
        expect(meta.identifierQuoting, isNull);
        expect(meta.containerPathShapes, 'exact');
        expect(meta.rowActions, isEmpty);
        expect(meta.keyScan, isNull);
        expect(kind('table').acceptsRowWrites, isTrue);
        expect(kind('view').sourceLanguage, 'pgsql');
        expect(kind('view').acceptsSourceEdits, isFalse);
        expect(kind('function').acceptsSourceEdits, isTrue);
        expect(kind('procedure').acceptsSourceEdits, isTrue);
        expect(kind('sequence').hasSource, isFalse);
        expect(kind('trigger').attachedTo, 'table');
        expect(meta.objectKinds.map((k) => k.childKinds), everyElement(isEmpty));
        expect(meta.objectKinds.map((k) => k.group), everyElement(isNull));
        expect(meta.objectKinds.where((k) => k.countIsListing || k.machineNamesWithheld || k.keyBrowserOnly), isEmpty);
      });
    }

    test('POST /api/db/objects/containers of a database-level seed lists its schemas', () {
      final containers = ObjectBrowserJson.containers(fixture('containers_postgres'));

      expect(
        containers.map((c) => c.path),
        containsAll([
          ['public'],
          ['sales'],
        ]),
      );
      expect(containers.map((c) => c.level), everyElement(0));
      expect(containers.singleWhere((c) => c.isSessionDefault).name, 'public');
    });

    test('POST /api/db/objects/containers of a server-level seed lists its databases', () {
      final containers = ObjectBrowserJson.containers(fixture('containers_postgres_server'));

      expect(containers.map((c) => c.name), containsAll(['app', 'archive']));
      expect(containers.map((c) => c.level), everyElement(0));
    });

    test('POST /api/db/objects/containers under one database of a server-level seed lists its schemas', () {
      final containers = ObjectBrowserJson.containers(fixture('containers_postgres_catalog'));

      expect(
        containers.map((c) => c.path),
        containsAll([
          ['app', 'public'],
          ['app', 'sales'],
        ]),
      );
      expect(containers.map((c) => c.level), everyElement(1));
    });

    test('POST /api/db/objects/counts of the public schema', () {
      final counts = ObjectBrowserJson.counts(fixture('counts_postgres'));

      expect(counts['table'], const KindCounted(4));
      expect(counts['view'], const KindCounted(0));
      expect(counts['function'], const KindCounted(1));
      expect(counts['trigger'], const KindCounted(1));
    });

    test('POST /api/db/objects/list of the tables in the public schema', () {
      final objects = ObjectBrowserJson.objects(fixture('list_postgres'));

      expect(objects.map((o) => o.name), ['column_types', 'customers', 'order_items', 'orders']);
      expect(objects.map((o) => o.kind), everyElement('table'));
      expect(objects.firstWhere((o) => o.name == 'orders').path, ['public', 'orders']);
    });

    test('POST /api/db/objects/describe of public.orders', () {
      final detail = ObjectBrowserJson.detail(fixture('describe_postgres_orders'));

      expect(detail.path, ['public', 'orders']);
      expect(detail.columns.map((c) => c.name), [
        'id',
        'customer_id',
        'status',
        'total',
        'placed_at',
        'updated_at',
        'note',
        'details',
        'receipt',
      ]);
      expect(detail.columns.firstWhere((c) => c.name == 'id').isPrimary, isTrue);
      expect(detail.columns.firstWhere((c) => c.name == 'note').nullable, isTrue);
      expect(detail.foreignKeys.single.columnName, 'customer_id');
      expect(detail.foreignKeys.single.referencedTable, contains('customers'));
      expect(detail.indexes!.map((i) => i.name), contains('orders_customer_id_idx'));
    });

    // Studio reads the keys from information_schema views, which show foreign keys only to the owner, and primary keys
    // only to the owner or a role with a non-SELECT privilege.
    test('POST /api/db/objects/describe of public.orders as a role that may only read has no keys', () {
      final detail = ObjectBrowserJson.detail(fixture('describe_postgres_orders_readonly'));

      expect(detail.columns.map((c) => c.name), contains('customer_id'));
      expect(detail.columns.where((c) => c.isPrimary), isEmpty);
      expect(detail.foreignKeys, isEmpty);
      expect(detail.indexes!.map((i) => i.name), containsAll(['orders_pkey', 'orders_customer_id_idx']));
    });

    test('POST /api/db/objects/source of a view', () {
      final source = ObjectBrowserJson.source(fixture('source_postgres_view'));
      final text = source.parts.whereType<SourceText>().first;

      expect(source.path, ['sales', 'order_totals']);
      expect(source.kind, 'view');
      expect(text.text, contains('order_items'));
      expect(text.language, 'pgsql');
      expect(text.complete, isFalse, reason: 'Studio regenerates the SELECT of a view, not its CREATE VIEW');
      expect(text.truncated, isFalse);
    });

    test('POST /api/db/objects/source of a function', () {
      final source = ObjectBrowserJson.source(fixture('source_postgres_function'));
      final text = source.parts.whereType<SourceText>().first;

      expect(source.kind, 'function');
      expect(source.path.first, 'sales');
      expect(text.text, contains('CREATE OR REPLACE FUNCTION sales.order_total'));
    });

    test('POST /api/db/objects/search for ord', () {
      final objects = ObjectBrowserJson.objects(fixture('search_postgres'));

      expect(objects.map((o) => o.name), containsAll(['orders', 'order_items']));
    });

    test('POST /api/db/query of one row of every column type', () {
      final result = SqlEditorJson.queryResult(fixture('query_types_postgres'));
      final row = result.rows.single;

      expect(result.fields.first, 'id');
      expect(result.fields.last, 'null_value');
      expect(row['null_value'], isNull);
      expect(result.columnTypes['bytea_value'], 'bytea');
      expect(result.columnTypes['jsonb_value'], 'jsonb');
    });

    test('POST /api/db/transaction begins on one database of a server-level seed', () {
      expect(SqlEditorJson.transactionBegun(fixture('txbegin')), isNull);
    });

    test('POST /api/db/transaction runs an UPDATE in that transaction', () {
      final run = SqlEditorJson.transactionRun(fixture('txquery'));

      expect(run.inTransaction, isTrue);
      expect(run.result!.rowCount, 1);
    });

    test('POST /api/db/transaction commits that transaction', () {
      // The app has no reader of this answer yet; #51 adds one.
      expect((jsonDecode(fixture('txcommit')) as Map<String, dynamic>)['status'], 'committed');
    });
  });

  group('the Redis seed of tool/studio-dev', () {
    test('POST /api/db/provider-meta of Redis', () {
      final meta = ProviderMetaJson.read(fixture('meta_redis'));
      ObjectKind kind(String id) => meta.objectKinds.singleWhere((k) => k.id == id);

      expect(meta.isSql, isFalse);
      expect(meta.queryLanguage, 'json');
      expect(meta.queryDialect, 'redis');
      expect(meta.containerLevels, const [ContainerLevel(id: 'schema', label: 'Database', labelPlural: 'Databases')]);
      expect(meta.supportsTransactions, isFalse);
      expect(meta.supportsResultPagination, isFalse);
      expect(meta.tablesAreDerivedGroupings, isTrue);
      expect(meta.objectKinds.map((k) => k.id), ['keyspace', 'function']);
      expect(kind('keyspace').hasColumns, isTrue);
      expect(kind('keyspace').hasSource, isFalse);
      expect(kind('function').sourceLanguage, 'lua');
      expect(kind('function').acceptsSourceEdits, isTrue);
    });

    test('POST /api/db/provider-meta of Redis reads the labels and the schema refresh rule', () {
      final meta = ProviderMetaJson.read(fixture('meta_redis'));

      expect(meta.schemaRefreshPattern, r'(DEL|FLUSHDB|FLUSHALL|RENAME)\b');
      expect(meta.refreshesSchema('del user:1'), isTrue);
      expect(meta.refreshesSchema('GET user:1'), isFalse);
      expect(
        meta.labels,
        const ProviderLabels(
          entityName: 'Key Pattern',
          entityNamePlural: 'Key Patterns',
          rowName: 'key',
          rowNamePlural: 'keys',
          selectAction: 'Scan Keys',
          generateAction: 'Generate Command',
          searchPlaceholder: 'Search keys...',
        ),
      );
    });

    test('POST /api/db/provider-meta of Redis declares the default key-scan shape', () {
      final keyScan = ProviderMetaJson.read(fixture('meta_redis')).keyScan!;
      final raw = (jsonDecode(fixture('meta_redis')) as Map<String, dynamic>)['capabilities']['keyScan'] as Map;

      expect(raw.keys, unorderedEquals(['defaultCount', 'maxCount']), reason: 'Redis declares no shape field');
      expect(keyScan, const KeyScanSpec(defaultCount: 500, maxCount: 1000));
      expect(keyScan.separator, ':');
      expect(keyScan.cursor, 'decimal');
      expect(keyScan.pattern, 'glob');
      expect(keyScan.totalScope, 'database');
      expect(keyScan.levels, isNull);
    });

    test('POST /api/db/objects/containers of Redis lists its numbered databases', () {
      final containers = ObjectBrowserJson.containers(fixture('containers_redis'));

      expect(containers.map((c) => c.path), [
        for (var i = 0; i < 16; i++) [i.toString()],
      ]);
      expect(containers.map((c) => c.level), everyElement(0));
      expect(containers.singleWhere((c) => c.isSessionDefault).name, '0');
    });

    test('POST /api/db/objects/counts of database 1', () {
      final counts = ObjectBrowserJson.counts(fixture('counts_redis'));

      expect(counts.keys, unorderedEquals(['keyspace', 'function']));
      expect(
        counts['keyspace'],
        const KindCounted(3, sampledFrom: 'the first 1,000 keys of one SCAN walk'),
        reason: 'the prefixes user, session and cache, from a walk Studio bounds at 1,000 keys',
      );
      expect(counts['function'], const KindCounted(0));
    });

    KeyScanPage page(String name) => ObjectBrowserJson.keyScanPage(fixture(name));
    Map<String, dynamic> request(String name) =>
        (jsonDecode(fixture('keyscan_requests')) as Map<String, dynamic>)[name] as Map<String, dynamic>;

    test('POST /api/db/keys/scan walks user:* in database 1 over several pages', () {
      for (final name in ['keyscan_first', 'keyscan_next', 'keyscan_last']) {
        final scanned = page(name);

        expect(request(name), containsPair('pattern', 'user:*'), reason: name);
        expect(request(name), containsPair('database', 1), reason: name);
        expect(scanned.keys, isNotEmpty, reason: name);
        expect(scanned.keys, everyElement(startsWith('user:')), reason: name);
        expect(scanned.types.keys, containsAll(scanned.keys), reason: '$name reads the type of every key');
        expect(scanned.total, 1207, reason: '$name counts every key of database 1');
      }
      expect(request('keyscan_first'), isNot(contains('cursor')), reason: 'a walk starts without a cursor');
      expect(page('keyscan_first').isLast, isFalse);
      expect(page('keyscan_next').isLast, isFalse);
      expect(page('keyscan_last').isLast, isTrue);
    });

    test('POST /api/db/keys/scan pages chain by the cursor of the page before', () {
      expect(request('keyscan_next')['cursor'], page('keyscan_first').cursor);
      expect(request('keyscan_last')['cursor'], isNot('0'));
      expect(page('keyscan_next').keys.toSet().intersection(page('keyscan_first').keys.toSet()), isEmpty);
    });

    test('POST /api/db/keys/scan reads the type of each key and covers every user:* key once', () {
      final pages = [
        for (final name in ['keyscan_first', 'keyscan_next', 'keyscan_last']) page(name),
      ];
      final keys = [for (final scanned in pages) ...scanned.keys];
      final types = {for (final scanned in pages) ...scanned.types};

      expect(keys, hasLength(1203));
      expect(keys.toSet(), hasLength(1203));
      expect(types['user:0001'], 'string');
      expect(types['user:2'], 'hash');
      expect(types['user:2:roles'], 'set');
      expect(types['user:2:profile'], 'string');
    });

    // One read per key type, each the statement Studio's key browser generates for it, run in database 1.
    test('POST /api/db/query reads a string', () {
      expect(SqlEditorJson.queryResult(fixture('query_redis_string')).rows, [
        {'result': 'hello from db1'},
      ]);
    });

    test('POST /api/db/query reads a string holding JSON as text', () {
      final result = SqlEditorJson.queryResult(fixture('query_redis_json'));

      expect(result.fields, ['result']);
      expect(jsonDecode(result.rows.single['result']! as String), {
        'name': 'Grace Hopper',
        'languages': ['en'],
        'active': true,
      });
    });

    test('POST /api/db/query reads a hash as field and value rows', () {
      final result = SqlEditorJson.queryResult(fixture('query_redis_hash'));

      expect(result.fields, ['field', 'value']);
      expect(result.rows.map((r) => r['field']), ['name', 'email', 'plan']);
      expect(result.rows.first['value'], 'Grace Hopper');
    });

    test('POST /api/db/query reads a list and a set as numbered rows', () {
      final list = SqlEditorJson.queryResult(fixture('query_redis_list'));
      final set = SqlEditorJson.queryResult(fixture('query_redis_set'));

      expect(list.fields, ['index', 'value']);
      expect(list.rows.map((r) => r['index']), [1, 2, 3]);
      expect(list.rows.map((r) => r['value']), ['login', 'run-query', 'logout']);
      expect(set.fields, ['index', 'value']);
      expect(set.rows.map((r) => r['value']), unorderedEquals(['analyst', 'viewer']));
    });

    test('POST /api/db/query reads a sorted set with each score as text', () {
      final result = SqlEditorJson.queryResult(fixture('query_redis_zset'));

      expect(result.fields, ['member', 'score']);
      expect(result.rows, [
        {'member': 'ada', 'score': '8'},
        {'member': 'linus', 'score': '17'},
        {'member': 'grace', 'score': '42'},
      ]);
    });

    test('POST /api/db/query reads a stream as one row per entry', () {
      final result = SqlEditorJson.queryResult(fixture('query_redis_stream'));

      expect(result.fields, ['id', 'action', 'device']);
      expect(result.rows.map((r) => r['id']), ['1700000000000-0', '1700000000001-0']);
      expect(result.rows.map((r) => r['action']), ['login', 'run-query']);
      expect(result.pagination?.hasMore, isFalse);
    });
  });

  // Studio 02dc26057 has the same health and ready routes as dbfea263.
  test('GET /api/health', () {
    StudioStatusJson.liveness(fixture('health'));
  });

  test('GET /api/ready without governance', () {
    expect(StudioStatusJson.readiness(fixture('ready')), const StudioReadinessReady());
  });

  test('GET /api/ready of the governed Studio', () {
    expect(StudioStatusJson.readiness(fixture('ready_governed')), const StudioReadinessOk());
  });

  // Recorded about 15 seconds after the governance source was stopped, while the connection routes answered
  // governance_unavailable.json.
  test('GET /api/ready of the governed Studio without its source is degraded, worded as temporarily unavailable', () {
    final readiness = StudioStatusJson.readiness(fixture('ready_degraded'));

    expect(readiness, const StudioReadinessDegraded());
    expect(GovernanceOutage.fromReadiness(readiness).kind, GovernanceOutageKind.temporarilyUnavailable);
  });
}
