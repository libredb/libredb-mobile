import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_search_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

const _postgres = 'seed:dev-postgres';
const _server = 'seed:dev-postgres-server';
const _mssql = 'seed:mssql';

void main() {
  late MockIObjectBrowserRepository repository;
  late MockIProviderMetaRepository providerMeta;

  setUp(() {
    repository = MockIObjectBrowserRepository();
    providerMeta = MockIProviderMetaRepository();
  });

  void answerMeta(String connectionId, ProviderMeta meta) =>
      when(() => providerMeta.providerMeta(connectionId)).thenAnswer((_) async => Success(meta));

  void answerSearch(String connectionId, Result<List<DatabaseObject>> answer) => when(
    () => repository.search(
      connectionId,
      term: any(named: 'term'),
      kinds: any(named: 'kinds'),
    ),
  ).thenAnswer((_) async => answer);

  ObjectSearchBloc build(String connectionId) =>
      ObjectSearchBloc(repository: repository, providerMeta: providerMeta, connectionId: connectionId);

  List<String> terms() => [
    for (final call in verify(
      () => repository.search(
        any(),
        term: captureAny(named: 'term'),
        kinds: any(named: 'kinds'),
      ),
    ).captured)
      call as String,
  ];

  group('start', () {
    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'reads provider-meta and waits for a term, sending no search',
      setUp: () => answerMeta(_postgres, metaAnswer('meta_postgres')),
      build: () => build(_postgres),
      act: (bloc) => bloc.add(const ObjectSearchStarted()),
      expect: () => [
        isA<ObjectSearchIdle>().having((s) => s.meta.labels.searchPlaceholder, 'hint', 'Search tables or columns...'),
      ],
      verify: (_) => verifyNever(
        () => repository.search(
          any(),
          term: any(named: 'term'),
          kinds: any(named: 'kinds'),
        ),
      ),
    );

    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'fails with Studio\'s error when provider-meta cannot be read',
      setUp: () =>
          when(() => providerMeta.providerMeta(_postgres))
              .thenAnswer((_) async => const Failure(ServerError('down', code: 'studio.database_unreachable'))),
      build: () => build(_postgres),
      act: (bloc) => bloc.add(const ObjectSearchStarted()),
      expect: () => [
        isA<ObjectSearchFailure>()
            .having((s) => s.error.code, 'code', 'studio.database_unreachable')
            .having((s) => s.meta, 'meta', isNull),
      ],
    );
  });

  group('server-level connection', () {
    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'is not searchable when provider-meta declares catalogSessions, and never sends a search',
      setUp: () {
        answerMeta(_server, metaAnswer('meta_postgres_server'));
        answerSearch(_server, const Success([]));
      },
      build: () => build(_server),
      act: (bloc) async {
        bloc.add(const ObjectSearchStarted());
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const ObjectSearchTermChanged('orders'))
          ..add(const ObjectSearchSubmitted('orders'));
      },
      wait: ObjectSearchBloc.debounce * 2,
      expect: () => [const ObjectSearchNotAvailable()],
      verify: (_) => verifyNever(
        () => repository.search(
          any(),
          term: any(named: 'term'),
          kinds: any(named: 'kinds'),
        ),
      ),
    );
  });

  group('debounce', () {
    test('typing quickly sends one request, for the last term, once 400 ms pass without typing', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        for (final term in ['or', 'ord', 'orde']) {
          bloc.add(ObjectSearchTermChanged(term));
          async.elapse(const Duration(milliseconds: 300));
        }
        verifyNever(
          () => repository.search(
            any(),
            term: any(named: 'term'),
            kinds: any(named: 'kinds'),
          ),
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(terms(), ['orde']);

        async.elapse(const Duration(seconds: 2));
        verifyNever(
          () => repository.search(
            any(),
            term: any(named: 'term'),
            kinds: any(named: 'kinds'),
          ),
        );
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('a pause between two terms sends one request for each', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchTermChanged('or'));
        async.elapse(ObjectSearchBloc.debounce);
        bloc.add(const ObjectSearchTermChanged('ord'));
        async.elapse(ObjectSearchBloc.debounce);

        expect(terms(), ['or', 'ord']);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('a submit searches at once and drops the wait of the term typed before it', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc
          ..add(const ObjectSearchTermChanged('ord'))
          ..add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        expect(terms(), ['ord']);

        async.elapse(ObjectSearchBloc.debounce * 2);
        verifyNever(
          () => repository.search(
            any(),
            term: any(named: 'term'),
            kinds: any(named: 'kinds'),
          ),
        );
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });

  group('repeats', () {
    test('a submit after the pause sends nothing new for the term already searched', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchTermChanged('ord'));
        async.elapse(ObjectSearchBloc.debounce);
        bloc.add(const ObjectSearchSubmitted('ord'));
        async.elapse(ObjectSearchBloc.debounce * 2);

        expect(terms(), ['ord']);
        expect(bloc.state, isA<ObjectSearchResults>().having((s) => s.term, 'term', 'ord'));
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('a trailing space after the pause sends nothing new, typed or submitted', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchTermChanged('ord'));
        async.elapse(ObjectSearchBloc.debounce);
        bloc.add(const ObjectSearchTermChanged('ord '));
        async.elapse(ObjectSearchBloc.debounce);
        bloc.add(const ObjectSearchSubmitted('ord '));
        async.elapse(ObjectSearchBloc.debounce * 2);

        expect(terms(), ['ord']);
        expect(bloc.state, isA<ObjectSearchResults>());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('a submit while the same term is in flight sends nothing new', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        final answer = Completer<Result<List<DatabaseObject>>>();
        when(
          () => repository.search(
            _postgres,
            term: 'ord',
            kinds: any(named: 'kinds'),
          ),
        ).thenAnswer((_) => answer.future);
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchTermChanged('ord'));
        async.elapse(ObjectSearchBloc.debounce);
        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        answer.complete(Success(objectsAnswer('search_postgres')));
        async.flushMicrotasks();

        expect(terms(), ['ord']);
        expect(bloc.state, isA<ObjectSearchResults>());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('typing back to the term on screen drops the wait of the other term and sends nothing', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        bloc.add(const ObjectSearchTermChanged('orde'));
        async.elapse(const Duration(milliseconds: 200));
        bloc.add(const ObjectSearchTermChanged('ord'));
        async.elapse(ObjectSearchBloc.debounce * 2);

        expect(terms(), ['ord']);
        expect(bloc.state, isA<ObjectSearchResults>().having((s) => s.term, 'term', 'ord'));
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('the same term is sent again from a failure, so Retry works', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, const Failure(ValidationError('refused')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        expect(bloc.state, isA<ObjectSearchFailure>());
        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();

        expect(terms(), ['ord', 'ord']);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('the same term is sent again after a shorter one cleared the results', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        bloc.add(const ObjectSearchTermChanged('o'));
        async.flushMicrotasks();
        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();

        expect(terms(), ['ord', 'ord']);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });

  group('minimum length', () {
    test('a one-character term sends no request, typed or submitted, and spaces around it do not count', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, const Success([]));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc
          ..add(const ObjectSearchTermChanged('o'))
          ..add(const ObjectSearchSubmitted('o'))
          ..add(const ObjectSearchTermChanged('  o  '))
          ..add(const ObjectSearchSubmitted('  o  '))
          ..add(const ObjectSearchSubmitted('   '));
        async.elapse(const Duration(seconds: 2));

        verifyNever(
          () => repository.search(
            any(),
            term: any(named: 'term'),
            kinds: any(named: 'kinds'),
          ),
        );
        expect(bloc.state, isA<ObjectSearchIdle>());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('sends the term trimmed, as Studio compares it', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, const Success([]));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();

        bloc.add(const ObjectSearchSubmitted('  ord '));
        async.flushMicrotasks();

        expect(terms(), ['ord']);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('shortening the term below two characters drops the results on screen at once', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        async.flushMicrotasks();
        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        expect(bloc.state, isA<ObjectSearchResults>());

        bloc.add(const ObjectSearchTermChanged('o'));
        async.flushMicrotasks();

        expect(bloc.state, isA<ObjectSearchIdle>());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });

  group('restart', () {
    test('a new term cancels the search in flight, whose late answer is never shown', () {
      fakeAsync((async) {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        final first = Completer<Result<List<DatabaseObject>>>();
        when(
          () => repository.search(
            _postgres,
            term: 'or',
            kinds: any(named: 'kinds'),
          ),
        ).thenAnswer((_) => first.future);
        when(
          () => repository.search(
            _postgres,
            term: 'ord',
            kinds: any(named: 'kinds'),
          ),
        ).thenAnswer((_) async => Success(objectsAnswer('search_postgres')));
        final bloc = build(_postgres)..add(const ObjectSearchStarted());
        final states = <ObjectSearchState>[];
        final subscription = bloc.stream.listen(states.add);
        async.flushMicrotasks();

        bloc.add(const ObjectSearchSubmitted('or'));
        async.flushMicrotasks();
        bloc.add(const ObjectSearchSubmitted('ord'));
        async.flushMicrotasks();
        first.complete(
          const Success([
            DatabaseObject(path: ['public', 'colors'], name: 'colors', kind: 'table'),
          ]),
        );
        async.flushMicrotasks();

        expect(states.whereType<ObjectSearchResults>().map((s) => s.term), ['ord']);
        expect(bloc.state, isA<ObjectSearchResults>().having((s) => s.term, 'term', 'ord'));
        unawaited(subscription.cancel());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });

  group('results', () {
    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'ord on seed:dev-postgres finds orders and order_items, grouped by schema in Studio\'s order, each with its kind',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Success(objectsAnswer('search_postgres')));
      },
      build: () => build(_postgres),
      act: (bloc) async {
        bloc.add(const ObjectSearchStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectSearchSubmitted('ord'));
      },
      skip: 1,
      expect: () => [
        isA<ObjectSearchSearching>().having((s) => s.term, 'term', 'ord'),
        isA<ObjectSearchResults>()
            .having((s) => s.term, 'term', 'ord')
            .having((s) => [for (final g in s.groups) g.container], 'containers', [
              ['public'],
              ['sales'],
            ])
            .having((s) => [for (final m in s.groups.first.matches) m.object.name], 'public', [
              'order_items',
              'orders',
              'order_items_id_seq',
              'orders_id_seq',
              'orders_touch_updated_at',
            ])
            .having((s) => [for (final m in s.groups.first.matches) m.kind?.label], 'kinds', [
              'Table',
              'Table',
              'Sequence',
              'Sequence',
              'Trigger',
            ])
            .having((s) => [for (final m in s.groups.last.matches) m.object.name], 'sales', [
              'order_totals',
              'order_total',
            ]),
      ],
      verify: (_) => verify(() => repository.search(_postgres, term: 'ord')).called(1),
    );

    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'groups by the whole container path on an engine with two container levels',
      setUp: () {
        answerMeta(_mssql, metaAnswer('handwritten/mssql/meta'));
        answerSearch(
          _mssql,
          const Success([
            DatabaseObject(path: ['app', 'dbo', 'orders'], name: 'orders', kind: 'table'),
            DatabaseObject(path: ['app', 'sales', 'orders'], name: 'orders', kind: 'table'),
            DatabaseObject(path: ['app', 'dbo', 'order_view'], name: 'order_view', kind: 'view'),
          ]),
        );
      },
      build: () => build(_mssql),
      act: (bloc) async {
        bloc.add(const ObjectSearchStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectSearchSubmitted('ord'));
      },
      skip: 2,
      expect: () => [
        isA<ObjectSearchResults>()
            .having((s) => [for (final g in s.groups) g.container], 'containers', [
              ['app', 'dbo'],
              ['app', 'sales'],
            ])
            .having((s) => [for (final m in s.groups.first.matches) m.object.name], 'dbo', ['orders', 'order_view']),
      ],
    );

    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'keeps a match whose kind the engine does not declare, without a kind, rather than hiding it',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(
          _postgres,
          const Success([
            DatabaseObject(path: ['public', 'orders_q'], name: 'orders_q', kind: 'queue'),
          ]),
        );
      },
      build: () => build(_postgres),
      act: (bloc) async {
        bloc.add(const ObjectSearchStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectSearchSubmitted('ord'));
      },
      skip: 2,
      expect: () => [
        isA<ObjectSearchResults>()
            .having((s) => s.groups.single.matches.single.object.name, 'name', 'orders_q')
            .having((s) => s.groups.single.matches.single.kind, 'kind', isNull),
      ],
    );

    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'a 400 is a failure that keeps the term and provider-meta, so the search can be sent again',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, const Failure(ValidationError('too many pairs')));
      },
      build: () => build(_postgres),
      act: (bloc) async {
        bloc.add(const ObjectSearchStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectSearchSubmitted('ord'));
      },
      skip: 2,
      expect: () => [
        isA<ObjectSearchFailure>()
            .having((s) => s.error, 'error', isA<ValidationError>())
            .having((s) => s.error.code, 'code', isNull)
            .having((s) => s.term, 'term', 'ord')
            .having((s) => s.meta, 'meta', isNotNull),
      ],
    );

    blocTest<ObjectSearchBloc, ObjectSearchState>(
      'a CONFIG_ERROR keeps its code for the banner',
      setUp: () {
        answerMeta(_postgres, metaAnswer('meta_postgres'));
        answerSearch(_postgres, Failure(ValidationError('server', code: AppErrorCode.studioConfigError.key)));
      },
      build: () => build(_postgres),
      act: (bloc) async {
        bloc.add(const ObjectSearchStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectSearchSubmitted('ord'));
      },
      skip: 2,
      expect: () => [
        isA<ObjectSearchFailure>().having((s) => s.error.code, 'code', AppErrorCode.studioConfigError.key),
      ],
    );
  });
}
