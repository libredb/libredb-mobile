import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_list_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

const _postgres = 'seed:dev-postgres';
const _oracle = 'seed:oracle';

const _cities = [
  DatabaseObject(path: ['public', 'İstanbul'], name: 'İstanbul', kind: 'table'),
  DatabaseObject(path: ['public', 'ankara'], name: 'ankara', kind: 'table'),
  DatabaseObject(path: ['public', 'izmir_istanbul_route'], name: 'izmir_istanbul_route', kind: 'table'),
];

void main() {
  late MockIObjectBrowserRepository repository;
  late MockIProviderMetaRepository providerMeta;

  setUp(() {
    repository = MockIObjectBrowserRepository();
    providerMeta = MockIProviderMetaRepository();
  });

  void answerMeta(String connectionId, ProviderMeta meta) =>
      when(() => providerMeta.providerMeta(connectionId)).thenAnswer((_) async => Success(meta));

  void answerList(String connectionId, List<String> container, String kind, Result<List<DatabaseObject>> answer) =>
      when(
        () => repository.list(
          connectionId,
          container: container,
          kind: kind,
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answer);

  ObjectListBloc build(
    String connectionId,
    List<String> container,
    String kind, {
    Stream<String> schemaChanges = const Stream.empty(),
  }) => ObjectListBloc(
    repository: repository,
    providerMeta: providerMeta,
    connectionId: connectionId,
    container: container,
    kind: kind,
    schemaChanges: schemaChanges,
  );

  List<String> names(List<DatabaseObject> objects) => [for (final o in objects) o.name];

  group('load', () {
    blocTest<ObjectListBloc, ObjectListState>(
      'reads the kind\'s objects of the container through the repository, with the kind as the engine declares it',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerList(_postgres, ['public'], 'table', Success(objectsAnswer('list_postgres')));
      },
      build: () => build(_postgres, const ['public'], 'table'),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      expect: () => [
        const ObjectListLoading(),
        isA<ObjectListLoaded>()
            .having((s) => s.kind.labelPlural, 'kind', 'Tables')
            .having((s) => names(s.objects), 'objects', ['column_types', 'customers', 'order_items', 'orders'])
            .having((s) => s.visible, 'visible', objectsAnswer('list_postgres'))
            .having((s) => s.isFiltering, 'isFiltering', isFalse)
            .having((s) => s.childKindLabels, 'childKindLabels', isEmpty),
      ],
      verify: (_) =>
          verify(() => repository.list(_postgres, container: const ['public'], kind: 'table', refresh: false))
              .called(1),
    );

    blocTest<ObjectListBloc, ObjectListState>(
      'names a group kind\'s child kinds by their plural labels, so a package row can say what it holds',
      setUp: () {
        answerMeta(_oracle, metaAnswer('handwritten/oracle/meta'));
        answerList(_oracle, ['APP'], 'package', Success(objectsAnswer('handwritten/oracle/list_package')));
      },
      build: () => build(_oracle, const ['APP'], 'package'),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      expect: () => [
        const ObjectListLoading(),
        isA<ObjectListLoaded>()
            .having((s) => s.kind.role, 'role', 'group')
            .having((s) => s.childKindLabels, 'childKindLabels', ['Procedures', 'Functions'])
            .having((s) => [for (final o in s.objects) o.status], 'statuses', ['INVALID', null]),
      ],
    );

    blocTest<ObjectListBloc, ObjectListState>(
      'leaves out a child kind the engine does not declare rather than showing its raw id',
      setUp: () {
        answerMeta(
          _oracle,
          const ProviderMeta(
            queryLanguage: 'sql',
            schemaRefreshPattern: 'x',
            containerLevels: [],
            objectKinds: [
              ObjectKind(
                id: 'package',
                role: 'group',
                label: 'Package',
                labelPlural: 'Packages',
                childKinds: ['procedure', 'type_body'],
              ),
              ObjectKind(id: 'procedure', role: 'routine', label: 'Procedure', labelPlural: 'Procedures'),
            ],
          ),
        );
        answerList(_oracle, [], 'package', const Success([]));
      },
      build: () => build(_oracle, const [], 'package'),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      skip: 1,
      expect: () => [
        isA<ObjectListLoaded>().having((s) => s.childKindLabels, 'childKindLabels', ['Procedures']),
      ],
    );

    blocTest<ObjectListBloc, ObjectListState>(
      'refuses a kind the engine does not declare without asking Studio',
      setUp: () => answerMeta(_postgres, metaAnswer('meta_postgres')),
      build: () => build(_postgres, const ['public'], 'no_such_kind'),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      expect: () => [
        const ObjectListLoading(),
        isA<ObjectListFailure>().having((s) => s.error, 'error', isA<ValidationError>()),
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

    blocTest<ObjectListBloc, ObjectListState>(
      'fails with Studio\'s error when the list cannot be read',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerList(_postgres, ['public'], 'table', const Failure(ServerError('down')));
      },
      build: () => build(_postgres, const ['public'], 'table'),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      expect: () => [const ObjectListLoading(), const ObjectListFailure(error: ServerError('down'))],
    );

    blocTest<ObjectListBloc, ObjectListState>(
      'fails with the provider-meta error when the engine cannot be described',
      setUp: () =>
          when(() => providerMeta.providerMeta(_postgres))
              .thenAnswer((_) async => const Failure(ServerError('meta down'))),
      build: () => build(_postgres, const ['public'], 'table'),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      expect: () => [const ObjectListLoading(), const ObjectListFailure(error: ServerError('meta down'))],
    );
  });

  group('refresh', () {
    blocTest<ObjectListBloc, ObjectListState>(
      'takes the cache\'s refresh path and keeps the list on screen while Studio answers',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerList(_postgres, ['public'], 'table', const Success(_cities));
      },
      build: () => build(_postgres, const ['public'], 'table'),
      act: (bloc) async {
        bloc.add(const ObjectListRequested());
        await bloc.stream.firstWhere((s) => s is ObjectListLoaded);
        bloc.add(const ObjectListRefreshed());
      },
      skip: 2,
      expect: () => [
        isA<ObjectListLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isTrue),
        isA<ObjectListLoaded>().having((s) => s.isRefreshing, 'isRefreshing', isFalse),
      ],
      verify: (_) {
        verify(() => repository.list(_postgres, container: const ['public'], kind: 'table', refresh: false)).called(1);
        verify(() => repository.list(_postgres, container: const ['public'], kind: 'table', refresh: true)).called(1);
      },
    );

    test('a failed refresh keeps the list under the error, and an offline one keeps it without an error', () async {
      answerMeta(_postgres, metaAnswer('meta_postgres'));
      answerList(_postgres, ['public'], 'table', const Success(_cities));
      final bloc = build(_postgres, const ['public'], 'table')..add(const ObjectListRequested());
      final loaded = await bloc.stream.firstWhere((s) => s is ObjectListLoaded) as ObjectListLoaded;

      answerList(_postgres, ['public'], 'table', const Failure(ServerError('down')));
      bloc.add(const ObjectListRefreshed());
      final failed = await bloc.stream.firstWhere((s) => s is ObjectListFailure) as ObjectListFailure;
      expect(failed.previous?.objects, loaded.objects);

      answerList(
        _postgres,
        ['public'],
        'table',
        Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key)),
      );
      bloc.add(const ObjectListRefreshed());
      final kept = await bloc.stream.firstWhere((s) => s is ObjectListLoaded && !s.isRefreshing) as ObjectListLoaded;
      expect(kept.objects, loaded.objects);
      expect(kept.loadedAt, loaded.loadedAt);
      await bloc.close();
    });

    blocTest<ObjectListBloc, ObjectListState>(
      'loads again when a statement changed the connection\'s schema, and not for another connection',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerList(_postgres, ['public'], 'table', const Success(_cities));
      },
      build: () => build(
        _postgres,
        const ['public'],
        'table',
        schemaChanges: Stream.fromFutures([
          Future.delayed(const Duration(milliseconds: 20), () => 'seed:other'),
          Future.delayed(const Duration(milliseconds: 40), () => _postgres),
        ]),
      ),
      act: (bloc) => bloc.add(const ObjectListRequested()),
      wait: const Duration(milliseconds: 80),
      verify: (_) =>
          verify(() => repository.list(_postgres, container: const ['public'], kind: 'table', refresh: false))
              .called(2),
    );
  });

  group('filter', () {
    test('waits 200 ms after the last change, then shows what matches, folded as Studio\'s tree filter folds', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerList(_postgres, ['public'], 'table', const Success(_cities));
        final bloc = build(_postgres, const ['public'], 'table')..add(const ObjectListRequested());
        async.flushMicrotasks();

        bloc.add(const ObjectListFilterChanged('ist'));
        async.elapse(const Duration(milliseconds: 150));
        bloc.add(const ObjectListFilterChanged('istanbul'));
        async.elapse(const Duration(milliseconds: 199));
        expect((bloc.state as ObjectListLoaded).isFiltering, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        final state = bloc.state as ObjectListLoaded;
        expect(state.query, 'istanbul');
        expect(state.isFiltering, isTrue);
        expect(names(state.visible), ['İstanbul', 'izmir_istanbul_route']);
        expect(state.objects, _cities);

        verify(
          () => repository.list(
            any(),
            container: any(named: 'container'),
            kind: any(named: 'kind'),
            refresh: false,
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('matches the name only, never the path, and whitespace alone does not filter', () {
      fakeAsync((async) {
        const objects = [
          DatabaseObject(path: ['public', 'order_total(integer)'], name: 'order_total', kind: 'function'),
          DatabaseObject(path: ['public', 'integer_sum'], name: 'integer_sum', kind: 'function'),
        ];
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerList(_postgres, ['public'], 'function', const Success(objects));
        final bloc = build(_postgres, const ['public'], 'function')..add(const ObjectListRequested());
        async.flushMicrotasks();

        bloc.add(const ObjectListFilterChanged('integer'));
        async.elapse(const Duration(milliseconds: 200));
        expect(names((bloc.state as ObjectListLoaded).visible), ['integer_sum']);

        bloc.add(const ObjectListFilterChanged('   '));
        async.elapse(const Duration(milliseconds: 200));
        final state = bloc.state as ObjectListLoaded;
        expect(state.isFiltering, isFalse);
        expect(state.visible, objects);
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a filter typed while the list loads applies once it arrives, and survives a refresh', () async {
      answerMeta(_postgres, metaAnswer('meta_postgres'));
      final answer = Completer<Result<List<DatabaseObject>>>();
      when(() => repository.list(_postgres, container: const ['public'], kind: 'table', refresh: false))
          .thenAnswer((_) => answer.future);
      final bloc = build(_postgres, const ['public'], 'table')..add(const ObjectListRequested());
      bloc.add(const ObjectListFilterChanged('ankara'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      answer.complete(const Success(_cities));
      final loaded = await bloc.stream.firstWhere((s) => s is ObjectListLoaded) as ObjectListLoaded;
      expect(names(loaded.visible), ['ankara']);

      answerList(_postgres, ['public'], 'table', const Success(_cities));
      bloc.add(const ObjectListRefreshed());
      final refreshed =
          await bloc.stream.firstWhere((s) => s is ObjectListLoaded && !s.isRefreshing) as ObjectListLoaded;
      expect(refreshed.query, 'ankara');
      expect(names(refreshed.visible), ['ankara']);
      await bloc.close();
    });
  });
}
