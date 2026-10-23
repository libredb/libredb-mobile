part of 'editor_draft_bloc.dart';

sealed class EditorDraftEvent extends Equatable {
  const EditorDraftEvent();

  @override
  List<Object?> get props => const [];
}

/// The account Studio named for the signed-in user changed, as its subject hash: null while it names none, when no
/// draft is read or saved.
final class EditorDraftSubjectChanged extends EditorDraftEvent {
  const EditorDraftSubjectChanged(this.subjectHash);

  final String? subjectHash;

  /// Prints whether there is a subject, never its hash, which no log line holds.
  @override
  String toString() => 'EditorDraftSubjectChanged(subject: ${subjectHash != null})';

  @override
  List<Object?> get props => [subjectHash];
}

/// The text in the field changed; it is saved once typing pauses.
final class EditorDraftTextChanged extends EditorDraftEvent {
  const EditorDraftTextChanged(this.text, {this.catalog});

  final String text;

  /// The database the text is typed for on a server-level connection.
  final String? catalog;

  /// Prints the length, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'EditorDraftTextChanged(${text.length} characters, catalog: ${catalog != null})';

  @override
  List<Object?> get props => [text, catalog];
}

/// Saves the latest text now, without waiting for the pause: the app goes to the background.
final class EditorDraftFlushRequested extends EditorDraftEvent {
  const EditorDraftFlushRequested();
}

/// Removes the saved draft that cannot be read, which the user confirmed.
final class EditorDraftDiscardRequested extends EditorDraftEvent {
  const EditorDraftDiscardRequested();
}

/// Reads the saved draft again after a read that failed.
final class EditorDraftRetryRequested extends EditorDraftEvent {
  const EditorDraftRetryRequested();
}

/// The user answered which text to keep after [EditorDraftConflict]: the saved draft when [restore], else the text
/// typed before Studio named the account, which is then saved as the draft.
final class EditorDraftConflictAnswered extends EditorDraftEvent {
  const EditorDraftConflictAnswered({required this.restore});

  final bool restore;

  @override
  List<Object?> get props => [restore];
}
