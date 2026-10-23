import 'dart:async';

import 'package:clock/clock.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/container_browser_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/session_default_entry.dart';
import 'package:libredb_mobile/shared/models/object_container.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

void main() {
  late MockIObjectBrowserRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late StreamController<String?> connectionIds;
  late SessionDefaultEntry entry;

  setUp(() {
    repository = MockIObjectBrowserRepository();
    providerMeta = MockIProviderMetaRepository();
    connectionIds = StreamController<String?>.broadcast();
    entry = SessionDefaultEntry(connectionIds.stream);
    addTearDown(() async {
      await entry.dispose();
      await connectionIds.close();
    });
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

  ContainerBrowserBloc build(
    String connectionId, {
    List<String> parent = const [],
    Stream<String> schemaChanges = const Stream.empty(),
  }) => ContainerBrowserBloc(
    repository: repository,
    providerMeta: providerMeta,
    connectionId: connectionId,
    parent: parent,
    schemaChanges: schemaChanges,
    entry: entry,
  );

  Matcher loaded({required String label, required List<String> names, required int depth, List<String>? opens}) =>
      isA<ContainerBrowserLoaded>()
          .having((s) => s.level.labelPlural, 'level', label)
          .having((s) => s.containers.map((c) => c.name).toList(), 'names', names)
          .having((s) => s.depth, 'depth', depth)
          .having((s) => s.isRefreshing, 'isRefreshing', isFalse)
          .having((s) => s.openOnEntry?.path, 'openOnEntry', opens);

  test('a kept answer shows the time Studio gave it, not the time the bloc got it', () async {
    final studioAt = DateTime.utc(2026, 10, 23, 14);
    answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
    when(() => repository.containers('seed:dev-postgres', parent: null, refresh: any(named: 'refresh')))
        .thenAnswer((_) async => answered(containersAnswer('containers_postgres'), at: studioAt));
    final bloc = withClock(
      Clock.fixed(studioAt.add(const Duration(minutes: 9))),
      () => build('seed:dev-postgres')..add(const ContainerBrowserRequested()),
    );
    addTearDown(bloc.close);

    final loaded = await bloc.stream.firstWhere((state) => state is ContainerBrowserLoaded) as ContainerBrowserLoaded;

    expect(loaded.loadedAt, studioAt);
  });

  group('by depth', () {
    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'SQLite has no container level, so it asks for no containers',
      setUp: () => answerMeta('seed:sample', metaAnswer('meta')),
      build: () => build('seed:sample'),
      act: (bloc) => bloc.add(const ContainerBrowserRequested()),
      expect: () => const [ContainerBrowserLoading(), ContainerBrowserNoLevels(searchesObjects: true)],
      verify: (_) => verifyNever(
        () => repository.containers(
          any(),
          parent: any(named: 'parent'),
          refresh: any(named: 'refresh'),
        ),
      ),
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'seed:dev-postgres shows its schemas and opens the session default on the first entry',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) => bloc.add(const ContainerBrowserRequested()),
      expect: () => [
        const ContainerBrowserLoading(),
        loaded(label: 'Schemas', names: ['public', 'sales'], depth: 1, opens: ['public']),
      ],
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'seed:dev-postgres-server shows its databases, which name no session default, and declares catalogSessions',
      setUp: () {
        answerMeta('seed:dev-postgres-server', metaAnswer('meta_postgres_server'));
        answerContainers('seed:dev-postgres-server', null, containersAnswer('containers_postgres_server'));
      },
      build: () => build('seed:dev-postgres-server'),
      act: (bloc) => bloc
        ..add(const ContainerBrowserRequested())
        ..add(const ContainerBrowserFilterChanged('arch')),
      wait: ContainerBrowserBloc.filterDebounce,
      expect: () => [
        const ContainerBrowserLoading(),
        isA<ContainerBrowserLoaded>()
            .having((s) => s.containers.map((c) => c.name), 'names', ['app', 'archive', 'postgres'])
            .having((s) => s.openOnEntry, 'openOnEntry', isNull)
            .having((s) => s.catalogSessions, 'catalogSessions', isTrue),
        isA<ContainerBrowserLoaded>()
            .having((s) => s.visibleContainers.map((c) => c.name), 'filtered', ['archive'])
            .having((s) => s.catalogSessions, 'catalogSessions kept by a filter', isTrue),
      ],
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'seed:dev-postgres declares no catalogSessions',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) => bloc.add(const ContainerBrowserRequested()),
      expect: () => [
        const ContainerBrowserLoading(),
        isA<ContainerBrowserLoaded>().having((s) => s.catalogSessions, 'catalogSessions', isFalse),
      ],
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'seed:dev-postgres-server shows the schemas of a database at the second level',
      setUp: () {
        answerMeta('seed:dev-postgres-server', metaAnswer('meta_postgres_server'));
        answerContainers('seed:dev-postgres-server', ['app'], containersAnswer('containers_postgres_catalog'));
      },
      build: () => build('seed:dev-postgres-server', parent: ['app']),
      act: (bloc) => bloc.add(const ContainerBrowserRequested()),
      expect: () => [
        const ContainerBrowserLoading(),
        // The user opened the database, so the first entry does not reach this level.
        loaded(label: 'Schemas', names: ['public', 'sales'], depth: 2),
      ],
      verify: (_) =>
          verify(() => repository.containers('seed:dev-postgres-server', parent: ['app'], refresh: false)).called(1),
    );

    test('MSSQL opens its default database and then that database\'s default schema on the first entry', () async {
      answerMeta('seed:mssql', metaAnswer('handwritten/mssql/meta'));
      answerContainers('seed:mssql', null, containersAnswer('handwritten/mssql/containers_database'));
      answerContainers('seed:mssql', ['app'], containersAnswer('handwritten/mssql/containers_schema'));

      final top = build('seed:mssql')..add(const ContainerBrowserRequested());
      final topLoaded = await top.stream.firstWhere((s) => s is ContainerBrowserLoaded) as ContainerBrowserLoaded;
      expect(topLoaded.level.labelPlural, 'Databases');
      expect(topLoaded.depth, 2);
      expect(topLoaded.openOnEntry?.path, ['app']);

      final schemas = build('seed:mssql', parent: ['app'])..add(const ContainerBrowserRequested());
      final schemasLoaded =
          await schemas.stream.firstWhere((s) => s is ContainerBrowserLoaded) as ContainerBrowserLoaded;
      expect(schemasLoaded.level.labelPlural, 'Schemas');
      expect(schemasLoaded.containers.map((c) => c.name), ['dbo', 'guest', 'sales']);
      expect(schemasLoaded.openOnEntry?.path, ['app', 'dbo']);
      expect(schemasLoaded.opensKinds(schemasLoaded.containers.first), isTrue);
      expect(topLoaded.opensKinds(topLoaded.containers.first), isFalse);
      await top.close();
      await schemas.close();
    });
  });

  group('the first entry', () {
    test('opens the session default once, not when the user comes back to the level', () async {
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));

      Future<ContainerBrowserLoaded> open() async {
        final bloc = build('seed:dev-postgres')..add(const ContainerBrowserRequested());
        addTearDown(bloc.close);
        return await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded) as ContainerBrowserLoaded;
      }

      expect((await open()).openOnEntry?.path, ['public']);
      expect((await open()).openOnEntry, isNull);
    });

    test('starts again when another connection becomes active', () async {
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));

      Future<ContainerBrowserLoaded> open() async {
        final bloc = build('seed:dev-postgres')..add(const ContainerBrowserRequested());
        addTearDown(bloc.close);
        return await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded) as ContainerBrowserLoaded;
      }

      expect((await open()).openOnEntry?.path, ['public']);
      connectionIds.add('seed:other');
      connectionIds.add('seed:dev-postgres');
      await Future<void>.delayed(Duration.zero);
      expect((await open()).openOnEntry?.path, ['public']);
    });

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'a pull to refresh never opens the session default',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
        entry.take('seed:dev-postgres', const [], const []);
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        bloc.add(const ContainerBrowserRefreshed());
      },
      skip: 2,
      expect: () => [
        isA<ContainerBrowserLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isTrue),
        loaded(label: 'Schemas', names: ['public', 'sales'], depth: 1),
      ],
    );
  });

  group('refresh', () {
    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'reads the level afresh through the cache\'s refresh path, keeping it on screen meanwhile',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        bloc.add(const ContainerBrowserRefreshed());
      },
      skip: 2,
      expect: () => [
        isA<ContainerBrowserLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isTrue),
        isA<ContainerBrowserLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isFalse),
      ],
      verify: (_) {
        verify(() => repository.containers('seed:dev-postgres', parent: null, refresh: false)).called(1);
        verify(() => repository.containers('seed:dev-postgres', parent: null, refresh: true)).called(1);
      },
    );

    const unavailable = ServerError('down', code: 'studio.database_unreachable');

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'a failed refresh keeps the level it had under the error',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
        when(() => repository.containers('seed:dev-postgres', parent: null, refresh: true))
            .thenAnswer((_) async => const Failure(unavailable));
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        bloc.add(const ContainerBrowserRefreshed());
      },
      skip: 3,
      expect: () => [
        isA<ContainerBrowserFailure>()
            .having((s) => s.error, 'error', unavailable)
            .having((s) => s.previous?.containers.length, 'previous', 2),
      ],
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'an offline refresh keeps the level on screen without an error, for the page to mark it stale',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
        when(() => repository.containers('seed:dev-postgres', parent: null, refresh: true))
            .thenAnswer((_) async => Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key)));
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        bloc.add(const ContainerBrowserRefreshed());
      },
      skip: 3,
      expect: () => [
        loaded(label: 'Schemas', names: ['public', 'sales'], depth: 1, opens: null),
      ],
    );
  });

  group('failure', () {
    const refused = ServerError('gone', code: 'studio.connection_not_available');

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'shows why the containers could not be read',
      setUp: () {
        answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
        when(() => repository.containers('seed:dev-postgres', parent: null, refresh: false))
            .thenAnswer((_) async => const Failure(refused));
      },
      build: () => build('seed:dev-postgres'),
      act: (bloc) => bloc.add(const ContainerBrowserRequested()),
      expect: () => const [ContainerBrowserLoading(), ContainerBrowserFailure(error: refused)],
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'shows why provider-meta could not be read, and asks for no containers',
      setUp: () =>
          when(() => providerMeta.providerMeta('seed:dev-postgres')).thenAnswer((_) async => const Failure(refused)),
      build: () => build('seed:dev-postgres'),
      act: (bloc) => bloc.add(const ContainerBrowserRequested()),
      expect: () => const [ContainerBrowserLoading(), ContainerBrowserFailure(error: refused)],
      verify: (_) => verifyNever(
        () => repository.containers(
          any(),
          parent: any(named: 'parent'),
          refresh: any(named: 'refresh'),
        ),
      ),
    );
  });

  group('schema change', () {
    late StreamController<String> changes;

    setUp(() {
      changes = StreamController<String>.broadcast();
      addTearDown(changes.close);
      answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
    });

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'reloads the level when a statement changed this connection\'s schema',
      build: () => build('seed:dev-postgres', schemaChanges: changes.stream),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        changes.add('seed:dev-postgres');
      },
      wait: Duration.zero,
      verify: (_) => verify(() => repository.containers('seed:dev-postgres', parent: null, refresh: false)).called(2),
    );

    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'ignores a schema change of another connection',
      build: () => build('seed:dev-postgres', schemaChanges: changes.stream),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        changes.add('seed:other');
      },
      wait: Duration.zero,
      verify: (_) => verify(() => repository.containers('seed:dev-postgres', parent: null, refresh: false)).called(1),
    );
  });

  group('filter', () {
    blocTest<ContainerBrowserBloc, ContainerBrowserState>(
      'narrows the level by name after 200 ms, folded as Studio\'s tree filter folds, without a request, across a refresh',
      setUp: () {
        answerMeta('seed:dev-postgres-server', metaAnswer('meta_postgres_server'));
        answerContainers('seed:dev-postgres-server', null, const [
          ObjectContainer(path: ['İstanbul'], name: 'İstanbul', level: 0),
          ObjectContainer(path: ['ankara'], name: 'ankara', level: 0),
        ]);
      },
      build: () => build('seed:dev-postgres-server'),
      act: (bloc) async {
        bloc.add(const ContainerBrowserRequested());
        await bloc.stream.firstWhere((s) => s is ContainerBrowserLoaded);
        bloc.add(const ContainerBrowserFilterChanged('ist'));
        bloc.add(const ContainerBrowserFilterChanged('istanbul'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        bloc.add(const ContainerBrowserRefreshed());
      },
      wait: const Duration(milliseconds: 50),
      skip: 2,
      expect: () => [
        isA<ContainerBrowserLoaded>()
            .having((s) => s.query, 'query', 'istanbul')
            .having((s) => s.visibleContainers.map((c) => c.name), 'visible', ['İstanbul'])
            .having((s) => s.containers, 'containers', hasLength(2)),
        isA<ContainerBrowserLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isTrue),
        isA<ContainerBrowserLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isFalse).having(
          (s) => s.visibleContainers.map((c) => c.name),
          'visible',
          ['İstanbul'],
        ),
      ],
      verify: (_) {
        verify(() => repository.containers('seed:dev-postgres-server', parent: null, refresh: false)).called(1);
        verify(() => repository.containers('seed:dev-postgres-server', parent: null, refresh: true)).called(1);
      },
    );
  });
}
