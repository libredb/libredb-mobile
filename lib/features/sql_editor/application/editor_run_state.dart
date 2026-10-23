part of 'editor_run_bloc.dart';

/// A text the editor sends, and why it asked before running, null when the check cleared it; [catalog] is the
/// database it runs in on a server-level connection, which each later page of its result names again. [isScript]
/// sends it to `runScript`, which splits it under the connection's grammar.
class EditorStatement extends Equatable {
  const EditorStatement({required this.text, this.asks, this.catalog, this.isScript = false});

  final String text;
  final AsksBeforeRunning? asks;
  final String? catalog;
  final bool isScript;

  @override
  List<Object?> get props => [text, asks, catalog, isScript];

  /// Prints the length, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'EditorStatement(${text.length} characters, asks: ${asks != null}, script: $isScript)';
}

/// The keyword that keeps a transaction's changes on [meta]'s engine, for the rolled-back notice: `EXEC` for Redis,
/// whose open transaction is a `MULTI`, and `COMMIT` for every other engine, as Studio's web names it
/// (`src/lib/db/providers/keyvalue/redis-execution-ui.ts`, `src/lib/db/execution-ui/shared.ts`).
String _commitKeywordOf(ProviderMeta meta) => meta.queryDialect == 'redis' ? 'EXEC' : 'COMMIT';

sealed class EditorRunState extends Equatable {
  const EditorRunState();

  @override
  List<Object?> get props => const [];
}

/// Nothing has run yet.
final class EditorIdle extends EditorRunState {
  const EditorIdle();
}

/// [statement] waits for the user's confirmation before it is sent; [previous] is what stays on screen meanwhile and
/// after a cancel. [meta], [role] and [history] are the run's, read when Run was tapped.
final class EditorAwaitingConfirmation extends EditorRunState {
  const EditorAwaitingConfirmation({
    required this.statement,
    required this.previous,
    required this.meta,
    required this.role,
    this.history,
  });

  final EditorStatement statement;
  final EditorRunState previous;
  final ProviderMeta meta;
  final StudioRole? role;
  final EditorHistoryTarget? history;

  /// The asks of a statement waiting here, never null.
  AsksBeforeRunning get asks => statement.asks!;

  @override
  List<Object?> get props => [statement, previous, meta, role, history];

  @override
  String toString() => 'EditorAwaitingConfirmation($statement, previous: ${previous.runtimeType})';
}

/// The statement is in flight under [queryId]. [supportsCancel] is the engine's `supportsQueryCancel`: with it Cancel
/// asks Studio to stop the run, without it Stop waiting only drops the request.
///
/// [cancelFailure] is why the last cancel failed, shown while the run goes on; while [waitingForRetry], the delay a
/// rate limit on the cancel asked for runs and Cancel sends nothing.
final class EditorRunning extends EditorRunState {
  const EditorRunning({
    required this.queryId,
    required this.supportsCancel,
    this.cancelFailure,
    this.waitingForRetry = false,
  });

  final String queryId;
  final bool supportsCancel;
  final AppError? cancelFailure;
  final bool waitingForRetry;

  @override
  List<Object?> get props => [queryId, supportsCancel, cancelFailure, waitingForRetry];

  @override
  String toString() =>
      'EditorRunning($queryId, cancel: $supportsCancel, cancelFailure: ${cancelFailure?.code}, '
      'waiting: $waitingForRetry)';
}

/// Cancel of the run [queryId] is posted to Studio, and the run's request is still open.
final class EditorCancelling extends EditorRunState {
  const EditorCancelling({required this.queryId});

  final String queryId;

  @override
  List<Object?> get props => [queryId];
}

/// What a cancel told the user, never shown as an error.
enum EditorCancelOutcome {
  /// Studio stopped the run: it confirmed the cancel, or the run answered `QUERY_CANCELLED`.
  confirmed,

  /// Studio answered that it stopped nothing; the app stopped waiting, and the statement may still run.
  notConfirmed,

  /// The engine cannot cancel, so the app only stopped waiting; the statement may still run.
  stoppedWaiting,
}

/// The run ended by a cancel, with [outcome].
final class EditorCancelled extends EditorRunState {
  const EditorCancelled({required this.outcome});

  final EditorCancelOutcome outcome;

  @override
  List<Object?> get props => [outcome];
}

