import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/statement_position.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_id.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';

part 'editor_run_event.dart';
part 'editor_run_state.dart';

/// The SQL editor's run of a statement or a script on [connectionId].
///
/// Run reads the text that is sent, the editor's non-blank selection or its whole text, through [InterimWriteCheck]
/// for the connection's engine; a text longer than [maxTextLength] is refused with the too-large message and nothing
/// is sent. A text the check flags waits in [EditorAwaitingConfirmation] for the user's answer, and the text sent is
/// the one carried there, never read again from the field.
///
/// Routing: on a SQL connection, a text the check reads as several statements is a script, which always asks and goes
/// to [ISqlEditorRepository.runScript] with the first page, where Studio splits it under the connection's grammar and
/// answers each statement; any other text goes whole to [ISqlEditorRepository.run], and a non-SQL text is never split.
/// A selection the check reads as one statement on an engine whose `statementTerminator` is `none` is sent without
/// its trailing `;`, as Studio's web sends it (`selectionTarget`, `src/lib/sql/run-target.ts`).
///
/// Each request has a fresh run id and is never sent again by the bloc: a failure, a rate limit included, waits for
/// the user's next Run, and a Run while one is in flight is dropped. A script waits without a receive timeout, so the
/// bloc holds when it started ([scriptStartedAt]) for the elapsed time on screen, and Cancel ends it as it ends a run.
/// On a server-level connection the text, a script included, runs in the database Run named, and each page of its
/// result in the same one.
///
/// Cancel of the run in flight: when the engine supports it, the bloc posts [ISqlEditorRepository.cancel] with the
/// run's id while the run's request is still open, because Studio stops a run as soon as its request is dropped and a
/// cancel posted after that answers that it stopped nothing; the request is dropped once the cancel answered. A
/// confirmed cancel, or the run answering `QUERY_CANCELLED`, ends in [EditorCancelled] as confirmed, an unconfirmed one
/// as not confirmed. A failed cancel, a rate limit included, leaves the run going and is never sent again by the bloc.
/// Without the engine's cancel, or after a cancel that failed, Stop waiting only drops the request. A run that answers
/// before the cancel shows its answer.
///
/// The answer is masked at once with the policy of the role the request carries and the engine's exempt column, so the
/// bloc never holds a clear row; a script's every statement is. After a success [SchemaChangeNotifier.statementSucceeded]
/// tells the object browser the text that ran, and after a script each successful statement's text. Neither the
/// statement nor a database error text is logged; only an error's code is.
///
/// Each run that reached Studio adds one entry to the account's history through [IStatementHistoryRepository], when
/// the run names an [EditorHistoryTarget]: Succeeded, or Failed for any failure but one before the request reached
/// Studio (a [NetworkError], or a [TimeoutError] before it was sent), without the error's text; a cancelled run is
/// Failed, and a request dropped by Stop waiting adds none. A script adds one entry for its whole text, Failed when a
/// statement failed. A text refused here, a
/// cancelled confirmation and a page of Load more add none. The entry is written even when the editor closed before
/// the answer came, and a write the store refused is told to [onHistoryNotKept] then too.
class EditorRunBloc extends Bloc<EditorRunEvent, EditorRunState> {
  EditorRunBloc({
    required this._repository,
    required this._providerMeta,
    required this._schemaChanges,
    required this._history,
    required this._onHistoryNotKept,
    required this.connectionId,
    this._check = const InterimWriteCheck(),
    this._newRunId = newQueryId,
  }) : super(const EditorIdle()) {
    on<EditorRunRequested>(_onRunRequested, transformer: EventTransformers.dropConcurrent());
    on<EditorConfirmationAnswered>(_onConfirmationAnswered, transformer: EventTransformers.dropConcurrent());
    on<EditorRateLimitElapsed>(_onRateLimitElapsed);
    on<EditorCancelRequested>(_onCancelRequested, transformer: EventTransformers.dropConcurrent());
  }

  /// The longest text the phone sends, counted as `String.length`: Studio bounds the text of a console engine only
  /// (a 413), so this is the phone's own cap for a SQL engine.
  static const maxTextLength = 1000000;

  static final _log = AppLogger.getLogger('EditorRunBloc');

  final ISqlEditorRepository _repository;
  final IProviderMetaRepository _providerMeta;
  final SchemaChangeNotifier _schemaChanges;
  final IStatementHistoryRepository _history;

