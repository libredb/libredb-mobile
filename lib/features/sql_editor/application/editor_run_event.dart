part of 'editor_run_bloc.dart';

sealed class EditorRunEvent extends Equatable {
  const EditorRunEvent();

  @override
  List<Object?> get props => const [];
}

/// Where a run's history entry goes: the account Studio named when Run was tapped, as its subject hash, and the name of
/// the connection the run is on.
final class EditorHistoryTarget extends Equatable {
  const EditorHistoryTarget({required this.subjectHash, required this.connectionName});

  final String subjectHash;
  final String connectionName;

  @override
  List<Object?> get props => [subjectHash, connectionName];

  /// Prints neither the account nor the connection.
  @override
  String toString() => 'EditorHistoryTarget';
}

/// Run [text] for [role], the role Studio names now, whose policy masks the answer, in [catalog], the database picked
/// on a server-level connection, or null on any other, and add it to the history of [history]; null while Studio has
/// named no account, when nothing is kept.
final class EditorRunRequested extends EditorRunEvent {
  const EditorRunRequested({required this.text, required this.role, this.catalog, this.history});

  final String text;
  final StudioRole? role;
  final String? catalog;
  final EditorHistoryTarget? history;

  @override
  List<Object?> get props => [text, role, catalog, history];

  /// Prints the length, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'EditorRunRequested(${text.length} characters)';
}

/// The user's answer to the write confirmation: run the text it showed, or not.
final class EditorConfirmationAnswered extends EditorRunEvent {
  const EditorConfirmationAnswered({required this.confirmed});

  final bool confirmed;

  @override
  List<Object?> get props => [confirmed];
}

/// The delay a rate limit asked for has passed, so Run, or Cancel of a run, may send again.
final class EditorRateLimitElapsed extends EditorRunEvent {
  const EditorRateLimitElapsed();
}

/// Cancel (or Stop waiting) of the statement in flight. With [stopWaiting] the request is only dropped and nothing is
/// posted, which the editor offers after a cancel that failed.
final class EditorCancelRequested extends EditorRunEvent {
  const EditorCancelRequested({this.stopWaiting = false});

  final bool stopWaiting;

  @override
  List<Object?> get props => [stopWaiting];
}
