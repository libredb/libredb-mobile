part of 'editor_draft_bloc.dart';

sealed class EditorDraftState extends Equatable {
  const EditorDraftState();

  @override
  List<Object?> get props => const [];
}

/// Studio has named no account, so no draft is read or saved.
final class EditorDraftOff extends EditorDraftState {
  const EditorDraftOff();
}

/// The saved draft is being read; the field waits for it.
final class EditorDraftLoading extends EditorDraftState {
  const EditorDraftLoading();
}

/// The saved [draft] was read, for the field to show.
final class EditorDraftRestored extends EditorDraftState {
  const EditorDraftRestored(this.draft);

  final StatementDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// The text is kept, or there is nothing to keep yet.
final class EditorDraftKept extends EditorDraftState {
  const EditorDraftKept();
}

/// The text is longer than the store keeps, so it is not kept and the connection's earlier draft was removed.
final class EditorDraftNotKept extends EditorDraftState {
  const EditorDraftNotKept();
}

/// The device refused to save the text.
final class EditorDraftSaveFailed extends EditorDraftState {
  const EditorDraftSaveFailed(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}

/// The saved draft cannot be read: nothing is saved over it until the user discards it. [discardFailure] tells why
/// the last Discard failed.
final class EditorDraftUnreadable extends EditorDraftState {
  const EditorDraftUnreadable({this.discardFailure});

  final AppErrorCode? discardFailure;

  @override
  List<Object?> get props => [discardFailure];
}

/// Reading the saved draft failed for another reason; nothing is saved, so nothing replaces a draft not yet read.
final class EditorDraftReadFailed extends EditorDraftState {
  const EditorDraftReadFailed(this.errorCode);

  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}
