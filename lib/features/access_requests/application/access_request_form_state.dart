part of 'access_request_form_bloc.dart';

/// A field of the form, for what is missing from it and where a refusal lands.
enum AccessRequestField { connection, level, reason }

sealed class AccessRequestFormState extends Equatable {
  const AccessRequestFormState();

  @override
  List<Object?> get props => const [];
}

/// The connections are being loaded.
final class AccessRequestFormLoading extends AccessRequestFormState {
  const AccessRequestFormLoading();
}

final class AccessRequestFormLoadFailure extends AccessRequestFormState {
  const AccessRequestFormLoadFailure({required this.errorCode});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  @override
  List<Object?> get props => [errorCode];
}

/// The form with its draft. [submission] says whether a request is out or was refused; the draft stays either way.
final class AccessRequestFormReady extends AccessRequestFormState {
  const AccessRequestFormReady({
    required this.connections,
    this.connectionId,
    this.level,
    this.reason = '',
    this.submission = const SubmissionIdle(),
  });

  /// The requestable connections in Platform's order.
  final List<RequestableConnection> connections;

  final String? connectionId;

  /// The level picked, `read` or `write`; null until picked.
  final String? level;

  /// The reason as typed, not trimmed. It never reaches a log.
  final String reason;

  final AccessRequestSubmission submission;

  /// The connection picked, or null.
  RequestableConnection? get connection => connections.where((c) => c.id == connectionId).firstOrNull;

  /// A copy with the given fields; [level] is cleared by [clearLevel].
  AccessRequestFormReady copyWith({
    String? connectionId,
    String? level,
    bool clearLevel = false,
    String? reason,
    AccessRequestSubmission? submission,
  }) => AccessRequestFormReady(
    connections: connections,
    connectionId: connectionId ?? this.connectionId,
    level: clearLevel ? null : (level ?? this.level),
    reason: reason ?? this.reason,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [connections, connectionId, level, reason, submission];

  /// No reason: this text can reach a log.
  @override
  String toString() =>
      'AccessRequestFormReady(connections: ${connections.length}, connectionId: $connectionId, level: $level, '
      'reasonLength: ${reason.length}, submission: $submission)';
}

/// Platform took the request; [request] is it as Platform holds it. The page closes to "My requests".
final class AccessRequestFormSubmitted extends AccessRequestFormState {
  const AccessRequestFormSubmitted(this.request);

  final MyAccessRequest request;

  @override
  List<Object?> get props => [request];
}

/// Where the sending of the draft stands.
sealed class AccessRequestSubmission extends Equatable {
  const AccessRequestSubmission();

  @override
  List<Object?> get props => const [];
}

/// Nothing has been sent, or the draft changed since the last refusal.
final class SubmissionIdle extends AccessRequestSubmission {
  const SubmissionIdle();
}

final class SubmissionSending extends AccessRequestSubmission {
  const SubmissionSending();
}

/// Send was pressed on a draft that cannot be sent yet; nothing was sent. [missing] names the fields to fix.
final class SubmissionIncomplete extends AccessRequestSubmission {
  const SubmissionIncomplete(this.missing);

  final Set<AccessRequestField> missing;

  @override
  List<Object?> get props => [missing];
}

/// Platform refused, or did not answer. [field] is set for a refusal that belongs under one field.
final class SubmissionRefused extends AccessRequestSubmission {
  const SubmissionRefused({required this.errorCode, this.field});

  /// Shown via `errorCode.resolve(context)`; the raw message only goes to the log.
  final AppErrorCode errorCode;

  final AccessRequestField? field;

  @override
  List<Object?> get props => [errorCode, field];
}
