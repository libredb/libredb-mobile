import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_id.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'object_rows_event.dart';
part 'object_rows_state.dart';

/// The first rows of the object at [path] of [connectionId], of [kind]: Studio's preview statement, written by
/// [PreviewStatementGenerator] from the cached provider-meta, run through [IStatementRepository] with a page of 50 rows
/// and a fresh run id, in the path's catalog on a server-level connection.
///
/// The answer is masked at once with the policy of the role the request carries and the engine's exempt column, so the
/// bloc never holds a clear row. A run is a statement: it runs only when the page asks, on open, a pull or a retry,
/// never again by itself after a failure or a schema change, and a request while one runs is dropped. Neither the
/// statement nor a database error text is logged.
///
/// Closing the bloc, which leaving the page does, drops the requests still in flight, the preview and a Load more;
/// Studio then cancels the run where the engine supports it, and no `/db/cancel` spends a request slot.
///
/// Backgrounding (#156), as the SQL editor's run and its Load more (#118, #150): the preview and each page of Load more
/// ask [IBackgroundRunTime] for background time when sent and give it back on their answer, and at once when the bloc
/// closes. The bloc follows [IAppLifecycleSource]: a request that fails without an answer from Studio (a dropped
/// connection, or a timeout after it was sent) while or after the app was in the background is reported as
/// interrupted, because Studio cancels a run whose request drops. The preview is always a read, so the preview ends in
/// [ObjectRowsFailure] with [AppErrorCode.browseRowsInterrupted] and the page's Retry, and a page of Load more answers
/// [AppErrorCode.editorPageInterrupted] with the result view's retry. Nothing is sent again by itself, and any answer
/// Studio sent shows as usual, since it says what happened.
class ObjectRowsBloc extends Bloc<ObjectRowsEvent, ObjectRowsState> {
  ObjectRowsBloc({
    required this._statements,
    required this._providerMeta,
    required IAppLifecycleSource lifecycle,
    required this._backgroundRunTime,
    required this.connectionId,
    required this.path,
    required this.kind,
    this._generator = const PreviewStatementGenerator(),
    this._newRunId = newQueryId,
  }) : _lifecycle = lifecycle,
       super(const ObjectRowsLoading()) {
    _lifecycleChanges = lifecycle.changes.listen((change) {
      if (isInBackground(change)) _backgroundChanges++;
    });
    on<ObjectRowsRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('ObjectRowsBloc');

  final IStatementRepository _statements;
  final IProviderMetaRepository _providerMeta;
  final PreviewStatementGenerator _generator;
  final String Function() _newRunId;
  final IAppLifecycleSource _lifecycle;
  final IBackgroundRunTime _backgroundRunTime;
  late final StreamSubscription<AppLifecycleState> _lifecycleChanges;

  /// How many times the app went to the background, so a request can tell whether it did while it was in flight.
  int _backgroundChanges = 0;

  /// The connection, from the page's route.
  final String connectionId;

  /// The object's path, from the page's route.
  final List<String> path;

  /// The object's kind id, from the page's route.
  final String kind;

  /// The runs answered so far, which tells one result on screen from the next.
  int _runs = 0;

  /// Drop the requests in flight.
  final _inFlight = <CancelSignal>{};

  /// The background time of each request in flight.
  final _leases = <BackgroundRunLease>{};

  Future<void> _onRequested(ObjectRowsRequested event, Emitter<ObjectRowsState> emit) async {
    final onScreen = switch (state) {
      final ObjectRowsLoaded loaded => loaded,
      ObjectRowsFailure(:final previous) => previous,
      ObjectRowsLoading() || ObjectRowsUnavailable() => null,
    };
    if (onScreen != null) {
      emit(onScreen.copyWith(isRefreshing: true));
    } else if (state is! ObjectRowsLoading) {
      emit(const ObjectRowsLoading());
    }

    final ProviderMeta meta;
    switch (await _providerMeta.providerMeta(connectionId)) {
      case Failure(:final error):
        if (emit.isDone) return;
        _fail(emit, error, onScreen: onScreen);
        return;
      case Success(:final data):
        meta = data;
    }
    if (emit.isDone) return;
    final declared = meta.objectKinds.where((candidate) => candidate.id == kind).firstOrNull;
    if (declared == null) {
      _log.warn('the engine declares no kind of the route\'s id');
      _fail(emit, const ValidationError('The engine declares no such object kind'), onScreen: onScreen, meta: meta);
      return;
    }

    final PreviewStatement preview;
    switch (_generator.preview(meta, declared, path)) {
      case PreviewUnavailable(:final reason):
        _log.info('no preview for this object: {}', [reason]);
        emit(ObjectRowsUnavailable(meta: meta, kind: declared));
        return;
      case final PreviewStatement statement:
        preview = statement;
    }

    final result = await _send(
      (signal) => _statements.run(
        connectionId,
        preview.statement,
        queryId: _newRunId(),
        page: const QueryPage(limit: PreviewStatementGenerator.pageSize),
        catalog: preview.catalog,
        cancelSignal: signal,
      ),
      interrupted: AppErrorCode.browseRowsInterrupted,
    );
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _fail(emit, error, onScreen: onScreen, meta: meta, kind: declared);
      case Success(:final data):
        final policy = MaskingPolicy.forRole(event.role, exempt: meta.maskingExemptColumns);
        emit(
          ObjectRowsLoaded(
            meta: meta,
            kind: declared,
            preview: preview,
            masked: maskResult(data, policy),
            policy: policy,
            loadedAt: clock.now(),
            run: ++_runs,
          ),
        );
    }
  }

