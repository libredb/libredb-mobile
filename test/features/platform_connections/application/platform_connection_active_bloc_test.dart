import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_active_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/application/usecases/set_connection_active_usecase.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../../../support/printed_lines.dart';

void main() {
  late MockIPlatformConnectionRepository repository;

  const disabled = PlatformConnection(
    id: 'c1',
    name: 'Payroll Secret',
    engine: 'postgres',
    status: 'inactive',
    hasWriteCredential: true,
  );

  setUp(() => repository = MockIPlatformConnectionRepository());

  PlatformConnectionActiveBloc build() =>
      PlatformConnectionActiveBloc(setConnectionActiveUseCase: SetPlatformConnectionActiveUseCase(repository));

  void answer(Result<PlatformConnection> result) =>
      when(() => repository.setActive(any(), active: any(named: 'active'))).thenAnswer((_) async => result);

  test('starts idle', () {
    expect(build().state, const PlatformConnectionActiveIdle());
  });

  test('sends the asked value and succeeds with the connection Platform answered', () async {
    answer(const Success(disabled));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionActiveRequested('c1', active: false));

    expect(await states, [
      const PlatformConnectionActiveInProgress('c1'),
      const PlatformConnectionActiveSucceeded(disabled),
    ]);
    verify(() => repository.setActive('c1', active: false)).called(1);
    await bloc.close();
  });

  test('a 404 says the connection is gone', () async {
    answer(Failure(NotFoundError('404 NOT_FOUND', code: AppErrorCode.platformNotFound.key)));
    final bloc = build();
    final states = bloc.stream.take(2).toList();

    bloc.add(const PlatformConnectionActiveRequested('c1', active: true));

    expect(await states, [const PlatformConnectionActiveInProgress('c1'), const PlatformConnectionActiveGone('c1')]);
    await bloc.close();
  });

  test('any other error fails with its code, and one without a known code with the generic code', () async {
    answer(Failure(AuthError('403', code: AppErrorCode.platformLicenseUserSeats.key)));
    final bloc = build()..add(const PlatformConnectionActiveRequested('c1', active: true));

    expect(
      await bloc.stream.firstWhere((state) => state is PlatformConnectionActiveFailed),
      const PlatformConnectionActiveFailed('c1', errorCode: AppErrorCode.platformLicenseUserSeats),
    );

    answer(const Failure(UnknownError('boom')));
    bloc.add(const PlatformConnectionActiveRequested('c1', active: true));

    expect(
      await bloc.stream.firstWhere((state) => state is PlatformConnectionActiveFailed),
      const PlatformConnectionActiveFailed('c1', errorCode: AppErrorCode.generic),
    );
    await bloc.close();
  });

  test('a request confirmed while one runs is dropped, so one PATCH is sent', () async {
    final pending = Completer<Result<PlatformConnection>>();
    when(() => repository.setActive(any(), active: any(named: 'active'))).thenAnswer((_) => pending.future);
    final bloc = build();

    bloc
      ..add(const PlatformConnectionActiveRequested('c1', active: false))
      ..add(const PlatformConnectionActiveRequested('c1', active: false))
      ..add(const PlatformConnectionActiveRequested('c2', active: true));
    // A timer runs after every microtask, so all three events have reached the bloc while the first one runs.
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const PlatformConnectionActiveInProgress('c1'));
    pending.complete(const Success(disabled));
    await bloc.stream.firstWhere((state) => state is PlatformConnectionActiveSucceeded);
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.setActive('c1', active: false)).called(1);
    verifyNever(() => repository.setActive('c2', active: true));
    expect(bloc.state, const PlatformConnectionActiveSucceeded(disabled));
    await bloc.close();
  });

  test('no connection name reaches a log line, an event or a state text', () async {
    answer(const Success(disabled));
    late PlatformConnectionActiveBloc bloc;

    final lines = await printedLines(() async {
      bloc = build()..add(const PlatformConnectionActiveRequested('c1', active: false));
      await bloc.stream.firstWhere((state) => state is PlatformConnectionActiveSucceeded);
      answer(Failure(ServerError('Payroll Secret broke', code: AppErrorCode.platformInternalError.key)));
      bloc.add(const PlatformConnectionActiveRequested('c1', active: true));
      await bloc.stream.firstWhere((state) => state is PlatformConnectionActiveFailed);
      await bloc.close();
    });

    expect(lines, contains(allOf(contains('[W]'), contains('onRequested failed: platform.internal_error'))));
    expect(lines, everyElement(isNot(contains('Payroll'))));
    expect(const PlatformConnectionActiveSucceeded(disabled).toString(), isNot(contains('Payroll')));
    expect(const PlatformConnectionActiveRequested('c1', active: false).toString(), isNot(contains('Payroll')));
  });
}
