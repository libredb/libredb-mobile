import 'dart:async';

import 'package:clock/clock.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/kind_counts_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/shared/models/object_container.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

void main() {
  late MockIObjectBrowserRepository repository;
  late MockIProviderMetaRepository providerMeta;

  setUp(() {
    repository = MockIObjectBrowserRepository();
    providerMeta = MockIProviderMetaRepository();
  });

  void answerMeta(String connectionId, ProviderMeta meta) =>
      when(() => providerMeta.providerMeta(connectionId)).thenAnswer((_) async => Success(meta));

  void answerContainers(String connectionId, List<String>? parent, List<ObjectContainer> containers) => when(
    () => repository.containers(
      connectionId,
      parent: parent,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => answered(containers));

  void answerCounts(String connectionId, List<String> container, Map<String, KindCount> counts) => when(
    () => repository.counts(
      connectionId,
      container: container,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => answered(counts));

  KindCountsBloc build(
    String connectionId,
    List<String> container, {
    Stream<String> schemaChanges = const Stream.empty(),
  }) => KindCountsBloc(
    repository: repository,
    providerMeta: providerMeta,
    connectionId: connectionId,
    container: container,
    schemaChanges: schemaChanges,
  );

  List<(String, Object)> rowsOf(KindCountsLoaded state) => [
    for (final section in state.sections)
      for (final row in section.rows)
        (
          row.kind.labelPlural,
          switch (row.count) {
            KindCounted(:final count, :final isFloor) => isFloor ? '$count+' : count,
            KindCountUnavailable(:final reason) => reason,
          },
        ),
  ];

  test('a kept answer shows the time Studio gave the counts, not the time the bloc got them', () async {
    final studioAt = DateTime.utc(2026, 10, 23, 14);
    when(() => providerMeta.providerMeta('seed:dev-postgres'))
        .thenAnswer((_) async => Success(metaAnswer('meta_postgres')));
    answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
    when(
      () => repository.counts(
        'seed:dev-postgres',
        container: ['public'],
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async => answered(countsAnswer('counts_postgres'), at: studioAt));
    final bloc = withClock(
      Clock.fixed(studioAt.add(const Duration(minutes: 9))),
      () => build('seed:dev-postgres', const ['public'])..add(const KindCountsRequested()),
    );
    addTearDown(bloc.close);

    final loaded = await bloc.stream.firstWhere((state) => state is KindCountsLoaded) as KindCountsLoaded;

    expect(loaded.loadedAt, studioAt);
  });

  blocTest<KindCountsBloc, KindCountsState>(
    'SQLite counts its kinds at the connection itself, with no container to name',
    setUp: () {
      answerMeta('seed:sample', metaAnswer('meta'));
      answerCounts('seed:sample', const [], countsAnswer('counts'));
    },
    build: () => build('seed:sample', const []),
    act: (bloc) => bloc.add(const KindCountsRequested()),
    expect: () => [
      const KindCountsLoading(),
      isA<KindCountsLoaded>()
          .having((s) => s.container, 'container', isNull)
          .having((s) => s.levelLabel, 'levelLabel', isNull)
          .having(rowsOf, 'rows', [('Tables', 6), ('Views', 2), ('Indexes', 0), ('Triggers', 0)]),
    ],
    verify: (_) => verifyNever(
      () => repository.containers(
        any(),
        parent: any(named: 'parent'),
        refresh: any(named: 'refresh'),
      ),
    ),
  );

  blocTest<KindCountsBloc, KindCountsState>(
    'a Postgres schema shows its counts under the schema\'s name and Studio\'s level label',
    setUp: () {
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      answerCounts('seed:dev-postgres', ['public'], countsAnswer('counts_postgres'));
    },
    build: () => build('seed:dev-postgres', ['public']),
    act: (bloc) => bloc.add(const KindCountsRequested()),
    expect: () => [
      const KindCountsLoading(),
      isA<KindCountsLoaded>()
          .having((s) => s.container?.name, 'name', 'public')
          .having((s) => s.levelLabel, 'levelLabel', 'Schema')
          .having(rowsOf, 'rows', [
            ('Tables', 4),
            ('Views', 0),
            ('Materialized Views', 0),
            ('Sequences', 3),
            ('Functions', 1),
            ('Procedures', 0),
            ('Triggers', 1),
          ]),
    ],
  );

  blocTest<KindCountsBloc, KindCountsState>(
    'an MSSQL schema finds itself under its database, at the second level',
    setUp: () {
      answerMeta('seed:mssql', metaAnswer('handwritten/mssql/meta'));
      answerContainers('seed:mssql', ['app'], containersAnswer('handwritten/mssql/containers_schema'));
      answerCounts('seed:mssql', ['app', 'sales'], const {'table': KindCounted(2)});
    },
    build: () => build('seed:mssql', ['app', 'sales']),
    act: (bloc) => bloc.add(const KindCountsRequested()),
    expect: () => [
      const KindCountsLoading(),
      isA<KindCountsLoaded>()
          .having((s) => s.container?.name, 'name', 'sales')
          .having((s) => s.levelLabel, 'levelLabel', 'Schema')
          .having(rowsOf, 'rows', [('Tables', 2)]),
    ],
  );

  blocTest<KindCountsBloc, KindCountsState>(
    'keeps a floor apart from an exact count and shows Studio\'s sentence for an unavailable one',
    setUp: () {
      answerMeta(
        'seed:rabbit',
        const ProviderMeta(
          queryLanguage: 'json',
          schemaRefreshPattern: 'x',
          containerLevels: [ContainerLevel(id: 'schema', label: 'Virtual host', labelPlural: 'Virtual hosts')],
          objectKinds: [
            ObjectKind(id: 'queue', role: 'relation', label: 'Queue', labelPlural: 'Queues'),
            ObjectKind(id: 'stream', role: 'relation', label: 'Stream', labelPlural: 'Streams'),
            ObjectKind(id: 'exchange', role: 'relation', label: 'Exchange', labelPlural: 'Exchanges'),
          ],
        ),
      );
      answerContainers('seed:rabbit', null, const [
        ObjectContainer(path: ['/'], name: '/', level: 0),
      ]);
      answerCounts('seed:rabbit', ['/'], countsAnswer('handwritten/rabbitmq/counts'));
    },
    build: () => build('seed:rabbit', ['/']),
    act: (bloc) => bloc.add(const KindCountsRequested()),
    skip: 1,
    expect: () => [
      isA<KindCountsLoaded>().having(rowsOf, 'rows', [
        ('Queues', '380+'),
        (
          'Streams',
          'Other queue types fill this virtual host\'s listing page, so Studio cannot list its streams; a stream is '
              'still readable by a typed read.',
        ),
        ('Exchanges', 7),
      ]),
    ],
  );

  blocTest<KindCountsBloc, KindCountsState>(
    'shows only the kinds a container names',
    setUp: () {
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, const [
        ObjectContainer(path: ['public'], name: 'public', level: 0, kinds: ['table', 'trigger']),
      ]);
      answerCounts('seed:dev-postgres', ['public'], countsAnswer('counts_postgres'));
    },
    build: () => build('seed:dev-postgres', ['public']),
    act: (bloc) => bloc.add(const KindCountsRequested()),
    skip: 1,
    expect: () => [
      isA<KindCountsLoaded>().having(rowsOf, 'rows', [('Tables', 4), ('Triggers', 1)]),
    ],
  );

  group('refresh', () {
    setUp(() {
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      answerCounts('seed:dev-postgres', ['public'], countsAnswer('counts_postgres'));
    });

    blocTest<KindCountsBloc, KindCountsState>(
      'reads the counts afresh through the cache\'s refresh path, keeping them on screen meanwhile',
      build: () => build('seed:dev-postgres', ['public']),
      act: (bloc) async {
        bloc.add(const KindCountsRequested());
        await bloc.stream.firstWhere((s) => s is KindCountsLoaded);
        bloc.add(const KindCountsRefreshed());
      },
      skip: 2,
      expect: () => [
        isA<KindCountsLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isTrue),
        isA<KindCountsLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isFalse),
      ],
      verify: (_) {
        verify(() => repository.counts('seed:dev-postgres', container: ['public'], refresh: false)).called(1);
        verify(() => repository.counts('seed:dev-postgres', container: ['public'], refresh: true)).called(1);
      },
    );

    const unreachable = ServerError('down', code: 'studio.database_unreachable');

    blocTest<KindCountsBloc, KindCountsState>(
      'a failed refresh keeps the counts it had under the error',
      setUp: () =>
          when(() => repository.counts('seed:dev-postgres', container: ['public'], refresh: true))
              .thenAnswer((_) async => const Failure(unreachable)),
      build: () => build('seed:dev-postgres', ['public']),
      act: (bloc) async {
        bloc.add(const KindCountsRequested());
        await bloc.stream.firstWhere((s) => s is KindCountsLoaded);
        bloc.add(const KindCountsRefreshed());
      },
      skip: 3,
      expect: () => [
        isA<KindCountsFailure>()
            .having((s) => s.error, 'error', unreachable)
            .having((s) => s.previous?.sections.first.rows.length, 'previous rows', 7),
      ],
    );

    blocTest<KindCountsBloc, KindCountsState>(
      'an offline refresh keeps the counts on screen without an error',
      setUp: () =>
          when(() => repository.counts('seed:dev-postgres', container: ['public'], refresh: true))
              .thenAnswer((_) async => Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key))),
      build: () => build('seed:dev-postgres', ['public']),
      act: (bloc) async {
        bloc.add(const KindCountsRequested());
        await bloc.stream.firstWhere((s) => s is KindCountsLoaded);
        bloc.add(const KindCountsRefreshed());
      },
      skip: 3,
      expect: () => [isA<KindCountsLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isFalse)],
    );
  });

  blocTest<KindCountsBloc, KindCountsState>(
    'shows why the counts could not be read',
    setUp: () {
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      when(() => repository.counts('seed:dev-postgres', container: ['public'], refresh: false))
          .thenAnswer((_) async => const Failure(ServerError('gone', code: 'studio.connection_not_available')));
    },
    build: () => build('seed:dev-postgres', ['public']),
    act: (bloc) => bloc.add(const KindCountsRequested()),
    expect: () => const [
      KindCountsLoading(),
      KindCountsFailure(error: ServerError('gone', code: 'studio.connection_not_available')),
    ],
  );

  group('schema change', () {
    late StreamController<String> changes;

    setUp(() {
      changes = StreamController<String>.broadcast();
      addTearDown(changes.close);
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      answerCounts('seed:dev-postgres', ['public'], countsAnswer('counts_postgres'));
    });

    blocTest<KindCountsBloc, KindCountsState>(
      'reloads the counts when a statement changed this connection\'s schema',
      build: () => build('seed:dev-postgres', ['public'], schemaChanges: changes.stream),
      act: (bloc) async {
        bloc.add(const KindCountsRequested());
        await bloc.stream.firstWhere((s) => s is KindCountsLoaded);
        changes
          ..add('seed:other')
          ..add('seed:dev-postgres');
      },
      wait: Duration.zero,
      verify: (_) =>
          verify(() => repository.counts('seed:dev-postgres', container: ['public'], refresh: false)).called(2),
    );
  });
}