  /// Told the code of each history entry the store refused to keep, also after this bloc closed, so the editor that
  /// ran it can say so wherever the user is.
  final void Function(AppErrorCode code) _onHistoryNotKept;
  final InterimWriteCheck _check;
  final String Function() _newRunId;

  /// The connection, the active one the page was built for.
  final String connectionId;

  /// The runs answered so far, which tells one result on screen from the next.
  int _runs = 0;

  /// Drops the request of the run in flight; null while none is.
  CancelSignal? _inFlight;

  /// The signal of the run whose cancel Studio answered, so its dropped request still counts as a run that reached
  /// Studio and was cancelled; a request dropped by Stop waiting has no known outcome.
  CancelSignal? _cancelAnswered;

  /// When the script in flight was sent, for the elapsed time the editor shows while it runs; null while no script is.
  DateTime? get scriptStartedAt => _scriptStartedAt;
  DateTime? _scriptStartedAt;

  Future<void> _onRunRequested(EditorRunRequested event, Emitter<EditorRunState> emit) async {
    switch (state) {
      case EditorRunning() || EditorCancelling() || EditorAwaitingConfirmation() || EditorFailed(waitingForRetry: true):
        return;
      case EditorIdle() ||
          EditorSucceeded() ||
          EditorScriptAnswered() ||
          EditorStatementFailed() ||
          EditorFailed() ||
          EditorCancelled():
        break;
    }
    var text = event.text;
    if (text.trim().isEmpty) return;
    if (text.length > maxTextLength) {
      _log.info('a statement over the phone\'s length cap was not sent');
      emit(
        EditorFailed(
          error: ValidationError('The statement is too large', code: AppErrorCode.studioStatementTooLarge.key),
        ),
      );
      return;
    }

    final ProviderMeta meta;
    switch (await _providerMeta.providerMeta(connectionId)) {
      case Failure(:final error):
        if (emit.isDone) return;
        _fail(emit, error);
        return;
      case Success(:final data):
        meta = data;
    }
    if (emit.isDone) return;

    if (event.isSelection && meta.isSql && meta.statementTerminator == 'none' && !_isScript(text)) {
      text = _withoutTrailingTerminator(text);
    }

    switch (_check.check(text, isSql: meta.isSql)) {
      case final AsksBeforeRunning asks:
        emit(
          EditorAwaitingConfirmation(
            statement: EditorStatement(
              text: text,
              asks: asks,
              catalog: event.catalog,
              isScript: meta.isSql && asks.reasons.contains(WriteCheckReason.severalStatements),
            ),
            previous: state,
            meta: meta,
            role: event.role,
            history: event.history,
          ),
        );
      case RunsWithoutAsking():
        await _run(emit, EditorStatement(text: text, catalog: event.catalog), meta, event.role, event.history);
    }
  }

  /// Whether the check reads the SQL [text] as several statements.
  bool _isScript(String text) => switch (_check.check(text, isSql: true)) {
    AsksBeforeRunning(:final reasons) => reasons.contains(WriteCheckReason.severalStatements),
    RunsWithoutAsking() => false,
  };

  /// [text] without its trailing `;` and the white space around it.
  static String _withoutTrailingTerminator(String text) {
    final trimmed = text.trimRight();
    return trimmed.endsWith(';') ? trimmed.substring(0, trimmed.length - 1).trimRight() : text;
  }

  Future<void> _onConfirmationAnswered(EditorConfirmationAnswered event, Emitter<EditorRunState> emit) async {
    final awaiting = state;
    if (awaiting is! EditorAwaitingConfirmation) return;
    if (!event.confirmed) {
      emit(awaiting.previous);
      return;
    }
    await _run(emit, awaiting.statement, awaiting.meta, awaiting.role, awaiting.history);
  }

  void _onRateLimitElapsed(EditorRateLimitElapsed event, Emitter<EditorRunState> emit) {
    switch (state) {
      case EditorFailed(:final error, waitingForRetry: true):
        emit(EditorFailed(error: error));
      case final EditorRunning running when running.waitingForRetry:
        emit(
          EditorRunning(
            queryId: running.queryId,
            supportsCancel: running.supportsCancel,
            cancelFailure: running.cancelFailure,
          ),
        );
      case _:
        break;
    }
  }

