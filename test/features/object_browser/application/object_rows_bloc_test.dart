import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_rows_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

QueryResult _recorded(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

void main() {
  late MockIStatementRepository statements;
  late MockIProviderMetaRepository providerMeta;
  const postgres = 'seed:dev-postgres';
  const server = 'seed:dev-postgres-server';
  const customers = ['public', 'customers'];
  const preview = 'SELECT * FROM public.customers;';
  final customerRows = _recorded('query_preview_postgres_customers');

  setUp(() {
    statements = MockIStatementRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(postgres)).thenAnswer((_) async => Success(metaAnswer('meta_postgres')));
    when(() => providerMeta.providerMeta(server)).thenAnswer((_) async => Success(metaAnswer('meta_postgres_server')));
  });

  var ids = 0;
  ObjectRowsBloc build({String connectionId = postgres, List<String> path = customers, String kind = 'table'}) =>
      ObjectRowsBloc(
        statements: statements,
        providerMeta: providerMeta,
        connectionId: connectionId,
        path: path,
        kind: kind,
        newRunId: () => 'run-${++ids}',
      );

  void answerRun(String connectionId, Result<QueryResult> Function() answer) => when(
    () => statements.run(
      connectionId,
      any(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      catalog: any(named: 'catalog'),
    ),
  ).thenAnswer((_) async => answer());

  group('generate, then run', () {
    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'runs Studio\'s preview with a page of 50, a fresh run id and no catalog, and masks the answer',
      setUp: () => answerRun(postgres, () => Success(customerRows)),
      build: build,
      act: (bloc) => bloc.add(const ObjectRowsRequested(role: StudioUserRole())),
      expect: () => [
        isA<ObjectRowsLoaded>()
            .having((s) => s.preview, 'preview', const PreviewStatement(statement: preview))
            .having((s) => s.masked.maskedColumns, 'masked columns', {'email', 'card_number'})
            .having((s) => s.masked.result.rows.first['email'], 'masked email', isNot('ada@example.com'))
            .having((s) => s.masked.result.rows.first['card_number'], 'masked card', isNot('4111111111111111'))
            .having((s) => s.masked.result.rows.first['name'], 'clear name', 'Ada Lovelace')
            .having((s) => s.policy, 'policy', MaskingPolicy.forRole(const StudioUserRole()))
            .having((s) => s.kind.id, 'kind', 'table')
            .having((s) => s.isRefreshing, 'refreshing', isFalse),
      ],
      verify: (_) {
        final call = verify(
          () => statements.run(
            postgres,
            preview,
            queryId: captureAny(named: 'queryId'),
            page: const QueryPage(limit: 50),
            catalog: null,
          ),
        )..called(1);
        expect(call.captured.single, startsWith('run-'));
      },
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'on a server-level connection runs the full path in the catalog of the path',
      setUp: () => answerRun(server, () => Success(_recorded('query_preview_postgres_server_orders'))),
      build: () => build(connectionId: server, path: const ['app', 'public', 'orders']),
      act: (bloc) => bloc.add(const ObjectRowsRequested(role: StudioAdminRole())),
      expect: () => [isA<ObjectRowsLoaded>().having((s) => s.masked.result.rows, 'rows', hasLength(4))],
      verify: (_) => verify(
        () => statements.run(
          server,
          'SELECT * FROM app.public.orders;',
          queryId: any(named: 'queryId'),
          page: const QueryPage(limit: 50),
          catalog: 'app',
        ),
      ).called(1),
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'a role not yet loaded masks with the user settings',
      setUp: () => answerRun(postgres, () => Success(customerRows)),
      build: build,
      act: (bloc) => bloc.add(const ObjectRowsRequested(role: null)),
      expect: () => [
        isA<ObjectRowsLoaded>().having((s) => s.policy, 'policy', MaskingPolicy.forRole(null)).having(
          (s) => s.masked.maskedColumns,
          'masked columns',
          {'email', 'card_number'},
        ),
      ],
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'each run takes a new run id',
      setUp: () => answerRun(postgres, () => Success(customerRows)),
      build: build,
      act: (bloc) async {
        bloc.add(const ObjectRowsRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectRowsRequested(role: null));
      },
      skip: 1,
      verify: (_) {
        final ids = verify(
          () => statements.run(
            postgres,
            preview,
            queryId: captureAny(named: 'queryId'),
            page: any(named: 'page'),
            catalog: any(named: 'catalog'),
          ),
        ).captured;
        expect(ids, hasLength(2));
        expect(ids.toSet(), hasLength(2));
      },
    );
  });

  group('refused', () {
    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'a preview the generator refuses runs nothing and says so',
      setUp: () =>
          when(() => providerMeta.providerMeta('seed:dev-redis'))
              .thenAnswer((_) async => Success(metaAnswer('meta_redis'))),
      build: () => build(connectionId: 'seed:dev-redis', path: const ['0', 'user:*'], kind: 'keyspace'),
      act: (bloc) => bloc.add(const ObjectRowsRequested(role: null)),
      expect: () => [isA<ObjectRowsUnavailable>()],
      verify: (_) => verifyNever(() => statements.run(any(), any(), page: any(named: 'page'))),
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'a kind the engine does not declare is a failure, and nothing runs',
      build: () => build(kind: 'nonesuch'),
      act: (bloc) => bloc.add(const ObjectRowsRequested(role: null)),
      expect: () => [isA<ObjectRowsFailure>().having((s) => s.error, 'error', isA<ValidationError>())],
      verify: (_) => verifyNever(() => statements.run(any(), any(), page: any(named: 'page'))),
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'a provider-meta failure is the page\'s failure, and nothing runs',
      setUp: () =>
          when(() => providerMeta.providerMeta(postgres)).thenAnswer((_) async => const Failure(ServerError('down'))),
      build: build,
      act: (bloc) => bloc.add(const ObjectRowsRequested(role: null)),
      expect: () => [const ObjectRowsFailure(error: ServerError('down'))],
      verify: (_) => verifyNever(() => statements.run(any(), any(), page: any(named: 'page'))),
    );
  });

  group('a failed run', () {
    const refused = ValidationError('permission denied for table customers', code: 'studio.query_error');

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'keeps the error itself, the engine and the kind, and is not run again until the user asks',
      setUp: () => answerRun(postgres, () => const Failure(refused)),
      build: build,
      act: (bloc) async {
        bloc.add(const ObjectRowsRequested(role: null));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        isA<ObjectRowsFailure>()
            .having((s) => s.error, 'error', refused)
            .having((s) => s.meta, 'meta', isNotNull)
            .having((s) => s.kind?.id, 'kind', 'table')
            .having((s) => s.previous, 'previous', isNull),
      ],
      verify: (_) => verify(
        () => statements.run(
          postgres,
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          catalog: any(named: 'catalog'),
        ),
      ).called(1),
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'a retry runs the statement once more',
      setUp: () {
        var calls = 0;
        answerRun(postgres, () => calls++ == 0 ? const Failure(refused) : Success(customerRows));
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ObjectRowsRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectRowsRequested(role: null));
      },
      expect: () => [isA<ObjectRowsFailure>(), const ObjectRowsLoading(), isA<ObjectRowsLoaded>()],
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'a refresh that fails keeps the rows on screen under the error',
      setUp: () {
        var calls = 0;
        answerRun(postgres, () => calls++ == 0 ? Success(customerRows) : const Failure(ServerError('down')));
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ObjectRowsRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectRowsRequested(role: null));
      },
      expect: () => [
        isA<ObjectRowsLoaded>().having((s) => s.isRefreshing, 'refreshing', isFalse),
        isA<ObjectRowsLoaded>().having((s) => s.isRefreshing, 'refreshing', isTrue),
        isA<ObjectRowsFailure>()
            .having((s) => s.error, 'error', const ServerError('down'))
            .having((s) => s.previous?.isRefreshing, 'previous', isFalse),
      ],
    );

    blocTest<ObjectRowsBloc, ObjectRowsState>(
      'offline, a refresh that was never sent keeps the rows as they were',
      setUp: () {
        var calls = 0;
        answerRun(
          postgres,
          () => calls++ == 0
              ? Success(customerRows)
              : Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key)),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ObjectRowsRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ObjectRowsRequested(role: null));
      },
      skip: 2,
      expect: () => [isA<ObjectRowsLoaded>().having((s) => s.isRefreshing, 'refreshing', isFalse)],
    );
  });

  blocTest<ObjectRowsBloc, ObjectRowsState>(
    'a second request while one runs is dropped',
    setUp: () => when(
      () => statements.run(
        postgres,
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
      ),
    ).thenAnswer((_) => Future.delayed(const Duration(milliseconds: 20), () => Success(customerRows))),
    build: build,
    act: (bloc) {
      bloc
        ..add(const ObjectRowsRequested(role: null))
        ..add(const ObjectRowsRequested(role: null));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [isA<ObjectRowsLoaded>()],
    verify: (_) => verify(
      () => statements.run(
        postgres,
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
      ),
    ).called(1),
  );
}
