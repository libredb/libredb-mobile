import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/platform_status/application/usecases/check_platform_liveness_usecase.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockIPlatformStatusRepository repository;

  const offline = NetworkError('No Internet connection');

  setUp(() {
    repository = MockIPlatformStatusRepository();
    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
  });

  PlatformStatusBloc build() => PlatformStatusBloc(checkLivenessUseCase: CheckPlatformLivenessUseCase(repository));

  test('starts unknown and asks nothing until a check is requested', () async {
    final bloc = build();
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const PlatformStatusUnknown());
    verifyNever(() => repository.liveness());
    await bloc.close();
  });

  group('liveness check', () {
    blocTest<PlatformStatusBloc, PlatformStatusState>(
      'Platform answering is reachable',
      build: build,
      act: (bloc) => bloc.add(const PlatformLivenessCheckRequested()),
      expect: () => [const PlatformReachable()],
    );

    blocTest<PlatformStatusBloc, PlatformStatusState>(
      'a failure is unreachable, with the error',
      setUp: () => when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline)),
      build: build,
      act: (bloc) => bloc.add(const PlatformLivenessCheckRequested()),
      expect: () => [const PlatformUnreachable(error: offline)],
    );

    blocTest<PlatformStatusBloc, PlatformStatusState>(
      'a retry keeps the unreachable state, marked as retrying, until the answer arrives',
      build: build,
      seed: () => const PlatformUnreachable(error: offline),
      act: (bloc) => bloc.add(const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.retry)),
      expect: () => [const PlatformUnreachable(error: offline, retrying: true), const PlatformReachable()],
    );

    blocTest<PlatformStatusBloc, PlatformStatusState>(
      'a failed retry stays unreachable with the new error',
      setUp: () => when(() => repository.liveness()).thenAnswer((_) async => const Failure(TimeoutError('timeout'))),
      build: build,
      seed: () => const PlatformUnreachable(error: offline),
      act: (bloc) => bloc.add(const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.retry)),
      expect: () => [
        const PlatformUnreachable(error: offline, retrying: true),
        const PlatformUnreachable(error: TimeoutError('timeout')),
      ],
    );

    blocTest<PlatformStatusBloc, PlatformStatusState>(
      'a reconnect check clears the unreachable state once Platform answers',
      build: build,
      seed: () => const PlatformUnreachable(error: offline),
      act: (bloc) => bloc.add(const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.reconnect)),
      expect: () => [const PlatformUnreachable(error: offline, retrying: true), const PlatformReachable()],
    );

    late Completer<Result<void>> answer;
    blocTest<PlatformStatusBloc, PlatformStatusState>(
      'a check that arrives while another runs is dropped',
      setUp: () {
        answer = Completer<Result<void>>();
        when(() => repository.liveness()).thenAnswer((_) => answer.future);
      },
      build: build,
      act: (bloc) async {
        bloc
          ..add(const PlatformLivenessCheckRequested())
          ..add(const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.retry));
        await Future<void>.delayed(Duration.zero);
        answer.complete(const Success(null));
      },
      expect: () => [const PlatformReachable()],
      verify: (_) => verify(() => repository.liveness()).called(1),
    );
  });

  group('resume', () {
    test('checks again only after more than five minutes in the background', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const PlatformLivenessCheckRequested());
        async.flushMicrotasks();
        verify(() => repository.liveness()).called(1);

        bloc.add(const PlatformAppPaused());
        async.flushMicrotasks();
        async.elapse(PlatformStatusBloc.defaultRecheckAfter);
        bloc.add(const PlatformAppResumed());
        async.flushMicrotasks();
        verifyNever(() => repository.liveness());

        bloc.add(const PlatformAppPaused());
        async.flushMicrotasks();
        async.elapse(PlatformStatusBloc.defaultRecheckAfter + const Duration(seconds: 1));
        bloc.add(const PlatformAppResumed());
        async.flushMicrotasks();
        verify(() => repository.liveness()).called(1);

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a resume after a long time away that finds Platform unreachable shows it', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const PlatformLivenessCheckRequested());
        async.flushMicrotasks();
        when(() => repository.liveness()).thenAnswer((_) async => const Failure(offline));

        bloc.add(const PlatformAppPaused());
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 6));
        bloc.add(const PlatformAppResumed());
        async.flushMicrotasks();

        expect(bloc.state, const PlatformUnreachable(error: offline));
        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('a resume without a pause checks nothing', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const PlatformLivenessCheckRequested());
        async.flushMicrotasks();
        verify(() => repository.liveness()).called(1);

        bloc.add(const PlatformAppResumed());
        async.flushMicrotasks();
        verifyNever(() => repository.liveness());
        bloc.close();
        async.flushMicrotasks();
      });
    });

    // The app layer decides when Platform is first asked (never in a Studio session or a build without a Platform
    // target), so a resume does not ask it first.
    test('a resume before the first check asks nothing', () {
      fakeAsync((async) {
        final bloc = build();
        bloc.add(const PlatformAppPaused());
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 1));
        bloc.add(const PlatformAppResumed());
        async.flushMicrotasks();

        verifyNever(() => repository.liveness());
        expect(bloc.state, const PlatformStatusUnknown());
        bloc.close();
        async.flushMicrotasks();
      });
    });
  });
}
