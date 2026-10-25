part of 'grant_editor_bloc.dart';

sealed class GrantEditorEvent extends Equatable {
  const GrantEditorEvent();

  @override
  List<Object?> get props => const [];
}

/// The admin picked [level], `read` or `write`.
final class GrantEditorLevelChanged extends GrantEditorEvent {
  const GrantEditorLevelChanged(this.level);

  final String level;

  @override
  List<Object?> get props => [level];
}

/// The admin set the expiry to [expiresAt], a local date and time, or to never when it is null.
final class GrantEditorExpiryChanged extends GrantEditorEvent {
  const GrantEditorExpiryChanged(this.expiresAt);

  final DateTime? expiresAt;

  @override
  List<Object?> get props => [expiresAt];
}

/// A request to send the grant `PUT`; one sent while another runs is dropped.
sealed class GrantEditorSaveRequested extends GrantEditorEvent {
  const GrantEditorSaveRequested();
}

/// Save: the form is checked, then sent.
final class GrantEditorSubmitted extends GrantEditorSaveRequested {
  const GrantEditorSubmitted();
}

/// Retry after Platform could not read Keycloak: the form is checked and sent again as it shows now.
final class GrantEditorRetryRequested extends GrantEditorSaveRequested {
  const GrantEditorRetryRequested();
}
