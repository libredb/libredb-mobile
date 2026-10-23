import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

const _postgres = 'seed:dev-postgres';
const _redis = 'seed:dev-redis';
const _user = StudioUserRole();

/// The lifecycle the bloc follows, driven by the test.
class _FakeLifecycle implements IAppLifecycleSource {
  final _changes = StreamController<AppLifecycleState>.broadcast(sync: true);

  @override
  AppLifecycleState? current = AppLifecycleState.resumed;

  @override
  Stream<AppLifecycleState> get changes => _changes.stream;

  void go(AppLifecycleState state) {
    current = state;
    _changes.add(state);
  }

  /// To another app, as iOS and Android report it.
  void leave() {
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.paused);
  }

  /// Back to the app.
  void comeBack() {
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.resumed);
  }
}

/// Backgrounding during a run (#118): a run that fails without an answer from Studio while or after the app was in the
/// background is interrupted, and only a text the check runs without asking counts as a read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late SchemaChangeNotifier schemaChanges;
  late MockIStatementHistoryRepository history;
  late _FakeLifecycle lifecycle;
  late Completer<Result<QueryResult>> runAnswer;
  late Completer<Result<bool>> cancelAnswer;
  late List<String> platformCalls;
  final customers = QueryResultJson.read(_fixture('query_preview_postgres_customers'));
  var ids = 0;
  var tasks = 0;

  setUp(() {
    ids = 0;
    tasks = 0;
    platformCalls = [];
    // The iOS channel, answered as AppDelegate answers it.
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, (call) async {
      switch (call.method) {
        case 'begin':
          platformCalls.add('begin ${++tasks}');
          return tasks;
        case 'end':
          platformCalls.add('end ${(call.arguments as Map)['id']}');
          return null;
      }
      throw MissingPluginException();
    });
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
    lifecycle = _FakeLifecycle();
    runAnswer = Completer();
    cancelAnswer = Completer();
    // The run waits for runAnswer, or fails as cancelled once its request is dropped, as ApiClient does.
    when(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
        catalog: any(named: 'catalog'),
      ),
    ).thenAnswer((invocation) {
      final signal = invocation.namedArguments[#cancelSignal] as CancelSignal?;
      return Future.any([
        runAnswer.future,
        if (signal != null)
          signal.whenCancelled.then((_) => const Failure<QueryResult>(RequestCancelledError('Request cancelled'))),
      ]);
    });
    when(() => repository.cancel(any(), any())).thenAnswer((_) => cancelAnswer.future);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, null);
    await schemaChanges.dispose();
  });

  EditorRunBloc build({String connectionId = _postgres}) => EditorRunBloc(
    repository: repository,
    providerMeta: providerMeta,
    schemaChanges: schemaChanges,
    history: history,
    onHistoryNotKept: (_) {},
    lifecycle: lifecycle,
    backgroundRunTime: const ChannelBackgroundRunTime(),
    connectionId: connectionId,
    newRunId: () => 'run-${++ids}',
  );

  Future<void> run(EditorRunBloc bloc, String text) async {
    bloc.add(EditorRunRequested(text: text, role: _user));
    await pumpEventQueue();
  }

  Future<void> runConfirmed(EditorRunBloc bloc, String text) async {
    await run(bloc, text);
    bloc.add(const EditorConfirmationAnswered(confirmed: true));
    await pumpEventQueue();
  }

  const reset = NetworkError('Connection reset by peer');
  const running = EditorRunning(queryId: 'run-1', supportsCancel: true);

  group('a run that fails without an answer while or after the app was in the background', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'a read that fails in the background is interrupted as a read, and is not sent again',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        lifecycle.leave();
        runAnswer.complete(const Failure(reset));
      },
      expect: () => [running, const EditorInterrupted(queryId: 'run-1', wasRead: true)],
      verify: (_) => verify(
        () => repository.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          cancelSignal: any(named: 'cancelSignal'),
          catalog: any(named: 'catalog'),
        ),
      ).called(1),
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a read whose request times out after the app came back is interrupted too',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        lifecycle
          ..leave()
          ..comeBack();
        runAnswer.complete(const Failure(TimeoutError('TimeoutException')));
      },
      expect: () => [running, const EditorInterrupted(queryId: 'run-1', wasRead: true)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a confirmed write is interrupted with its outcome unknown',
      build: build,
      act: (bloc) async {
        await runConfirmed(bloc, 'UPDATE orders SET status = status');
        lifecycle.leave();
        runAnswer.complete(const Failure(reset));
      },
      skip: 1,
      expect: () => [running, const EditorInterrupted(queryId: 'run-1', wasRead: false)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a text of an engine that does not speak SQL is never a read',
      build: () => build(connectionId: _redis),
      act: (bloc) async {
        await runConfirmed(bloc, 'GET a');
        lifecycle.leave();
        runAnswer.complete(const Failure(reset));
      },
      skip: 2,
      expect: () => [const EditorInterrupted(queryId: 'run-1', wasRead: false)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a script is never a read, since the phone cannot split it',
      setUp: () =>
          when(
            () => repository.runScript(
              any(),
              any(),
              queryId: any(named: 'queryId'),
              catalog: any(named: 'catalog'),
              page: any(named: 'page'),
              cancelSignal: any(named: 'cancelSignal'),
            ),
          ).thenAnswer((_) async {
            lifecycle.leave();
            return const Failure(reset);
          }),
      build: build,
      act: (bloc) => runConfirmed(bloc, 'SELECT 1; SELECT 2'),
      skip: 2,
      expect: () => [const EditorInterrupted(queryId: 'run-1', wasRead: false)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a run with a cancel posted when the app left is interrupted when its request drops',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        lifecycle.leave();
        runAnswer.complete(const Failure(reset));
      },
      expect: () => [
        running,
        const EditorCancelling(queryId: 'run-1'),
        const EditorInterrupted(queryId: 'run-1', wasRead: true),
      ],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a Run after the interrupted message runs again, and an earlier background does not count for it',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        lifecycle
          ..leave()
          ..comeBack();
        runAnswer.complete(const Failure(reset));
        await pumpEventQueue();
        runAnswer = Completer();
        await run(bloc, 'SELECT pg_sleep(20)');
        runAnswer.complete(const Failure(reset));
      },
      expect: () => [
        running,
        const EditorInterrupted(queryId: 'run-1', wasRead: true),
        const EditorRunning(queryId: 'run-2', supportsCancel: true),
        const EditorFailed(error: reset),
      ],
    );
  });

  group('history', () {
    const target = EditorHistoryTarget(subjectHash: 'account', connectionName: 'Dev Postgres');

    Future<void> runFor(EditorRunBloc bloc, {required bool leave, required AppError error}) async {
      bloc.add(const EditorRunRequested(text: 'SELECT pg_sleep(20)', role: _user, history: target));
      await pumpEventQueue();
      if (leave) lifecycle.leave();
      runAnswer.complete(Failure(error));
      await pumpEventQueue();
    }

    for (final error in [reset, const TimeoutError('TimeoutException')]) {
      test('an interrupted run (${error.runtimeType}) keeps no entry, as Stop waiting keeps none', () async {
        final bloc = build();
        await runFor(bloc, leave: true, error: error);
        expect(bloc.state, const EditorInterrupted(queryId: 'run-1', wasRead: true));
        await bloc.close();

        verifyNever(() => history.record(any(), any()));
      });
    }

    test('a timeout after sending while the app stayed on screen is still kept as Failed', () async {
      final bloc = build();
      await runFor(bloc, leave: false, error: const TimeoutError('TimeoutException'));
      await bloc.close();

      final run = verify(() => history.record('account', captureAny())).captured.single as FinishedRun;
      expect(run.status, StatementRunStatus.failure);
    });
  });

  group('shows the answer as usual', () {
    blocTest<EditorRunBloc, EditorRunState>(
      'a run that answers while the app is in the background shows its result on return',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT 1');
        lifecycle.leave();
        runAnswer.complete(Success(customers));
        await pumpEventQueue();
        lifecycle.comeBack();
      },
      expect: () => [running, isA<EditorSucceeded>()],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a run that fails while the app stayed on screen shows its failure',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT 1');
        lifecycle.go(AppLifecycleState.inactive);
        runAnswer.complete(const Failure(reset));
      },
      expect: () => [running, const EditorFailed(error: reset)],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      "the database's refusal answered in the background is shown, since Studio said what happened",
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT nope');
        lifecycle.leave();
        runAnswer.complete(Failure(ValidationError('no column', code: AppErrorCode.studioQueryError.key)));
      },
      expect: () => [running, isA<EditorStatementFailed>()],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      "Studio's own timeout answered in the background is shown",
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        lifecycle.leave();
        runAnswer.complete(Failure(TimeoutError('timed out', code: AppErrorCode.studioTimeout.key)));
      },
      expect: () => [running, isA<EditorFailed>()],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a request that timed out before it was sent never reached Studio, so nothing ran',
      build: build,
      act: (bloc) async {
        await run(bloc, 'UPDATE orders SET status = status');
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await pumpEventQueue();
        lifecycle.leave();
        runAnswer.complete(const Failure(TimeoutError('connect', sent: false)));
      },
      skip: 2,
      expect: () => [const EditorFailed(error: TimeoutError('connect', sent: false))],
    );

    blocTest<EditorRunBloc, EditorRunState>(
      'a request refused offline never left the device',
      build: build,
      act: (bloc) async {
        await run(bloc, 'SELECT 1');
        lifecycle.leave();
        runAnswer.complete(Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key)));
      },
      expect: () => [running, isA<EditorFailed>()],
    );
  });

  group('a page of Load more (#150)', () {
    final firstPage = QueryResultJson.read(_fixture('query_page_postgres_first'));
    final secondPage = QueryResultJson.read(_fixture('query_page_postgres_second'));
    final next = QueryPage.after(firstPage.pagination!);
    late Completer<Result<QueryResult>> pageAnswer;
    const read = 'SELECT * FROM sales.ledger';
    // The comment's keyword makes the check ask, as a data-modifying text does.
    const flagged = 'SELECT * FROM sales.ledger -- note: update';

    /// Runs [text] to its first page, then answers every later request with pageAnswer.
    Future<EditorSucceeded> firstPageOf(EditorRunBloc bloc, String text) async {
      await run(bloc, text);
      if (bloc.state is EditorAwaitingConfirmation) {
        bloc.add(const EditorConfirmationAnswered(confirmed: true));
        await pumpEventQueue();
      }
      runAnswer.complete(Success(firstPage));
      await pumpEventQueue();
      pageAnswer = Completer();
      when(
        () => repository.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
          catalog: any(named: 'catalog'),
        ),
      ).thenAnswer((_) => pageAnswer.future);
      return bloc.state as EditorSucceeded;
    }

    Future<Result<QueryResult>?> loadPage(EditorRunBloc bloc, EditorSucceeded shown) =>
        bloc.loadPage(shown.statement, next, confirm: () async => true);

    void verifyPageSentOnce() => verify(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: next,
        cancelSignal: any(named: 'cancelSignal'),
        catalog: any(named: 'catalog'),
      ),
    ).called(1);

    Matcher interrupted(AppErrorCode code) => isA<Failure<QueryResult>>().having(
      (failure) => failure.error,
      'error',
      isA<InterruptedError>().having((error) => error.code, 'code', code.key),
    );

    test('a page of a read dropped after the app left is interrupted as a read, and is not sent again', () async {
      final bloc = build();
      addTearDown(bloc.close);
      final shown = await firstPageOf(bloc, read);

      final answer = loadPage(bloc, shown);
      await pumpEventQueue();
      lifecycle.leave();
      pageAnswer.complete(const Failure(reset));

      expect(await answer, interrupted(AppErrorCode.editorPageInterrupted));
      await pumpEventQueue();
      verifyPageSentOnce();
      expect(bloc.state, shown, reason: 'the page leaves the run on screen as it is');
    });

    test('a page whose request times out after the app came back is interrupted too', () async {
      final bloc = build();
      addTearDown(bloc.close);
      final shown = await firstPageOf(bloc, read);

      final answer = loadPage(bloc, shown);
      await pumpEventQueue();
      lifecycle
        ..leave()
        ..comeBack();
      pageAnswer.complete(const Failure(TimeoutError('TimeoutException')));

      expect(await answer, interrupted(AppErrorCode.editorPageInterrupted));
    });

    test('a page of a confirmed text is interrupted with its outcome unknown, and is not sent again', () async {
      final bloc = build();
      addTearDown(bloc.close);
      final shown = await firstPageOf(bloc, flagged);

      final answer = loadPage(bloc, shown);
      await pumpEventQueue();
      lifecycle.leave();
      pageAnswer.complete(const Failure(reset));

      expect(await answer, interrupted(AppErrorCode.editorPageOutcomeUnknown));
      await pumpEventQueue();
      verifyPageSentOnce();
    });

    test('a background before the page was sent does not count for it', () async {
      final bloc = build();
      addTearDown(bloc.close);
      final shown = await firstPageOf(bloc, read);
      lifecycle
        ..leave()
        ..comeBack();

      final answer = loadPage(bloc, shown);
      pageAnswer.complete(const Failure(reset));

      expect(await answer, const Failure<QueryResult>(reset));
    });

    group('a page that got an answer from Studio, or never reached it, shows as it does today', () {
      final cases = <(String, Result<QueryResult>)>[
        ('a page answered in the background', Success(secondPage)),
        ("the database's refusal", Failure(ValidationError('no column', code: AppErrorCode.studioQueryError.key))),
        ("Studio's own timeout", Failure(TimeoutError('timed out', code: AppErrorCode.studioTimeout.key))),
        ('a rate limit', Failure(RateLimitedError('slow down', code: AppErrorCode.studioRateLimited.key))),
        ('a request refused offline', Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key))),
        ('a timeout before the request was sent', const Failure(TimeoutError('connect', sent: false))),
      ];
      for (final (name, studioAnswer) in cases) {
        test(name, () async {
          final bloc = build();
          addTearDown(bloc.close);
          final shown = await firstPageOf(bloc, flagged);

          final answer = loadPage(bloc, shown);
          await pumpEventQueue();
          lifecycle.leave();
          pageAnswer.complete(studioAnswer);

          final got = await answer;
          expect(got, studioAnswer);
          if (got case Failure(:final error)) expect(error, isNot(isA<InterruptedError>()));
        });
      }

      test('a dropped page while the app stayed on screen', () async {
        final bloc = build();
        addTearDown(bloc.close);
        final shown = await firstPageOf(bloc, flagged);

        final answer = loadPage(bloc, shown);
        await pumpEventQueue();
        lifecycle.go(AppLifecycleState.inactive);
        pageAnswer.complete(const Failure(reset));

        final got = await answer;
        expect(got, const Failure<QueryResult>(reset));
        expect((got! as Failure<QueryResult>).error, isA<NetworkError>());
      });
    });

    test('logs neither the statement nor an error text', () async {
      const secret = "SELECT * FROM sales.ledger WHERE note = 'ada@example.com' -- note: update";
      final bloc = build();
      addTearDown(bloc.close);
      final shown = await firstPageOf(bloc, secret);
      final printed = <String>[];

      await runZoned(() async {
        final answer = loadPage(bloc, shown);
        await pumpEventQueue();
        lifecycle.leave();
        pageAnswer.complete(const Failure(NetworkError('reset while reading ada@example.com')));
        await answer;
      }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printed.add(line)));

      expect(printed, isNotEmpty, reason: 'the interrupted page is logged');
      expect(printed.join('\n'), isNot(contains('ada@')));
      expect(printed.join('\n'), isNot(contains('sales.ledger')));
    });

    group('background time', () {
      test('is asked when the page is sent and given back on its answer', () async {
        final bloc = build();
        addTearDown(bloc.close);
        final shown = await firstPageOf(bloc, read);
        await pumpEventQueue();
        expect(platformCalls, ['begin 1', 'end 1']);

        final answer = loadPage(bloc, shown);
        await pumpEventQueue();
        expect(platformCalls, ['begin 1', 'end 1', 'begin 2']);
        pageAnswer.complete(Success(secondPage));
        await answer;
        await pumpEventQueue();

        expect(platformCalls, ['begin 1', 'end 1', 'begin 2', 'end 2']);
      });

      test('is given back when the page is interrupted', () async {
        final bloc = build();
        addTearDown(bloc.close);
        final shown = await firstPageOf(bloc, read);

        final answer = loadPage(bloc, shown);
        await pumpEventQueue();
        lifecycle.leave();
        pageAnswer.complete(const Failure(reset));
        await answer;
        await pumpEventQueue();

        expect(platformCalls, ['begin 1', 'end 1', 'begin 2', 'end 2']);
      });

      test('is given back when the editor closes while the page is in flight, and not again on its answer', () async {
        final bloc = build();
        final shown = await firstPageOf(bloc, read);

        final answer = loadPage(bloc, shown);
        await pumpEventQueue();
        await bloc.close();
        await pumpEventQueue();
        expect(platformCalls, ['begin 1', 'end 1', 'begin 2', 'end 2']);

        pageAnswer.complete(Success(secondPage));
        await answer;
        await pumpEventQueue();
        expect(platformCalls, ['begin 1', 'end 1', 'begin 2', 'end 2']);
      });

      test('is not asked for a page the user declined', () async {
        final bloc = build();
        addTearDown(bloc.close);
        final shown = await firstPageOf(bloc, flagged);
        await pumpEventQueue();

        expect(await bloc.loadPage(shown.statement, next, confirm: () async => false), isNull);
        await pumpEventQueue();

        expect(platformCalls, ['begin 1', 'end 1']);
      });
    });
  });

  group('background time', () {
    test('Android asks for none', () async {
      final bloc = EditorRunBloc(
        repository: repository,
        providerMeta: providerMeta,
        schemaChanges: schemaChanges,
        history: history,
        onHistoryNotKept: (_) {},
        lifecycle: lifecycle,
        backgroundRunTime: const NoBackgroundRunTime(),
        connectionId: _postgres,
      );
      await run(bloc, 'SELECT 1');
      runAnswer.complete(Success(customers));
      await pumpEventQueue();
      await bloc.close();

      expect(platformCalls, isEmpty);
    });

    Future<void> expectEnded(Future<void> Function(EditorRunBloc bloc) path) async {
      final bloc = build();
      await path(bloc);
      await pumpEventQueue();
      expect(platformCalls, ['begin 1', 'end 1']);
      await bloc.close();
      await pumpEventQueue();
      expect(platformCalls, ['begin 1', 'end 1'], reason: 'ended once');
    }

    test('is asked when the run starts and given back on success', () async {
      await expectEnded((bloc) async {
        await run(bloc, 'SELECT 1');
        expect(platformCalls, ['begin 1']);
        runAnswer.complete(Success(customers));
      });
    });

    test('is given back on failure', () async {
      await expectEnded((bloc) async {
        await run(bloc, 'SELECT 1');
        runAnswer.complete(Failure(ValidationError('no', code: AppErrorCode.studioQueryError.key)));
      });
    });

    test('is given back when the run is interrupted', () async {
      await expectEnded((bloc) async {
        await run(bloc, 'SELECT 1');
        lifecycle.leave();
        runAnswer.complete(const Failure(reset));
      });
    });

    test('is given back on a confirmed cancel', () async {
      await expectEnded((bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        bloc.add(const EditorCancelRequested());
        await pumpEventQueue();
        cancelAnswer.complete(const Success(true));
      });
    });

    test('is given back on Stop waiting', () async {
      await expectEnded((bloc) async {
        await run(bloc, 'SELECT pg_sleep(20)');
        bloc.add(const EditorCancelRequested(stopWaiting: true));
      });
    });

    test('is given back when the editor closes while the run is in flight, and not again on its answer', () async {
      final bloc = build();
      await run(bloc, 'SELECT pg_sleep(20)');
      await bloc.close();
      await pumpEventQueue();
      expect(platformCalls, ['begin 1', 'end 1']);

      runAnswer.complete(Success(customers));
      await pumpEventQueue();
      expect(platformCalls, ['begin 1', 'end 1']);
    });

    test('is not asked for a text that is not sent', () async {
      final bloc = build();
      await run(bloc, 'DELETE FROM orders WHERE false');
      bloc.add(const EditorConfirmationAnswered(confirmed: false));
      await run(bloc, 'x' * (EditorRunBloc.maxTextLength + 1));
      await pumpEventQueue();
      await bloc.close();

      expect(platformCalls, isEmpty);
    });

    test('each run asks for its own time', () async {
      final bloc = build();
      await run(bloc, 'SELECT 1');
      runAnswer.complete(Success(customers));
      await pumpEventQueue();
      runAnswer = Completer();
      await run(bloc, 'SELECT 2');
      runAnswer.complete(Success(customers));
      await pumpEventQueue();
      await bloc.close();

      expect(platformCalls, ['begin 1', 'end 1', 'begin 2', 'end 2']);
    });
  });
}
