import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_env.dart';

/// Each method against the recorded answers in assets/mock; the readers' edge cases are in object_browser_json_test.
void main() {
  late ObjectBrowserRepository repository;
  const connection = 'seed:sales-db';

  setUp(() {
    repository = ObjectBrowserRepository(TestEnv.apiClient());
  });

  T data<T>(Result<T> result) => (result as Success<T>).data;

  group('with a session', () {
    setUp(TestEnv.authenticate);

    test('containers reads the top level', () async {
      expect(data(await repository.containers(connection)), const [
        ObjectContainer(path: ['public'], name: 'public', level: 0, isSessionDefault: true),
        ObjectContainer(path: ['sales'], name: 'sales', level: 0),
      ]);
    });

    test('counts reads exact, floor and unavailable counts', () async {
      expect(data(await repository.counts(connection, container: const ['public'])), const {
        'table': KindCounted(42),
        'view': KindCounted(1000, sampledFrom: 'pg_class'),
        'function': KindCountUnavailable('permission denied for schema sales'),
        'trigger': KindCounted(3),
      });
    });

    test('list reads the objects of a kind', () async {
      final objects = data(await repository.list(connection, container: const ['public'], kind: 'table'));

      expect(
        objects.first,
        const DatabaseObject(
          path: ['public', 'orders'],
          name: 'orders',
          kind: 'table',
          rowCount: 12000,
          sizeBytes: 1835008,
        ),
      );
      expect(objects, hasLength(2));
    });

    test('describe reads columns, indexes and foreign keys', () async {
      final detail = data(await repository.describe(connection, path: const ['public', 'orders'], kind: 'table'));

      expect(
        detail.columns.first,
        const ColumnSchema(
          name: 'id',
          type: 'integer',
          nullable: false,
          isPrimary: true,
          defaultValue: "nextval('orders_id_seq'::regclass)",
        ),
      );
      expect(detail.indexes, const [
        IndexSchema(name: 'orders_pkey', columns: ['id'], unique: true),
      ]);
      expect(detail.foreignKeys, const [
        ForeignKeySchema(columnName: 'customer_id', referencedTable: 'customers', referencedColumn: 'id'),
      ]);
    });

    test('source reads text and unavailable parts', () async {
      final source = data(await repository.source(connection, path: const ['sales', 'order_totals'], kind: 'view'));

      expect(source.parts.first, isA<SourceText>().having((p) => p.language, 'language', 'sql'));
      expect(source.parts.last, const SourceUnavailable(id: 'comment', label: 'Comment', reason: 'no comment is set'));
    });

    test('search reads the matches', () async {
      final matches = data(await repository.search(connection, term: 'order'));

      expect(matches.map((o) => o.name), ['orders', 'order_totals']);
      expect(matches.last.status, 'INVALID');
    });

    test('scanKeys reads a page that is not the last', () async {
      final page = data(await repository.scanKeys(connection, pattern: 'session:*', count: 100));

      expect(
        page,
        const KeyScanPage(
          keys: ['session:1', 'session:2', 'cart:7'],
          cursor: '1792',
          types: {'session:1': 'hash', 'session:2': 'hash'},
          total: 1200,
        ),
      );
      expect(page.isLast, isFalse);
    });
  });

  group('what it sends', () {
    late _RecordingAdapter adapter;

    setUp(() {
      adapter = _RecordingAdapter();
      final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      repository = ObjectBrowserRepository(client);
    });

    // On a server-level connection the catalog is container[0]; Studio's list route reads no catalog field.
    test('list names the connection, the container path and the kind as JSON, and no catalog', () async {
      await repository.list(connection, container: const ['app', 'public'], kind: 'table');

      expect(adapter.lastPath, '/db/objects/list');
      expect(adapter.lastContentType, startsWith('application/json'));
      expect(adapter.lastBody, {
        'connectionId': connection,
        'container': ['app', 'public'],
        'kind': 'table',
      });
    });

    test('search names the connection and the term as JSON, and the kinds only when given', () async {
      await repository.search(connection, term: 'ord');

      expect(adapter.lastPath, '/db/objects/search');
      expect(adapter.lastContentType, startsWith('application/json'));
      expect(adapter.lastBody, {'connectionId': connection, 'term': 'ord'});

      await repository.search(connection, term: 'ord', kinds: const ['table']);

      expect(adapter.lastBody, {
        'connectionId': connection,
        'term': 'ord',
        'kinds': ['table'],
      });
    });
  });

  group('what scanKeys sends', () {
    late _RecordingAdapter adapter;

    setUp(() {
      adapter = _RecordingAdapter()..answer = (200, '{"keys":[],"cursor":"0","types":{},"total":0}');
      final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      repository = ObjectBrowserRepository(client);
    });

    test('the first page names no cursor, no level and nothing it was not given, as JSON', () async {
      await repository.scanKeys(connection);

      expect(adapter.lastPath, '/db/keys/scan');
      expect(adapter.lastContentType, startsWith('application/json'));
      expect(adapter.lastBody, {'connectionId': connection});
    });

    test('a later page sends the cursor exactly as the page before answered it', () async {
      const opaque = 'k:L2FwaXNpeC9yb3V0ZXMvMTI:4711:1207:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

      await repository.scanKeys(connection, cursor: opaque, pattern: '/apisix/');

      expect(adapter.lastBody, {'connectionId': connection, 'cursor': opaque, 'pattern': '/apisix/'});
    });

    test('a numbered database and a count travel as numbers', () async {
      await repository.scanKeys(connection, pattern: 'user:*', count: 500, database: 1);

      expect(adapter.lastBody, {'connectionId': connection, 'pattern': 'user:*', 'count': 500, 'database': 1});
    });

    test('a level page sends level true, and a walk of keys leaves the key out', () async {
      await repository.scanKeys(connection, pattern: 'users/', level: true);
      expect(adapter.lastBody, {'connectionId': connection, 'pattern': 'users/', 'level': true});

      await repository.scanKeys(connection, pattern: 'users/');
      expect(adapter.lastBody, {'connectionId': connection, 'pattern': 'users/'});
    });

    test('a prefix pattern travels as given, spaces and no star added', () async {
      await repository.scanKeys(connection, pattern: ' a/');

      expect((adapter.lastBody! as Map)['pattern'], ' a/');
    });

    test('a page refused by the audit log under governance maps to studio.governance_unavailable', () async {
      adapter.answer = (503, '{"error":"The audit log is unavailable","code":"AUDIT_UNAVAILABLE"}');

      final result = await repository.scanKeys(connection);

      expect((result as Failure).error.code, AppErrorCode.studioGovernanceUnavailable.key);
    });
  });

  test('a request without a session fails with an AuthError', () async {
    final result = await repository.containers(connection);

    expect(result, isA<Failure<List<ObjectContainer>>>().having((f) => f.error, 'error', isA<AuthError>()));
  });
}

const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
);

/// Answers every request with [answer] and records the last one.
class _RecordingAdapter implements HttpClientAdapter {
  (int, String) answer = (200, '[]');
  String? lastPath;
  String? lastContentType;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastContentType = options.contentType ?? '${options.headers[Headers.contentTypeHeader]}';
    final data = options.data;
    lastBody = data is String ? jsonDecode(data) : data;
    final (status, body) = answer;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
