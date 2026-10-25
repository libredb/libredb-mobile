part of 'audit_log_bloc.dart';

sealed class AuditLogEvent extends Equatable {
  const AuditLogEvent();

  @override
  List<Object?> get props => const [];
}

/// An event that reads the first page again, for the current filter or a new one; a newer one replaces one running.
sealed class AuditLogQueryEvent extends AuditLogEvent {
  const AuditLogQueryEvent();
}

/// Reads the first page of the current filter: the first load, a pull, a retry.
final class AuditLogRefreshed extends AuditLogQueryEvent {
  const AuditLogRefreshed();
}

/// Reads the first page of [filter], which replaces the current one.
final class AuditLogFilterChanged extends AuditLogQueryEvent {
  const AuditLogFilterChanged(this.filter);

  final AuditFilter filter;

  @override
  List<Object?> get props => [filter];

  /// The names of the set filters only, which [AuditFilter.toString] gives: a value can name a person.
  @override
  String toString() => 'AuditLogFilterChanged($filter)';
}

/// The search field of the filter sheet now holds [text], as typed.
final class AuditLogSearchChanged extends AuditLogEvent {
  const AuditLogSearchChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];

  /// Not the text: it can quote a statement, and this event can reach a log.
  @override
  String toString() => 'AuditLogSearchChanged(length: ${text.length})';
}

/// The next page of the current filter.
final class AuditLogLoadMoreRequested extends AuditLogEvent {
  const AuditLogLoadMoreRequested();
}