/// The answer of [statement], masked with [policy]; [run] tells it from the next one.
final class EditorSucceeded extends EditorRunState {
  const EditorSucceeded({
    required this.masked,
    required this.policy,
    required this.statement,
    required this.meta,
    required this.run,
  });

  final MaskedResult masked;
  final MaskingPolicy policy;
  final EditorStatement statement;
  final ProviderMeta meta;
  final int run;

  /// Whether the engine applies an offset, so Load more may be offered.
  bool get supportsResultPagination => meta.supportsResultPagination;

  /// The keyword that keeps a transaction's changes on this engine, for the rolled-back notice.
  String get commitKeyword => _commitKeywordOf(meta);

  @override
  List<Object?> get props => [masked, policy, statement, meta, run];

  @override
  String toString() => 'EditorSucceeded(run: $run, $statement)';
}

/// One statement of a script answer, with its rows masked: [index] from 0, the start of its [sql] for the card, its
/// time, and either its [rowCount] and [masked] rows, or the database's own [error] words, shown on screen only and
/// never logged. A successful statement whose answer carried no columns has a row count and no rows.
class EditorScriptStatement extends Equatable {
  const EditorScriptStatement({
    required this.index,
    required this.sql,
    required this.executionTime,
    this.rowCount,
    this.masked,
    this.error,
  });

  final int index;
  final String sql;
  final Duration executionTime;
  final int? rowCount;
  final MaskedResult? masked;
  final String? error;

  bool get failed => error != null;

  @override
  List<Object?> get props => [index, sql, executionTime, rowCount, masked, error];

  /// Prints neither the text nor the error, which can hold customer data.
  @override
  String toString() => 'EditorScriptStatement($index, failed: $failed, rows: $rowCount)';
}

/// The answer of the script [statement]: a card per statement Studio ran, in order and stopping at the first failure,
/// each masked with [policy]; [statementCount] is how many Studio found, so `notRun` were never started. Studio
/// answers no paging for a script, so no statement offers Load more. [run] tells it from the next answer.
final class EditorScriptAnswered extends EditorRunState {
  const EditorScriptAnswered({
    required this.statements,
    required this.statementCount,
    required this.executedCount,
    required this.openTransactionRolledBack,
    required this.policy,
    required this.statement,
    required this.meta,
    required this.run,
  });

  final List<EditorScriptStatement> statements;
  final int statementCount;
  final int executedCount;

  /// The script left a transaction open, and Studio rolled it back.
  final bool openTransactionRolledBack;
  final MaskingPolicy policy;
  final EditorStatement statement;
  final ProviderMeta meta;
  final int run;

  bool get hasError => statements.any((statement) => statement.failed);

  /// The statements Studio found but did not run, after a failure.
  int get notRun => statementCount > executedCount ? statementCount - executedCount : 0;

  /// The keyword that keeps a transaction's changes on this engine, for the rolled-back notice.
  String get commitKeyword => _commitKeywordOf(meta);

  @override
  List<Object?> get props => [
    statements,
    statementCount,
    executedCount,
    openTransactionRolledBack,
    policy,
    statement,
    meta,
    run,
  ];

  @override
  String toString() => 'EditorScriptAnswered(run: $run, $executedCount of $statementCount, $statement)';
}

/// The database refused the statement (`studio.query_error`): [error] carries its own words, shown on screen only and
/// never logged, and [position] is the UTF-16 offset in the text that ran where the database placed the error, when
/// it reported one.
final class EditorStatementFailed extends EditorRunState {
  const EditorStatementFailed({required this.error, this.position});

  final AppError error;
  final int? position;

  @override
  List<Object?> get props => [error, position];

  @override
  String toString() => 'EditorStatementFailed(${error.code}, position: $position)';
}

/// The run failed, or was refused before it was sent; [error] is shown by `StudioErrorBanner`, which needs the error
/// itself for a rate limit's delay. While [waitingForRetry], the delay a rate limit asked for runs and Run sends
/// nothing. Nothing logs its message.
final class EditorFailed extends EditorRunState {
  const EditorFailed({required this.error, this.waitingForRetry = false});

  final AppError error;
  final bool waitingForRetry;

  @override
  List<Object?> get props => [error, waitingForRetry];

  @override
  String toString() => 'EditorFailed(${error.code}, waiting: $waitingForRetry)';
}
