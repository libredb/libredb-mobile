import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_source_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

void main() {
  late MockIObjectBrowserRepository repository;
  const connection = 'seed:dev-postgres';
  const path = ['sales', 'order_totals'];

  setUp(() => repository = MockIObjectBrowserRepository());

  ObjectSourceBloc build() =>
      ObjectSourceBloc(repository: repository, connectionId: connection, path: path, kind: 'view');

  final view = sourceAnswer('source_postgres_view');

  blocTest<ObjectSourceBloc, ObjectSourceState>(
    'reads the source of the object the route names',
    setUp: () =>
        when(() => repository.source(connection, path: path, kind: 'view')).thenAnswer((_) async => Success(view)),
    build: build,
    act: (bloc) => bloc.add(const ObjectSourceRequested()),
    expect: () => [ObjectSourceLoaded(view)],
    verify: (_) => verify(() => repository.source(connection, path: path, kind: 'view')).called(1),
  );

  blocTest<ObjectSourceBloc, ObjectSourceState>(
    'keeps the error itself for the failure view, and reads afresh on a retry',
    setUp: () {
      var calls = 0;
      when(() => repository.source(connection, path: path, kind: 'view')).thenAnswer(
        (_) async => calls++ == 0
            ? const Failure(ServerError('refused', code: 'studio.connection_not_available'))
            : Success(view),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ObjectSourceRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ObjectSourceRequested());
    },
    expect: () => [
      const ObjectSourceFailure(ServerError('refused', code: 'studio.connection_not_available')),
      const ObjectSourceLoading(),
      ObjectSourceLoaded(view),
    ],
  );

  test('starts loading', () {
    expect(build().state, const ObjectSourceLoading());
  });

  test('a loaded source does not print its text', () {
    const secret = ObjectSource(
      path: ['p'],
      kind: 'view',
      parts: [SourceText(id: 'd', label: 'D', text: 'SELECT secret', language: 'sql', origin: SourceOrigin.stored)],
    );

    expect(const ObjectSourceLoaded(secret).toString(), isNot(contains('SELECT secret')));
  });
}