  /// Cancel, or Stop waiting, of the run in flight; see the class documentation for the order of the cancel and the
  /// drop.
  Future<void> _onCancelRequested(EditorCancelRequested event, Emitter<EditorRunState> emit) async {
    final running = state;
    final signal = _inFlight;
    if (running is! EditorRunning || running.waitingForRetry || signal == null) return;
    final queryId = running.queryId;
    if (!running.supportsCancel || event.stopWaiting) {
      signal.cancel();
      _scriptStartedAt = null;
      emit(const EditorCancelled(outcome: EditorCancelOutcome.stoppedWaiting));
      return;
    }
    emit(EditorCancelling(queryId: queryId));
    final answer = await _repository.cancel(connectionId, queryId);
    // The run answered first, and its answer is on screen.
    if (emit.isDone || state != EditorCancelling(queryId: queryId)) return;
    switch (answer) {
      case Success(:final data):
        _cancelAnswered = signal;
        signal.cancel();
        _scriptStartedAt = null;
        emit(EditorCancelled(outcome: data ? EditorCancelOutcome.confirmed : EditorCancelOutcome.notConfirmed));
      case Failure(:final error):
        _log.warn('cancel failed: {}', [error.code ?? error.runtimeType]);
        final waiting = error is RateLimitedError && (error.retryAfter?.inSeconds ?? 0) > 0;
        emit(EditorRunning(queryId: queryId, supportsCancel: true, cancelFailure: error, waitingForRetry: waiting));
    }
  }

  /// Sends [statement] once, to `runScript` when it is a script, and shows its answer.
  Future<void> _run(
    Emitter<EditorRunState> emit,
    EditorStatement statement,
    ProviderMeta meta,
    StudioRole? role,
    EditorHistoryTarget? history,
  ) async {
    final queryId = _newRunId();
    final signal = _inFlight = CancelSignal();
    _scriptStartedAt = statement.isScript ? clock.now() : null;
    emit(EditorRunning(queryId: queryId, supportsCancel: meta.supportsQueryCancel));
    final watch = Stopwatch()..start();
    final Result<Object> result = statement.isScript
        ? await _repository.runScript(
            connectionId,
            statement.text,
            queryId: queryId,
            catalog: statement.catalog,
            page: QueryPage.first,
            cancelSignal: signal,
          )
        : await _repository.run(
            connectionId,
            statement.text,
            queryId: queryId,
            cancelSignal: signal,
            catalog: statement.catalog,
          );
    if (identical(_inFlight, signal)) {
      _inFlight = null;
      _scriptStartedAt = null;
    }
    final cancelAnswered = identical(_cancelAnswered, signal);
    if (cancelAnswered) _cancelAnswered = null;
    if (history != null) {
      unawaited(_record(history, statement.text, result, watch.elapsed, cancelAnswered: cancelAnswered));
    }
    if (emit.isDone) return;
    switch (state) {
      case EditorRunning(queryId: final id) || EditorCancelling(queryId: final id) when id == queryId:
        break;
      // A cancel already ended the run on screen.
      case _:
        return;
    }
    switch (result) {
      // Only a cancel drops the request, and it says what happened itself.
      case Failure(:final error) when error is RequestCancelledError:
        return;
      case Failure(:final error) when error.code == AppErrorCode.studioQueryCancelled.key:
        _log.info('the run was cancelled');
        emit(const EditorCancelled(outcome: EditorCancelOutcome.confirmed));
      case Failure(:final error):
        _fail(emit, error, statement: statement);
      case Success(data: final ScriptResult script):
        _scriptAnswered(emit, script, statement, meta, role);
      case Success(data: final QueryResult data):
        final policy = MaskingPolicy.forRole(role, exempt: meta.maskingExemptColumns);
        emit(
          EditorSucceeded(
            masked: maskResult(data, policy),
            policy: policy,
            statement: statement,
            meta: meta,
            run: ++_runs,
          ),
        );
        unawaited(_schemaChanges.statementSucceeded(connectionId, statement.text));
      case Success():
        throw StateError('A run answered neither a result nor a script');
    }
  }

  /// Shows the [script] answer of [statement], each statement masked, and tells the object browser each successful
  /// statement's text.
  void _scriptAnswered(
    Emitter<EditorRunState> emit,
    ScriptResult script,
    EditorStatement statement,
    ProviderMeta meta,
    StudioRole? role,
  ) {
    final policy = MaskingPolicy.forRole(role, exempt: meta.maskingExemptColumns);
    if (script.hasError) _log.info('a script stopped at a failed statement');
    emit(
      EditorScriptAnswered(
        statements: [
          for (final item in script.statements)
            EditorScriptStatement(
              index: item.index,
              sql: item.sql,
              executionTime: item.executionTime,
              rowCount: item.rowCount,
              masked: item.result == null ? null : maskResult(item.result!, policy),
              error: item.error,
            ),
        ],
        statementCount: script.statementCount,
        executedCount: script.executedCount,
        openTransactionRolledBack: script.openTransactionRolledBack,
        policy: policy,
        statement: statement,
        meta: meta,
        run: ++_runs,
      ),
    );
    for (final item in script.statements) {
      if (item.error == null) unawaited(_schemaChanges.statementSucceeded(connectionId, item.sql));
    }
  }

