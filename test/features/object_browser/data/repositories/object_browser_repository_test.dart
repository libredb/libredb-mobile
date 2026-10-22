import 'package:flutter_bloc_advance/core/errors/app_error.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/database_object.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/kind_count.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/object_container.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/object_detail.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/object_source.dart';
import 'package:flutter_bloc_advance/features/object_browser/domain/entities/provider_meta.dart';
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

    test('providerMeta reads the capabilities and the tree shape', () async {
      final meta = data(await repository.providerMeta(connection));

      expect(meta.queryLanguage, 'sql');
      expect(meta.isSql, isTrue);
      expect(meta.supportsQueryCancel, isTrue);
      expect(meta.containerLevels, const [ContainerLevel(id: 'schema', label: 'Schema', labelPlural: 'Schemas')]);
      expect(meta.objectKinds.map((k) => k.id), ['table', 'view', 'function', 'trigger']);
      expect(meta.objectKinds.last.attachedTo, 'table');
      expect(meta.keyScan, isNull);
    });

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

  test('a request without a session fails with an AuthError', () async {
    final result = await repository.containers(connection);

    expect(result, isA<Failure<List<ObjectContainer>>>().having((f) => f.error, 'error', isA<AuthError>()));
  });
}
