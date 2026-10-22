import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIStudioStatusRepository repository;

  const offline = NetworkError('No Internet connection');
  const temporarilyUnavailable = GovernanceOutage(kind: GovernanceOutageKind.temporarilyUnavailable);

  setUp(() {
    repository = MockIStudioStatusRepository();
    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
    when(() => repository.readiness()).thenAnswer((_) async => const Success(StudioReadinessDegraded()));
  });

  StudioStatusBloc build() => StudioStatusBloc(
    checkLivenessUseCase: CheckStudioLivenessUseCase(repository),
    readReadinessUseCase: ReadStudioReadinessUseCase(repository),
  );

  test('starts unknown', () {
    final bloc = build();
    expect(bloc.state, const StudioStatusUnknown());
    bloc.close();
  });

  group('liveness check', () {
    blocTest<StudioStatusBloc, StudioStatusState>(
      'Studio answering is reachable',
      build: build,
      act: (bloc) => bloc.add(const StudioLivenessCheckRequested()),
      expect: () => [const StudioReachable()],
    );

    blocTest<StudioStatusBloc, StudioStatusState>(
      'a network failure is unreachable, with the error',
      setUp: () => when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline)),
      build: build,
      act: (bloc) => bloc.add(const StudioLivenessCheckRequested()),
      expect: () => [const StudioUnreachable(error: offline)],
    );

    blocTest<StudioStatusBloc, StudioStatusState>(
      'a timeout is unreachable, with the error',
      setUp: () => when(() => repository.liveness()).thenAnswer((_) async => const Failure(TimeoutError('timeout'))),
      build: build,
      act: (bloc) => bloc.add(const StudioLivenessCheckRequested()),
      expect: () => [const StudioUnreachable(error: TimeoutError('timeout'))],
    );

    blocTest<StudioStatusBloc, StudioStatusState>(
      'a retry keeps the unreachable state, marked as retrying, until the answer arrives',
      setUp: () => when(() => repository.liveness()).thenAnswer((_) async => const Success(null)),
      build: build,
      seed: () => const StudioUnreachable(error: offline),
      act: (bloc) => bloc.add(const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.retry)),
      expect: () => [const StudioUnreachable(error: offline, retrying: true), const StudioReachable()],
    );

    blocTest<StudioStatusBloc, StudioStatusState>(
      'a failed retry stays unreachable with the new error',
      setUp: () => when(() => repository.liveness()).thenAnswer((_) async => const Failure(TimeoutError('timeout'))),
      build: build,
      seed: () => const StudioUnreachable(error: offline),
      act: (bloc) => bloc.add(const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.retry)),
      expect: () => [
        const StudioUnreachable(error: offline, retrying: true),
        const StudioUnreachable(error: TimeoutError('timeout')),
      ],
    );

    late Completer<Result<void>> answer;
    blocTest<StudioStatusBloc, StudioStatusState>(
      'a check that arrives while another runs is dropped',
      setUp: () {
        answer = Completer<Result<void>>();
        when(() => repository.liveness()).thenAnswer((_) => answer.future);
      },
      build: build,
      act: (bloc) async {
        bloc
          ..add(const StudioLivenessCheckRequested())
          ..add(const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.retry));
        await Future<void>.delayed(Duration.zero);
        answer.complete(const Success(null));
      },
      expect: () => [const StudioReachable()],
      verify: (_) => verify(() => repository.liveness()).called(1),
    );

    // Liveness says nothing about governance.
    blocTest<StudioStatusBloc, StudioStatusState>(
      'Studio answering keeps a governance outage',
      build: build,
      seed: () => const StudioGovernanceUnavailable(outage: temporarilyUnavailable),
      act: (bloc) => bloc.add(const StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.resume)),
      expect: () => const <StudioStatusState>[],
    );
  });

  group('resume', () {
    test('checks again only after more than five minutes in the background', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const StudioLivenessCheckRequested());
        async.flushMicrotasks();
        verify(() => repository.liveness()).called(1);

        bloc.add(const StudioAppPaused());
        async.flushMicrotasks();
        async.elapse(StudioStatusBloc.defaultRecheckAfter);
        bloc.add(const StudioAppResumed());
        async.flushMicrotasks();
        verifyNever(() => repository.liveness());

        bloc.add(const StudioAppPaused());
        async.flushMicrotasks();
        async.elapse(StudioStatusBloc.defaultRecheckAfter + const Duration(seconds: 1));
        bloc.add(const StudioAppResumed());
        async.flushMicrotasks();
        verify(() => repository.liveness()).called(1);

        bloc.close();
        async.flushMicrotasks();
      });
    });

    // The time counts from the moment the app left the foreground, not from the last check.
    test('counts the time in the background, not the time since the last check', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const StudioLivenessCheckRequested());
        async.flushMicrotasks();
        verify(() => repository.liveness()).called(1);

        async.elapse(const Duration(hours: 1));
        bloc.add(const StudioAppPaused());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        bloc.add(const StudioAppResumed());
        async.flushMicrotasks();
        verifyNever(() => repository.liveness());

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a resume without a pause checks nothing', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const StudioAppResumed());
        async.flushMicrotasks();
        verifyNever(() => repository.liveness());
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a resume after a long time away that finds Studio unreachable shows it', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const StudioLivenessCheckRequested());
        async.flushMicrotasks();
        when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));

        bloc.add(const StudioAppPaused());
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 6));
        bloc.add(const StudioAppResumed());
        async.flushMicrotasks();

        expect(bloc.state, const StudioUnreachable(error: offline));
        bloc.close();
        async.flushMicrotasks();
      });
    });
  });

  group('governance outage', () {
    for (final (readiness, outage) in <(StudioReadiness, GovernanceOutage)>[
      (const StudioReadinessDegraded(), temporarilyUnavailable),
      (const StudioReadinessLoading(), temporarilyUnavailable),
      (
        const StudioReadinessMisconfigured(detail: 'libredb_grants: 42501'),
        const GovernanceOutage(kind: GovernanceOutageKind.cannotServeConnections, detail: 'libredb_grants: 42501'),
      ),
      (
        const StudioReadinessIncompatible(detail: 'supported 1, source 2'),
        const GovernanceOutage(kind: GovernanceOutageKind.cannotServeConnections, detail: 'supported 1, source 2'),
      ),
    ]) {
      blocTest<StudioStatusBloc, StudioStatusState>(
        'reads readiness to word the outage: ${readiness.runtimeType}',
        setUp: () => when(() => repository.readiness()).thenAnswer((_) async => Success(readiness)),
        build: build,
        seed: () => const StudioReachable(),
        act: (bloc) => bloc.add(const StudioGovernanceOutageReported()),
        expect: () => [StudioGovernanceUnavailable(outage: outage)],
      );
    }

    // The connection route's own 503 is the trigger, so the outage shows even when readiness cannot be read.
    blocTest<StudioStatusBloc, StudioStatusState>(
      'an unreadable readiness still shows the outage, as temporarily unavailable',
      setUp: () =>
          when(() => repository.readiness())
              .thenAnswer((_) async => const Failure(ServerError('unreadable', code: 'studio.unreadable_answer'))),
      build: build,
      seed: () => const StudioReachable(),
      act: (bloc) => bloc.add(const StudioGovernanceOutageReported()),
      expect: () => [const StudioGovernanceUnavailable(outage: temporarilyUnavailable)],
    );

    blocTest<StudioStatusBloc, StudioStatusState>(
      'a recovery ends the outage',
      build: build,
      seed: () => const StudioGovernanceUnavailable(outage: temporarilyUnavailable),
      act: (bloc) => bloc.add(const StudioGovernanceRecovered()),
      expect: () => [const StudioReachable()],
    );

    blocTest<StudioStatusBloc, StudioStatusState>(
      'a recovery without an outage changes nothing',
      build: build,
      seed: () => const StudioUnreachable(error: offline),
      act: (bloc) => bloc.add(const StudioGovernanceRecovered()),
      expect: () => const <StudioStatusState>[],
    );
  });
}
