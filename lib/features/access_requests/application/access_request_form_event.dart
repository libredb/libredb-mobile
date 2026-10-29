part of 'access_request_form_bloc.dart';

sealed class AccessRequestFormEvent extends Equatable {
  const AccessRequestFormEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the connections the user may ask for, when the form opens and on the retry of a failure.
final class AccessRequestFormLoadRequested extends AccessRequestFormEvent {
  const AccessRequestFormLoadRequested();
}

final class AccessRequestFormConnectionPicked extends AccessRequestFormEvent {
  const AccessRequestFormConnectionPicked(this.connectionId);

  final String connectionId;

  @override
  List<Object?> get props => [connectionId];
}

final class AccessRequestFormLevelPicked extends AccessRequestFormEvent {
  const AccessRequestFormLevelPicked(this.level);

  final String level;

  @override
  List<Object?> get props => [level];
}

final class AccessRequestFormReasonChanged extends AccessRequestFormEvent {
  const AccessRequestFormReasonChanged(this.reason);

  /// The text as typed; it is trimmed when the request is sent. It never reaches a log.
  final String reason;

  @override
  List<Object?> get props => [reason];

  @override
  String toString() => 'AccessRequestFormReasonChanged(length: ${reason.length})';
}

/// Sends the request; dropped while one is out.
final class AccessRequestFormSendRequested extends AccessRequestFormEvent {
  const AccessRequestFormSendRequested();
}
