import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/object_rows_bloc.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

QueryResult _recorded(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

const _postgres = 'seed:dev-postgres';
const _user = StudioUserRole();
const _dropped = NetworkError('Connection closed before full header was received');

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

/// Background time that records each lease asked for and given back, in order.
class _RecordingBackgroundRunTime implements IBackgroundRunTime {
  final calls = <String>[];
  var _leases = 0;

  @override
  BackgroundRunLease begin() {
    final id = ++_leases;
    calls.add('begin $id');
    return _RecordingLease(id, calls);
  }
}

class _RecordingLease implements BackgroundRunLease {
  _RecordingLease(this._id, this._calls);

  final int _id;
  final List<String> _calls;
  var _ended = false;

  @override
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    _calls.add('end $_id');
  }
}

/// Backgrounding on the Browse rows page (#156): the preview and each page of Load more ask for background time while
/// in flight, and one that fails without an answer from Studio while or after the app was in the background is reported
/// as the read's interrupted outcome, never sent again by itself.
void main() {
  late MockIStatementRepository statements;
  late MockIProviderMetaRepository providerMeta;
  late _FakeLifecycle lifecycle;
  late _RecordingBackgroundRunTime backgroundRunTime;
  late Completer<Result<QueryResult>> runAnswer;
  final customers = _recorded('query_preview_postgres_customers');

  var ids = 0;

  setUp(() {
    ids = 0;
    statements = MockIStatementRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_postgres)).thenAnswer((_) async => Success(metaAnswer('meta_postgres')));
    lifecycle = _FakeLifecycle();
    backgroundRunTime = _RecordingBackgroundRunTime();
    runAnswer = Completer();
    // The run waits for runAnswer, or fails as cancelled once its request is dropped, as ApiClient does.
    when(
      () => statements.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((invocation) {
      final signal = invocation.namedArguments[#cancelSignal] as CancelSignal?;
      return Future.any([
        runAnswer.future,
        if (signal != null)
          signal.whenCancelled.then((_) => const Failure<QueryResult>(RequestCancelledError('Request cancelled'))),
      ]);
    });
  });

  ObjectRowsBloc build() => ObjectRowsBloc(
    statements: statements,
    providerMeta: providerMeta,
    lifecycle: lifecycle,
    backgroundRunTime: backgroundRunTime,
    connectionId: _postgres,
    path: const ['public', 'customers'],
    kind: 'table',
    newRunId: () => 'run-${++ids}',
  );

  int runs() => verify(
    () => statements.run(
      any(),
      any(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      catalog: any(named: 'catalog'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).callCount;

  /// Opens the page and waits until its preview is in flight.
  Future<ObjectRowsBloc> open() async {
    final bloc = build();
    addTearDown(bloc.close);
    bloc.add(const ObjectRowsRequested(role: _user));
    await untilCalled(
      () => statements.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        catalog: any(named: 'catalog'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    );
    return bloc;
  }

  /// Answers the preview in flight with [answer] and returns the state it ends in.
  Future<ObjectRowsState> answer(ObjectRowsBloc bloc, Result<QueryResult> answer) async {
    final next = bloc.stream.first;
    runAnswer.complete(answer);
    return next;
  }

  /// Opens the page on a loaded preview, ready for a page of Load more.
  Future<(ObjectRowsBloc, ObjectRowsLoaded)> loaded() async {
    final bloc = await open();
    final state = await answer(bloc, Success(customers));
    runAnswer = Completer();
    return (bloc, state as ObjectRowsLoaded);
  }

  const nextPage = QueryPage(limit: 50, offset: 50);

  group('the preview', () {
    test('asks for background time when it is sent and gives it back when its answer arrives', () async {
      final bloc = await open();
      expect(backgroundRunTime.calls, ['begin 1']);
      await answer(bloc, Success(customers));
      expect(backgroundRunTime.calls, ['begin 1', 'end 1']);
    });

    test('dropped without an answer after the app went to the background shows the read\'s interrupted report, and '
        'nothing is sent again', () async {
      final bloc = await open();
      lifecycle
        ..leave()
        ..comeBack();
      final state = await answer(bloc, const Failure(_dropped));
      expect(
        state,
        isA<ObjectRowsFailure>()
            .having((s) => s.error, 'error', isA<InterruptedError>())
            .having((s) => s.error.code, 'code', AppErrorCode.browseRowsInterrupted.key)
            .having((s) => s.meta, 'meta', isNotNull)
            .having((s) => s.kind?.id, 'kind', 'table'),
      );
      await pumpEventQueue();
      expect(runs(), 1);
      expect(backgroundRunTime.calls, ['begin 1', 'end 1']);
    });

    test('dropped while the app is still in the background is interrupted too', () async {
      final bloc = await open();
      lifecycle.leave();
      final state = await answer(bloc, const Failure(_dropped));
      expect((state as ObjectRowsFailure).error.code, AppErrorCode.browseRowsInterrupted.key);
    });

    test('sent while the app was in the background and dropped is interrupted', () async {
      lifecycle.go(AppLifecycleState.paused);
      final bloc = await open();
      final state = await answer(bloc, const Failure(_dropped));
      expect((state as ObjectRowsFailure).error.code, AppErrorCode.browseRowsInterrupted.key);
    });

    test('a timeout after the request was sent, in the background, is interrupted', () async {
      final bloc = await open();
      lifecycle.leave();
      final state = await answer(bloc, const Failure(TimeoutError('Receive timeout')));
      expect((state as ObjectRowsFailure).error.code, AppErrorCode.browseRowsInterrupted.key);
    });

    test('a refresh dropped in the background keeps the rows on screen under the interrupted report', () async {
      final (bloc, shown) = await loaded();
      bloc.add(const ObjectRowsRequested(role: _user));
      await untilCalled(
        () => statements.run(
          any(),
          any(),
          queryId: 'run-2',
          page: any(named: 'page'),
          catalog: any(named: 'catalog'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      );
      lifecycle.leave();
      final next = bloc.stream.firstWhere((state) => state is ObjectRowsFailure);
      runAnswer.complete(const Failure(_dropped));
      expect(
        await next,
        isA<ObjectRowsFailure>()
            .having((s) => s.error.code, 'code', AppErrorCode.browseRowsInterrupted.key)
            .having((s) => s.previous, 'previous', shown),
      );
    });

    group('shows as it does today', () {
      test('a drop without the app leaving the screen', () async {
        final bloc = await open();
        final state = await answer(bloc, const Failure(_dropped));
        expect((state as ObjectRowsFailure).error, _dropped);
      });

      test('a drop after only a system sheet over the app (inactive)', () async {
        final bloc = await open();
        lifecycle
          ..go(AppLifecycleState.inactive)
          ..go(AppLifecycleState.resumed);
        final state = await answer(bloc, const Failure(_dropped));
        expect((state as ObjectRowsFailure).error, _dropped);
      });

      test('a drop after an earlier run came back from the background', () async {
        final (bloc, _) = await loaded();
        lifecycle
          ..leave()
          ..comeBack();
        bloc.add(const ObjectRowsRequested(role: _user));
        await untilCalled(
          () => statements.run(
            any(),
            any(),
            queryId: 'run-2',
            page: any(named: 'page'),
            catalog: any(named: 'catalog'),
            cancelSignal: any(named: 'cancelSignal'),
          ),
        );
        final next = bloc.stream.firstWhere((state) => state is ObjectRowsFailure);
        runAnswer.complete(const Failure(_dropped));
        expect((await next as ObjectRowsFailure).error, _dropped);
      });

      test('Studio\'s answer in the background', () async {
        final bloc = await open();
        lifecycle.leave();
        expect(await answer(bloc, Success(customers)), isA<ObjectRowsLoaded>());
      });

      for (final error in [
        const ValidationError('relation does not exist', code: 'studio.query_error'),
        const ServerError('Internal error'),
        const TimeoutError('Studio timed out', code: 'studio.timeout'),
        const NetworkError('No internet', code: 'network.offline'),
        const TimeoutError('Connect timeout', sent: false),
      ]) {
        test('$error in the background', () async {
          final bloc = await open();
          lifecycle.leave();
          final state = await answer(bloc, Failure(error));
          expect((state as ObjectRowsFailure).error, error);
        });
      }
    });
  });

  group('a page of Load more', () {
    test('asks for background time while in flight and gives it back on its answer', () async {
      final (bloc, shown) = await loaded();
      final page = bloc.loadPage(shown.preview, nextPage);
      await pumpEventQueue();
      expect(backgroundRunTime.calls, ['begin 1', 'end 1', 'begin 2']);
      runAnswer.complete(Success(customers));
      expect(await page, isA<Success<QueryResult>>());
      expect(backgroundRunTime.calls, ['begin 1', 'end 1', 'begin 2', 'end 2']);
    });

    test('dropped after the app went to the background answers the read\'s interrupted page, sent once', () async {
      final (bloc, shown) = await loaded();
      final page = bloc.loadPage(shown.preview, nextPage);
      await pumpEventQueue();
      lifecycle
        ..leave()
        ..comeBack();
      runAnswer.complete(const Failure(_dropped));
      expect(
        await page,
        isA<Failure<QueryResult>>()
            .having((f) => f.error, 'error', isA<InterruptedError>())
            .having((f) => f.error.code, 'code', AppErrorCode.editorPageInterrupted.key),
      );
      expect(runs(), 2);
      expect(bloc.state, shown);
    });

    test('sent while the app was in the background and dropped is interrupted', () async {
      final (bloc, shown) = await loaded();
      lifecycle.go(AppLifecycleState.paused);
      final page = bloc.loadPage(shown.preview, nextPage);
      await pumpEventQueue();
      runAnswer.complete(const Failure(_dropped));
      expect((await page as Failure<QueryResult>).error.code, AppErrorCode.editorPageInterrupted.key);
    });

    test('dropped without the app leaving the screen answers the drop as it does today', () async {
      final (bloc, shown) = await loaded();
      final page = bloc.loadPage(shown.preview, nextPage);
      await pumpEventQueue();
      runAnswer.complete(const Failure(_dropped));
      expect((await page as Failure<QueryResult>).error, _dropped);
    });

    test('Studio\'s refusal in the background answers as it does today', () async {
      const refused = ValidationError('relation does not exist', code: 'studio.query_error');
      final (bloc, shown) = await loaded();
      final page = bloc.loadPage(shown.preview, nextPage);
      await pumpEventQueue();
      lifecycle.leave();
      runAnswer.complete(const Failure(refused));
      expect((await page as Failure<QueryResult>).error, refused);
    });
  });

  test('closing the bloc gives back the background time of the preview and of each page in flight', () async {
    final (bloc, shown) = await loaded();
    unawaited(bloc.loadPage(shown.preview, nextPage));
    unawaited(bloc.loadPage(shown.preview, const QueryPage(limit: 50, offset: 100)));
    await pumpEventQueue();
    bloc.add(const ObjectRowsRequested(role: _user));
    await pumpEventQueue();
    expect(backgroundRunTime.calls, ['begin 1', 'end 1', 'begin 2', 'begin 3', 'begin 4']);
    await bloc.close();
    expect(backgroundRunTime.calls.skip(5), unorderedEquals(['end 2', 'end 3', 'end 4']));
  });
}