  /// Runs [preview], the statement of the rows on screen, again for [page], with a fresh run id and in its catalog, for
  /// the result view's Load more; the state does not change, and a failure is answered, never run again by itself. A
  /// page dropped in the background answers [AppErrorCode.editorPageInterrupted], see the class documentation.
  Future<Result<QueryResult>> loadPage(PreviewStatement preview, QueryPage page) async {
    final answer = await _send(
      (signal) => _statements.run(
        connectionId,
        preview.statement,
        queryId: _newRunId(),
        page: page,
        catalog: preview.catalog,
        cancelSignal: signal,
      ),
      interrupted: AppErrorCode.editorPageInterrupted,
    );
    if (answer case Failure(:final error)) _log.warn('page not read: {}', [error.code ?? error.runtimeType]);
    return answer;
  }

  /// Sends [run] once, with a signal that [close] cancels while the answer is awaited and with background time until
  /// the answer arrives. A failure without an answer from Studio while or after the app was in the background answers
  /// an [InterruptedError] of the [interrupted] code.
  Future<Result<QueryResult>> _send(
    Future<Result<QueryResult>> Function(CancelSignal signal) run, {
    required AppErrorCode interrupted,
  }) async {
    final signal = CancelSignal();
    _inFlight.add(signal);
    final backgroundChanges = _backgroundChanges;
    final startedInBackground = isInBackground(_lifecycle.current);
    final lease = _backgroundRunTime.begin();
    _leases.add(lease);
    final Result<QueryResult> answer;
    try {
      answer = await run(signal);
    } finally {
      _inFlight.remove(signal);
      if (_leases.remove(lease)) unawaited(lease.end());
    }
    final backgrounded = startedInBackground || _backgroundChanges != backgroundChanges;
    if (answer case Failure(:final error) when backgrounded && droppedWithoutAnswer(error)) {
      _log.info('a request was interrupted while the app was in the background');
      return Failure(InterruptedError('The request was interrupted in the background', code: interrupted.key));
    }
    return answer;
  }

  @override
  Future<void> close() async {
    for (final signal in _inFlight) {
      signal.cancel();
    }
    // The page closed: the background time of every request in flight is given back now.
    for (final lease in _leases) {
      unawaited(lease.end());
    }
    _leases.clear();
    await _lifecycleChanges.cancel();
    return super.close();
  }

  void _fail(
    Emitter<ObjectRowsState> emit,
    AppError error, {
    required ObjectRowsLoaded? onScreen,
    ProviderMeta? meta,
    ObjectKind? kind,
  }) {
    _log.warn('rows not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the rows on screen stay, marked stale by the page.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(onScreen.copyWith(isRefreshing: false));
      return;
    }
    emit(
      ObjectRowsFailure(
        error: error,
        meta: meta ?? onScreen?.meta,
        kind: kind ?? onScreen?.kind,
        previous: onScreen?.copyWith(isRefreshing: false),
      ),
    );
  }
}
