import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

const _postgres = 'seed:dev-postgres';
const _redis = 'seed:dev-redis';
const _user = StudioUserRole();

/// Cancel of a running statement (#116): with the engine's cancel, the cancel is posted while the request is still
/// open, because Studio's abort bridge stops the run as soon as the request is dropped and a cancel posted after that
/// finds nothing to stop; the request is dropped once the cancel answered.
void main() {
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late SchemaChangeNotifier schemaChanges;
  late MockIStatementHistoryRepository history;
  late Completer<Result<QueryResult>> runAnswer;
  late Completer<Result<bool>> cancelAnswer;
  late List<CancelSignal?> sentSignals;
  late List<bool> droppedWhenCancelPosted;
  final customers = QueryResultJson.read(_fixture('query_preview_postgres_customers'));
  var ids = 0;

  setUp(() {
    ids = 0;
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_postgres))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    when(() => providerMeta.providerMeta(_redis))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_redis'))));
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
    history = MockIStatementHistoryRepository();
    when(() => history.record(any(), any())).thenAnswer(
      (_) async => Success(
        StatementHistoryEntry(
          id: 'entry',
          connectionId: _postgres,
          connectionName: 'Dev Postgres',
          text: 'x',
          status: StatementRunStatus.failure,
          duration: Duration.zero,
          executedAt: DateTime.utc(2026, 10, 23),
        ),
      ),
    );
    runAnswer = Completer();
    cancelAnswer = Completer();
    sentSignals = [];
    droppedWhenCancelPosted = [];
    // The run waits for runAnswer, or fails as cancelled once its request is dropped, as ApiClient does.
    when(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((invocation) {
      final signal = invocation.namedArguments[#cancelSignal] as CancelSignal?;
      sentSignals.add(signal);
      return Future.any([
        runAnswer.future,
        if (signal != null)
          signal.whenCancelled.then((_) => const Failure<QueryResult>(RequestCancelledError('Request cancelled'))),
      ]);
    });
    when(() => repository.cancel(any(), any())).thenAnswer((_) {
      droppedWhenCancelPosted.add(sentSignals.last?.isCancelled ?? false);
      return cancelAnswer.future;
    });
  });

  tearDown(() => schemaChanges.dispose());

  EditorRunBloc build({String connectionId = _postgres}) => EditorRunBloc(
    repository: repository,
    providerMeta: providerMeta,
    schemaChanges: schemaChanges,
    history: history,
    onHistoryNotKept: (_) {},
    connectionId: connectionId,
    newRunId: () => 'run-${++ids}',
  );

  /// Runs `SELECT pg_sleep(30)` and lets the bloc reach the running state.
  Future<void> startRun(EditorRunBloc bloc) async {
    bloc.add(const EditorRunRequested(text: 'SELECT pg_sleep(30)', role: _user));
    await pumpEventQueue();
  }

  group('with the engine cancel', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'posts the run id while the request is open, then drops it and says Cancelled when Studio confirms',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Success(true));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        const EditorCancelled(outcome: EditorCancelOutcome.confirmed),
      ],
      verify: (_) {
        verify(() => repository.cancel(_postgres, 'run-1')).called(1);
        expect(droppedWhenCancelPosted, [false], reason: 'a cancel posted after the drop finds nothing to stop');
        expect(sentSignals.single!.isCancelled, isTrue);
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      "drops the request and says Studio could not confirm the cancel when it answers cancelled: false",
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Success(false));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        const EditorCancelled(outcome: EditorCancelOutcome.notConfirmed),
      ],
      verify: (_) => expect(sentSignals.single!.isCancelled, isTrue),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'the run answering 499 QUERY_CANCELLED before the cancel answers says Cancelled, and the late answer changes '
      'nothing',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        runAnswer.complete(Failure(ServerError('Query was cancelled', code: AppErrorCode.studioQueryCancelled.key)));
        await pumpEventQueue();
        cancelAnswer.complete(const Success(true));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        const EditorCancelled(outcome: EditorCancelOutcome.confirmed),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a run that finishes before the cancel answers shows its result, and the late answer changes nothing',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        runAnswer.complete(Success(customers));
        await pumpEventQueue();
        cancelAnswer.complete(const Success(false));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        isA<EditorSucceeded>(),
      ],
      verify: (_) => expect(sentSignals.single!.isCancelled, isFalse),
    );

    final rateLimited = RateLimitedError(
      'Too many requests',
      code: AppErrorCode.studioRateLimited.key,
      retryAfter: const Duration(seconds: 12),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a 429 on the cancel shows its countdown, keeps the run going, and is never sent again by itself',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(Failure(rateLimited));
        await pumpEventQueue();
        // Cancel stays disabled while the countdown runs.
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        bloc.add(const EditorRateLimitElapsed());
        await pumpEventQueue();
        runAnswer.complete(Success(customers));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        EditorRunning(queryId: 'run-1', supportsCancel: true, cancelFailure: rateLimited, waitingForRetry: true),
        EditorRunning(queryId: 'run-1', supportsCancel: true, cancelFailure: rateLimited),
        isA<EditorSucceeded>(),
      ],
      verify: (_) {
        verify(() => repository.cancel(_postgres, 'run-1')).called(1);
        expect(sentSignals.single!.isCancelled, isFalse);
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a cancel that fails otherwise shows the failure and keeps the run going, and a second tap asks again',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Failure(NetworkError('No Internet connection')));
        await pumpEventQueue();
        cancelAnswer = Completer()..complete(const Success(true));
        bloc.add(const EditorCancelRequested());
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelling(queryId: 'run-1'),
        const EditorRunning(
          queryId: 'run-1',
          supportsCancel: true,
          cancelFailure: NetworkError('No Internet connection'),
        ),
        const EditorCancelling(queryId: 'run-1'),
        const EditorCancelled(outcome: EditorCancelOutcome.confirmed),
      ],
      verify: (_) => verify(() => repository.cancel(_postgres, 'run-1')).called(2),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'after a cancel that failed otherwise, Stop waiting drops the request without posting a second cancel',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Failure(NetworkError('No Internet connection')));
        await pumpEventQueue();
        bloc.add(const EditorCancelRequested(stopWaiting: true));
      },
      skip: 2,
      expect: () => [
        const EditorRunning(
          queryId: 'run-1',
          supportsCancel: true,
          cancelFailure: NetworkError('No Internet connection'),
        ),
        const EditorCancelled(outcome: EditorCancelOutcome.stoppedWaiting),
      ],
      verify: (_) {
        verify(() => repository.cancel(_postgres, 'run-1')).called(1);
        expect(sentSignals.single!.isCancelled, isTrue);
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a second Cancel while the first is posted sends nothing',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc
          ..add(const EditorCancelRequested())
          ..add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Success(true));
      },
      skip: 1,
      expect: () => [
        const EditorCancelling(queryId: 'run-1'),
        const EditorCancelled(outcome: EditorCancelOutcome.confirmed),
      ],
      verify: (_) => verify(() => repository.cancel(_postgres, 'run-1')).called(1),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a 499 without a cancel from this phone says Cancelled too, not an error',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        runAnswer.complete(Failure(ServerError('Query was cancelled', code: AppErrorCode.studioQueryCancelled.key)));
      },
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: true),
        const EditorCancelled(outcome: EditorCancelOutcome.confirmed),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'Run works again after a cancel',
      build: build,
      act: (bloc) async {
        await startRun(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Success(true));
        await pumpEventQueue();
        runAnswer = Completer()..complete(Success(customers));
        bloc.add(const EditorRunRequested(text: 'SELECT 1', role: _user));
      },
      skip: 3,
      expect: () => [const EditorRunning(queryId: 'run-2', supportsCancel: true), isA<EditorSucceeded>()],
    );
  });

  group('without the engine cancel', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'Stop waiting drops the request only, posts nothing, and says the statement may still run',
      build: () => build(connectionId: _redis),
      act: (bloc) async {
        // Redis is not SQL, so every text asks first.
        bloc.add(const EditorRunRequested(text: 'GET "user:1"', role: _user));
        await pumpEventQueue();
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await pumpEventQueue();
        bloc.add(const EditorCancelRequested());
      },
      skip: 1,
      expect: () => [
        const EditorRunning(queryId: 'run-1', supportsCancel: false),
        const EditorCancelled(outcome: EditorCancelOutcome.stoppedWaiting),
      ],
      verify: (_) {
        verifyNever(() => repository.cancel(any(), any()));
        expect(sentSignals.single!.isCancelled, isTrue);
      },
    );
  });

  blocTest<EditorRunBloc, EditorRunState>(
    'a Cancel while nothing runs does nothing',
    build: build,
    act: (bloc) => bloc.add(const EditorCancelRequested()),
    expect: () => const <EditorRunState>[],
    verify: (_) => verifyNever(() => repository.cancel(any(), any())),
  );

  group('the history', () {
    const target = EditorHistoryTarget(subjectHash: 'account-hash', connectionName: 'Dev Postgres');

    Future<void> startTracked(EditorRunBloc bloc) async {
      bloc.add(const EditorRunRequested(text: 'SELECT pg_sleep(30)', role: _user, history: target));
      await pumpEventQueue();
    }

    List<FinishedRun> recorded() =>
        verify(() => history.record('account-hash', captureAny())).captured.cast<FinishedRun>();

    for (final confirmed in [true, false]) {
      blocTest<EditorRunBloc, EditorRunState>(
        'a cancel Studio answered ${confirmed ? 'as cancelled' : 'without confirming'} writes one Failed entry',
        build: build,
        act: (bloc) async {
          await startTracked(bloc);
          bloc.add(const EditorCancelRequested());
          await pumpEventQueue();
          cancelAnswer.complete(Success(confirmed));
          await pumpEventQueue();
        },
        skip: 3,
        verify: (_) {
          final run = recorded().single;
          expect(run.text, 'SELECT pg_sleep(30)');
          expect(run.status, StatementRunStatus.failure);
          expect(run.rowCount, isNull);
        },
      );
    }

    blocTest<EditorRunBloc, EditorRunState>(
      'a 499 QUERY_CANCELLED writes one Failed entry with no error text',
      build: build,
      act: (bloc) async {
        await startTracked(bloc);
        runAnswer.complete(Failure(ServerError('Query was cancelled', code: AppErrorCode.studioQueryCancelled.key)));
        await pumpEventQueue();
      },
      skip: 2,
      verify: (_) {
        final run = recorded().single;
        expect(run.status, StatementRunStatus.failure);
        expect(run.props, isNot(contains(contains('cancelled'))));
      },
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'Stop waiting on an engine without a cancel writes nothing, since the outcome is unknown',
      build: () => build(connectionId: _redis),
      act: (bloc) async {
        bloc.add(const EditorRunRequested(text: 'GET "user:1"', role: _user, history: target));
        await pumpEventQueue();
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await pumpEventQueue();
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
      },
      skip: 3,
      verify: (_) => verifyNever(() => history.record(any(), any())),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'Stop waiting after a failed cancel writes nothing',
      build: build,
      act: (bloc) async {
        await startTracked(bloc);
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Failure(ServerError('down')));
        await pumpEventQueue();
        bloc.add(const EditorCancelRequested(stopWaiting: true));
        await pumpEventQueue();
      },
      skip: 4,
      verify: (_) => verifyNever(() => history.record(any(), any())),
    );
  });
}
