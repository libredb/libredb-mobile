import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_check_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _id = 'seed:sales-postgres';

ProviderMeta _meta({bool resumesBilledCompute = false}) => ProviderMeta(
  queryLanguage: 'sql',
  schemaRefreshPattern: r'(CREATE|DROP)\b',
  containerLevels: const [],
  objectKinds: const [],
  resumesBilledCompute: resumesBilledCompute,
);

const _online = ConnectionTestResult(message: 'Connection successful', latency: Duration(milliseconds: 42));

void main() {
  late MockIConnectionRepository connections;
  late MockIProviderMetaRepository providerMeta;

  setUp(() {
    connections = MockIConnectionRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_id)).thenAnswer((_) async => Success(_meta()));
  });

  ConnectionCheckBloc build() =>
      ConnectionCheckBloc(connectionId: _id, connectionRepository: connections, providerMetaRepository: providerMeta);

  test('starts idle and asks Studio nothing on open', () async {
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const ConnectionCheckIdle());
    verifyZeroInteractions(connections);
    verifyZeroInteractions(providerMeta);
    await bloc.close();
  });

  blocTest<ConnectionCheckBloc, ConnectionCheckState>(
    'a check that connects shows the latency Studio measured',
    setUp: () => when(() => connections.test(_id)).thenAnswer((_) async => const Success(_online)),
    build: build,
    act: (bloc) => bloc.add(const ConnectionCheckRequested()),
    expect: () => const [ConnectionCheckChecking(), ConnectionCheckOnline(latency: Duration(milliseconds: 42))],
    verify: (_) => verify(() => connections.test(_id)).called(1),
  );

  blocTest<ConnectionCheckBloc, ConnectionCheckState>(
    'a degraded answer shows Studio its message',
    setUp: () => when(() => connections.test(_id)).thenAnswer(
      (_) async => const Success(ConnectionTestResult(message: 'Connected, but no health data', degraded: true)),
    ),
    build: build,
    act: (bloc) => bloc.add(const ConnectionCheckRequested()),
    expect: () => const [ConnectionCheckChecking(), ConnectionCheckDegraded(message: 'Connected, but no health data')],
  );

  blocTest<ConnectionCheckBloc, ConnectionCheckState>(
    'an answer with warnings carries them, online or degraded',
    setUp: () {
      var degraded = false;
      when(() => connections.test(_id)).thenAnswer((_) async {
        final result = ConnectionTestResult(
          message: degraded ? 'no health' : 'Connection successful',
          latency: degraded ? null : const Duration(milliseconds: 42),
          degraded: degraded,
          warnings: const [QueryWarning(message: 'careful')],
        );
        degraded = true;
        return Success(result);
      });
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ConnectionCheckRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ConnectionCheckRequested());
    },
    expect: () => const [
      ConnectionCheckChecking(),
      ConnectionCheckOnline(
        latency: Duration(milliseconds: 42),
        warnings: [QueryWarning(message: 'careful')],
      ),
      ConnectionCheckChecking(),
      ConnectionCheckDegraded(
        message: 'no health',
        warnings: [QueryWarning(message: 'careful')],
      ),
    ],
  );

  blocTest<ConnectionCheckBloc, ConnectionCheckState>(
    'a refused database credential fails with its code and fix statement, and the check can be run again',
    setUp: () => when(() => connections.test(_id)).thenAnswer(
      (_) async => Failure(
        AuthError(
          'password authentication failed',
          code: AppErrorCode.studioDatabaseAuth.key,
          fixStatement: 'ALTER USER app PASSWORD ...',
        ),
      ),
    ),
    build: build,
    act: (bloc) => bloc.add(const ConnectionCheckRequested()),
    expect: () => [
      const ConnectionCheckChecking(),
      isA<ConnectionCheckFailed>()
          .having((s) => s.errorCode, 'errorCode', AppErrorCode.studioDatabaseAuth)
          .having((s) => s.error, 'error', isA<AuthError>().having((e) => e.fixStatement, 'fix', isNotNull)),
    ],
  );

  blocTest<ConnectionCheckBloc, ConnectionCheckState>(
    'a rate limit fails with the delay Studio asked for',
    setUp: () => when(() => connections.test(_id)).thenAnswer(
      (_) async => Failure(
        RateLimitedError('slow down', code: AppErrorCode.studioRateLimited.key, retryAfter: const Duration(seconds: 9)),
      ),
    ),
    build: build,
    act: (bloc) => bloc.add(const ConnectionCheckRequested()),
    expect: () => [
      const ConnectionCheckChecking(),
      isA<ConnectionCheckFailed>().having(
        (s) => s.error,
        'error',
        isA<RateLimitedError>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 9)),
      ),
    ],
  );

  group('an engine that resumes billed compute', () {
    setUp(() {
      when(() => providerMeta.providerMeta(_id)).thenAnswer((_) async => Success(_meta(resumesBilledCompute: true)));
      when(() => connections.test(_id)).thenAnswer((_) async => const Success(_online));
    });

    blocTest<ConnectionCheckBloc, ConnectionCheckState>(
      'is not checked, so the check spends nothing on the database',
      build: build,
      act: (bloc) => bloc.add(const ConnectionCheckRequested()),
      expect: () => const [ConnectionCheckChecking(), ConnectionCheckNotChecked()],
      verify: (_) => verifyNever(() => connections.test(any())),
    );

    blocTest<ConnectionCheckBloc, ConnectionCheckState>(
      'is checked when the user asks for it anyway, without reading the engine again',
      build: build,
      act: (bloc) async {
        bloc.add(const ConnectionCheckRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ConnectionCheckForced());
      },
      expect: () => const [
        ConnectionCheckChecking(),
        ConnectionCheckNotChecked(),
        ConnectionCheckChecking(),
        ConnectionCheckOnline(latency: Duration(milliseconds: 42)),
      ],
      verify: (_) {
        verify(() => providerMeta.providerMeta(_id)).called(1);
        verify(() => connections.test(_id)).called(1);
      },
    );

    blocTest<ConnectionCheckBloc, ConnectionCheckState>(
      'once the user accepted the cost, a later check of the same sheet runs without asking again',
      build: build,
      act: (bloc) async {
        bloc.add(const ConnectionCheckForced());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ConnectionCheckRequested());
      },
      expect: () => const [
        ConnectionCheckChecking(),
        ConnectionCheckOnline(latency: Duration(milliseconds: 42)),
        ConnectionCheckChecking(),
        ConnectionCheckOnline(latency: Duration(milliseconds: 42)),
      ],
      verify: (_) => verify(() => connections.test(_id)).called(2),
    );
  });

  blocTest<ConnectionCheckBloc, ConnectionCheckState>(
    'fails with the error of a provider-meta read Studio refused, and connects to nothing',
    setUp: () =>
        when(() => providerMeta.providerMeta(_id))
            .thenAnswer((_) async => Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key))),
    build: build,
    act: (bloc) => bloc.add(const ConnectionCheckRequested()),
    expect: () => [
      const ConnectionCheckChecking(),
      isA<ConnectionCheckFailed>().having((s) => s.errorCode, 'errorCode', AppErrorCode.networkOffline),
    ],
    verify: (_) => verifyNever(() => connections.test(any())),
  );

  test('drops a second tap while a check runs, so one check spends one Studio slot', () async {
    final answer = Completer<Result<ConnectionTestResult>>();
    when(() => connections.test(_id)).thenAnswer((_) => answer.future);
    final bloc = build();
    final states = <ConnectionCheckState>[];
    final subscription = bloc.stream.listen(states.add);

    bloc.add(const ConnectionCheckRequested());
    await Future<void>.delayed(Duration.zero);
    bloc
      ..add(const ConnectionCheckRequested())
      ..add(const ConnectionCheckForced());
    await Future<void>.delayed(Duration.zero);
    answer.complete(const Success(_online));
    await Future<void>.delayed(Duration.zero);

    verify(() => connections.test(_id)).called(1);
    expect(states, const [ConnectionCheckChecking(), ConnectionCheckOnline(latency: Duration(milliseconds: 42))]);
    await subscription.cancel();
    await bloc.close();
  });
}