  /// Runs [statement], the text of the result on screen, again for [page] with a fresh run id and in its database, for
  /// the result view's Load more. Each page runs the whole statement again on Studio, so a text the check flagged asks
  /// [confirm] first, and nothing is sent unless it answers true; the answer is then null. The state does not change,
  /// and a failure is answered, never sent again by itself.
  Future<Result<QueryResult>?> loadPage(
    EditorStatement statement,
    QueryPage page, {
    required Future<bool> Function() confirm,
  }) async {
    if (statement.asks != null && !await confirm()) return null;
    final answer = await _repository.run(
      connectionId,
      statement.text,
      queryId: _newRunId(),
      page: page,
      catalog: statement.catalog,
    );
    if (answer case Failure(:final error)) _log.warn('page not read: {}', [error.code ?? error.runtimeType]);
    return answer;
  }

  /// Adds the run of [text] that answered [result] after [elapsed] to the history of [history], unless it never
  /// reached Studio, or was dropped without a cancel Studio answered ([cancelAnswered]): Stop waiting, which leaves the
  /// outcome unknown. A cancelled run, by the user's answered cancel or Studio's 499, is Failed, as Studio's web keeps
  /// its 499. A success keeps Studio's own time and row count, and the time measured here when Studio timed it
  /// as zero, as Studio's web does (`resultData.executionTime || executionTime`).
  Future<void> _record(
    EditorHistoryTarget history,
    String text,
    Result<Object> result,
    Duration elapsed, {
    required bool cancelAnswered,
  }) async {
    final FinishedRun run;
    switch (result) {
      // A script is one entry for its whole text, as Studio's web keeps it: Failed when a statement failed, with
      // Studio's total time and the row count of the result Studio shows, the last statement with rows.
      case Success(data: final ScriptResult script):
        final shown = script.statements.reversed
            .where((statement) => statement.error == null && (statement.result?.rows.isNotEmpty ?? false))
            .firstOrNull;
        run = FinishedRun(
          connectionId: connectionId,
          connectionName: history.connectionName,
          text: text,
          status: script.hasError ? StatementRunStatus.failure : StatementRunStatus.success,
          duration: script.executionTime == Duration.zero ? elapsed : script.executionTime,
          rowCount: script.hasError ? null : (shown?.rowCount ?? 0),
        );
      case Success(data: final QueryResult data):
        run = FinishedRun(
          connectionId: connectionId,
          connectionName: history.connectionName,
          text: text,
          status: StatementRunStatus.success,
          duration: data.executionTime == Duration.zero ? elapsed : data.executionTime,
          rowCount: data.rowCount,
        );
      case Success():
        throw StateError('A run answered neither a result nor a script');
      case Failure(:final error)
          when error is NetworkError ||
              (error is TimeoutError && !error.sent) ||
              (error is RequestCancelledError && !cancelAnswered):
        return;
      case Failure():
        run = FinishedRun(
          connectionId: connectionId,
          connectionName: history.connectionName,
          text: text,
          status: StatementRunStatus.failure,
          duration: elapsed,
        );
    }
    if (await _history.record(history.subjectHash, run) case Failure(:final error)) {
      _log.warn('history entry not kept: {}', [error.code ?? error.runtimeType]);
      _onHistoryNotKept(AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic);
    }
  }

  void _fail(Emitter<EditorRunState> emit, AppError error, {EditorStatement? statement}) {
    _log.warn('run failed: {}', [error.code ?? error.runtimeType]);
    if (statement != null && error.code == AppErrorCode.studioQueryError.key) {
      final position = error is ValidationError ? error.position : null;
      emit(
        EditorStatementFailed(
          error: error,
          position: position == null ? null : statementOffsetOf(statement.text, position),
        ),
      );
      return;
    }
    final waiting = error is RateLimitedError && (error.retryAfter?.inSeconds ?? 0) > 0;
    emit(EditorFailed(error: error, waitingForRetry: waiting));
  }
}
