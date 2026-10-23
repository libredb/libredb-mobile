part of 'editor_run_bloc.dart';

/// A text the editor sends, and why it asked before running, null when the check cleared it.
class EditorStatement extends Equatable {
  const EditorStatement({required this.text, this.asks});

  final String text;
  final AsksBeforeRunning? asks;

  @override
  List<Object?> get props => [text, asks];

  /// Prints the length, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'EditorStatement(${text.length} characters, asks: ${asks != null})';
}

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
/// after a cancel. [meta] and [role] are the run's, read when Run was tapped.
final class EditorAwaitingConfirmation extends EditorRunState {
  const EditorAwaitingConfirmation({
    required this.statement,
    required this.previous,
    required this.meta,
    required this.role,
  });

  final EditorStatement statement;
  final EditorRunState previous;
  final ProviderMeta meta;
  final StudioRole? role;

  /// The asks of a statement waiting here, never null.
  AsksBeforeRunning get asks => statement.asks!;

  @override
  List<Object?> get props => [statement, previous, meta, role];

  @override
  String toString() => 'EditorAwaitingConfirmation($statement, previous: ${previous.runtimeType})';
}

/// The statement is in flight under [queryId].
final class EditorRunning extends EditorRunState {
  const EditorRunning({required this.queryId});

  final String queryId;

  @override
  List<Object?> get props => [queryId];
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

  /// The keyword that keeps a transaction's changes on this engine, for the rolled-back notice: `EXEC` for Redis,
  /// whose open transaction is a `MULTI`, and `COMMIT` for every other engine, as Studio's web names it
  /// (`src/lib/db/providers/keyvalue/redis-execution-ui.ts`, `src/lib/db/execution-ui/shared.ts`).
  String get commitKeyword => meta.queryDialect == 'redis' ? 'EXEC' : 'COMMIT';

  @override
  List<Object?> get props => [masked, policy, statement, meta, run];

  @override
  String toString() => 'EditorSucceeded(run: $run, $statement)';
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
