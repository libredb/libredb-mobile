import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_detail_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

const _kindless = ProviderMeta(queryLanguage: 'sql', schemaRefreshPattern: '', containerLevels: [], objectKinds: []);

void main() {
  late MockIObjectBrowserRepository repository;
  late MockIProviderMetaRepository providerMeta;
  const connection = 'seed:dev-postgres';
  const orders = ['public', 'orders'];
  final at = DateTime.utc(2026, 10, 23, 9);

  setUp(() {
    repository = MockIObjectBrowserRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(connection)).thenAnswer((_) async => Success(metaAnswer('meta_postgres')));
  });

  void answerDescribe(List<String> path, Result<ObjectDetail> Function() answer) => when(
    () => repository.describe(
      connection,
      path: path,
      kind: 'table',
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => answer());

  void answerList(String kind, Result<List<DatabaseObject>> answer) => when(
    () => repository.list(
      connection,
      container: ['public'],
      kind: kind,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => answer);

  // Built under a fixed clock, which the bloc's handlers run in, so a loaded state's time is known.
  ObjectDetailBloc build({DateTime? now, Stream<String> schemaChanges = const Stream.empty()}) => withClock(
    Clock.fixed(now ?? at),
    () => ObjectDetailBloc(
      repository: repository,
      providerMeta: providerMeta,
      connectionId: connection,
      path: orders,
      kind: 'table',
      schemaChanges: schemaChanges,
    ),
  );

  final ordersDetail = detailAnswer('describe_postgres_orders');
  final tables = objectsAnswer('list_postgres');
  final customers = tables.firstWhere((object) => object.name == 'customers');
  final postgresMeta = metaAnswer('meta_postgres');
  final table = postgresMeta.objectKinds.firstWhere((kind) => kind.id == 'table');

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'describes the object, and a foreign key opens the table of that name the container lists',
    setUp: () {
      answerDescribe(orders, () => Success(ordersDetail));
      answerList('table', Success(tables));
    },
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [
      ObjectDetailLoaded(
        meta: postgresMeta,
        detail: ordersDetail,
        kind: table,
        foreignKeyTargets: {'customers': customers},
        loadedAt: at,
      ),
    ],
    verify: (_) {
      verify(() => repository.describe(connection, path: orders, kind: 'table', refresh: false)).called(1);
      verify(() => repository.list(connection, container: ['public'], kind: 'table', refresh: false)).called(1);
      verifyNever(() => repository.list(connection, container: ['public'], kind: 'view', refresh: false));
    },
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'looks in each kind with columns until it finds the referenced name, and leaves an unlisted one unresolved',
    setUp: () {
      answerDescribe(orders, () => Success(ordersDetail));
      answerList('table', Success(tables.where((object) => object.name != 'customers').toList()));
      answerList('view', const Success([]));
      answerList('materialized_view', const Success([]));
      answerList('sequence', const Success([]));
    },
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [
      ObjectDetailLoaded(
        meta: postgresMeta,
        detail: ordersDetail,
        kind: table,
        foreignKeyTargets: const {},
        loadedAt: at,
      ),
    ],
    verify: (_) {
      for (final kind in ['table', 'view', 'materialized_view', 'sequence']) {
        verify(() => repository.list(connection, container: ['public'], kind: kind, refresh: false)).called(1);
      }
      verifyNever(() => repository.list(connection, container: ['public'], kind: 'function', refresh: false));
      verifyNever(() => repository.list(connection, container: ['public'], kind: 'trigger', refresh: false));
    },
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'two objects of the referenced name leave the foreign key unresolved rather than guess',
    setUp: () {
      answerDescribe(orders, () => Success(ordersDetail));
      answerList(
        'table',
        Success([
          customers,
          const DatabaseObject(path: ['public', 'customers', 'x'], name: 'customers', kind: 'table'),
        ]),
      );
      answerList('view', const Success([]));
      answerList('materialized_view', const Success([]));
      answerList('sequence', const Success([]));
    },
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [
      ObjectDetailLoaded(
        meta: postgresMeta,
        detail: ordersDetail,
        kind: table,
        foreignKeyTargets: const {},
        loadedAt: at,
      ),
    ],
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'a list Studio refuses leaves the foreign key as text and keeps the refusal for the page to say so',
    setUp: () {
      answerDescribe(orders, () => Success(ordersDetail));
      answerList('table', const Failure(ServerError('refused')));
      answerList('view', const Success([]));
      answerList('materialized_view', const Success([]));
      answerList('sequence', const Success([]));
    },
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [
      ObjectDetailLoaded(
        meta: postgresMeta,
        detail: ordersDetail,
        kind: table,
        foreignKeyTargets: const {},
        foreignKeyLookupError: const ServerError('refused'),
        loadedAt: at,
      ),
    ],
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'an object without foreign keys lists nothing',
    setUp: () => answerDescribe(orders, () => Success(detailAnswer('describe_postgres_orders_readonly'))),
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [
      ObjectDetailLoaded(
        meta: postgresMeta,
        detail: detailAnswer('describe_postgres_orders_readonly'),
        kind: table,
        foreignKeyTargets: const {},
        loadedAt: at,
      ),
    ],
    verify: (_) => verifyNever(
      () => repository.list(
        any(),
        container: any(named: 'container'),
        kind: any(named: 'kind'),
        refresh: any(named: 'refresh'),
      ),
    ),
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'a kind the engine does not declare shows the detail without a kind',
    setUp: () {
      when(() => providerMeta.providerMeta(connection)).thenAnswer((_) async => const Success(_kindless));
      answerDescribe(orders, () => Success(ordersDetail));
    },
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [
      ObjectDetailLoaded(meta: _kindless, detail: ordersDetail, foreignKeyTargets: const {}, loadedAt: at),
    ],
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'keeps the error itself for the failure view, and reads again on a retry',
    setUp: () {
      var calls = 0;
      answerDescribe(
        orders,
        () => calls++ == 0
            ? const Failure(ServerError('gone', code: 'studio.connection_not_available'))
            : Success(ordersDetail),
      );
      answerList('table', Success(tables));
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ObjectDetailRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ObjectDetailRequested());
    },
    expect: () => [
      const ObjectDetailFailure(error: ServerError('gone', code: 'studio.connection_not_available')),
      const ObjectDetailLoading(),
      ObjectDetailLoaded(
        meta: postgresMeta,
        detail: ordersDetail,
        kind: table,
        foreignKeyTargets: {'customers': customers},
        loadedAt: at,
      ),
    ],
  );

  blocTest<ObjectDetailBloc, ObjectDetailState>(
    'a provider-meta failure is the page\'s failure',
    setUp: () =>
        when(() => providerMeta.providerMeta(connection)).thenAnswer((_) async => const Failure(ServerError('down'))),
    build: build,
    act: (bloc) => bloc.add(const ObjectDetailRequested()),
    expect: () => [const ObjectDetailFailure(error: ServerError('down'))],
    verify: (_) => verifyNever(
      () => repository.describe(
        any(),
        path: any(named: 'path'),
        kind: any(named: 'kind'),
        refresh: any(named: 'refresh'),
      ),
    ),
  );

  group('refresh', () {
    final loaded = ObjectDetailLoaded(
      meta: postgresMeta,
      detail: ordersDetail,
      kind: table,
      foreignKeyTargets: {'customers': customers},
      loadedAt: at,
    );
    final later = at.add(const Duration(minutes: 1));

    blocTest<ObjectDetailBloc, ObjectDetailState>(
      'takes the cache\'s refresh path for the describe and keeps the detail on screen meanwhile',
      setUp: () {
        answerDescribe(orders, () => Success(ordersDetail));
        answerList('table', Success(tables));
      },
      build: () => build(now: later),
      seed: () => loaded,
      act: (bloc) => bloc.add(const ObjectDetailRefreshed()),
      expect: () => [
        ObjectDetailLoaded(
          meta: postgresMeta,
          detail: ordersDetail,
          kind: table,
          foreignKeyTargets: {'customers': customers},
          loadedAt: at,
          isRefreshing: true,
        ),
        ObjectDetailLoaded(
          meta: postgresMeta,
          detail: ordersDetail,
          kind: table,
          foreignKeyTargets: {'customers': customers},
          loadedAt: later,
        ),
      ],
      verify: (_) =>
          verify(() => repository.describe(connection, path: orders, kind: 'table', refresh: true)).called(1),
    );

    blocTest<ObjectDetailBloc, ObjectDetailState>(
      'a failed refresh keeps what was shown under the error',
      setUp: () => answerDescribe(orders, () => const Failure(ServerError('down'))),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const ObjectDetailRefreshed()),
      expect: () => [
        ObjectDetailLoaded(
          meta: postgresMeta,
          detail: ordersDetail,
          kind: table,
          foreignKeyTargets: {'customers': customers},
          loadedAt: at,
          isRefreshing: true,
        ),
        ObjectDetailFailure(error: const ServerError('down'), previous: loaded),
      ],
    );

    blocTest<ObjectDetailBloc, ObjectDetailState>(
      'offline, a refresh that never left the device leaves the detail as it was',
      setUp: () =>
          answerDescribe(orders, () => Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key))),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const ObjectDetailRefreshed()),
      expect: () => [
        ObjectDetailLoaded(
          meta: postgresMeta,
          detail: ordersDetail,
          kind: table,
          foreignKeyTargets: {'customers': customers},
          loadedAt: at,
          isRefreshing: true,
        ),
        loaded,
      ],
    );
  });

  test(
    'a schema change of the connection describes the object again, and one of another connection does not',
    () async {
      answerDescribe(orders, () => Success(ordersDetail));
      answerList('table', Success(tables));
      final changes = StreamController<String>();
      final bloc = build(schemaChanges: changes.stream)..add(const ObjectDetailRequested());
      await bloc.stream.firstWhere((state) => state is ObjectDetailLoaded);

      changes.add('seed:other');
      await Future<void>.delayed(Duration.zero);
      changes.add(connection);
      await bloc.stream.firstWhere((state) => state is ObjectDetailLoaded && !state.isRefreshing);

      verify(() => repository.describe(connection, path: orders, kind: 'table', refresh: false)).called(2);
      await bloc.close();
      await changes.close();
    },
  );

  test('starts loading', () {
    expect(build().state, const ObjectDetailLoading());
  });
}
