import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';

/// One page of LibreDB Platform's audit log: the [events] from [offset], newest first, and the [total] of events the
/// filters select on every page.
///
/// Offset paging over a newest-first list repeats an event when a new one arrives between two pages: every older event
/// moves one place down, so the next page starts with the last event of this one. A screen that appends a page drops
/// an event whose `eventId` it already shows.
final class AuditPage extends Equatable {
  const AuditPage({required this.events, required this.total, required this.offset});

  final List<AuditEvent> events;
  final int total;

  /// The offset this page was asked from.
  final int offset;

  /// Whether another page follows this one.
  bool get hasMore => events.isNotEmpty && offset + events.length < total;

  @override
  List<Object?> get props => [events, total, offset];

  @override
  String toString() => 'AuditPage(events: ${events.length}, total: $total, offset: $offset)';
}
