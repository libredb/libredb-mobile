import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/row_count_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

QueryResult _recorded(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

QueryResult _count(String field, Object? value) => QueryResult(
  fields: [field],
  rows: [
    {field: value},
  ],
  rowCount: 1,
  executionTime: Duration.zero,
);

void main() {
  late MockIStatementRepository statements;
  const connection = 'seed:dev-postgres-server';
  const count = PreviewStatement(statement: 'SELECT COUNT(*) AS row_count\nFROM app.public.orders;', catalog: 'app');

  setUp(() => statements = MockIStatementRepository());

  var ids = 0;
  RowCountBloc build() =>
      RowCountBloc(statements: statements, connectionId: connection, newRunId: () => 'count-${++ids}');

  void answer(Result<QueryResult> Function() result) => when(
    () => statements.run(
      connection,
      any(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      catalog: any(named: 'catalog'),
    ),
  ).thenAnswer((_) async => result());

  test('starts idle and runs nothing by itself', () async {
    final bloc = build();
    expect(bloc.state, const RowCountIdle());
    await bloc.close();
    verifyZeroInteractions(statements);
  });

  blocTest<RowCountBloc, RowCountState>(
    'runs the count once in its catalog, with a fresh run id, and reads Postgres\'s bigint string',
    setUp: () => answer(() => Success(_recorded('query_count_postgres_customers'))),
    build: build,
    act: (bloc) => bloc.add(const RowCountRequested(count)),
    expect: () => [const RowCountRunning(), const RowCountLoaded(3)],
    verify: (_) {
      final ids = verify(
        () => statements.run(
          connection,
          count.statement,
          queryId: captureAny(named: 'queryId'),
          page: QueryPage.first,
          catalog: 'app',
        ),
      ).captured;
      expect(ids.single, startsWith('count-'));
    },
  );

  for (final (field, value, expected) in [
    ('row_count', 20000, 20000),
    ('ROW_COUNT', 12, 12),
    ('count', 5, 5),
    ('row_count', '1234567', 1234567),
  ]) {
    blocTest<RowCountBloc, RowCountState>(
      'reads $field from ${value.runtimeType}',
      setUp: () => answer(() => Success(_count(field, value))),
      build: build,
      act: (bloc) => bloc.add(const RowCountRequested(count)),
      expect: () => [const RowCountRunning(), RowCountLoaded(expected)],
    );
  }

  blocTest<RowCountBloc, RowCountState>(
    'an answer of another shape is an unreadable answer',
    setUp: () => answer(() => Success(_count('row_count', 1.5))),
    build: build,
    act: (bloc) => bloc.add(const RowCountRequested(count)),
    expect: () => [
      const RowCountRunning(),
      isA<RowCountFailure>().having((s) => s.error.code, 'code', AppErrorCode.studioUnreadableAnswer.key),
    ],
  );

  blocTest<RowCountBloc, RowCountState>(
    'a refused count keeps the error itself, and runs again only on the next tap',
    setUp: () {
      var calls = 0;
      answer(
        () => calls++ == 0
            ? const Failure(ValidationError('permission denied', code: 'studio.query_error'))
            : Success(_count('row_count', 9)),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const RowCountRequested(count));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const RowCountRequested(count));
    },
    expect: () => [
      const RowCountRunning(),
      const RowCountFailure(ValidationError('permission denied', code: 'studio.query_error')),
      const RowCountRunning(),
      const RowCountLoaded(9),
    ],
  );

  blocTest<RowCountBloc, RowCountState>(
    'a tap while a count runs is dropped',
    setUp: () => when(
      () => statements.run(
        connection,
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
      ),
    ).thenAnswer((_) => Future.delayed(const Duration(milliseconds: 20), () => Success(_count('row_count', 1)))),
    build: build,
    act: (bloc) => bloc
      ..add(const RowCountRequested(count))
      ..add(const RowCountRequested(count)),
    wait: const Duration(milliseconds: 50),
    expect: () => [const RowCountRunning(), const RowCountLoaded(1)],
    verify: (_) => verify(
      () => statements.run(
        connection,
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
      ),
    ).called(1),
  );

  blocTest<RowCountBloc, RowCountState>(
    'a new count keeps the last one on screen while it runs',
    setUp: () => answer(() => Success(_count('row_count', 4))),
    build: build,
    seed: () => const RowCountLoaded(3),
    act: (bloc) => bloc.add(const RowCountRequested(count)),
    expect: () => [const RowCountRunning(previous: 3), const RowCountLoaded(4)],
  );
}
