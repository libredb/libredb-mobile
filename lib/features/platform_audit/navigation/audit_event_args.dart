import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';

/// What the audit list hands the event page as route `extra`: the [event] it already holds, since Platform has no
/// route that reads one event, and [onFilterSelected], which narrows the list's filter.
///
/// The list's bloc is provided by the list page, which is no ancestor of the pushed event page, so the event page
/// reaches it only through this callback: it passes a function from the list's current filter to the new one.
@immutable
final class AuditEventArgs {
  const AuditEventArgs({required this.event, required this.onFilterSelected});

  final AuditEvent event;

  final void Function(AuditFilter Function(AuditFilter current) update) onFilterSelected;

  /// The event id and status only, which [AuditEvent.toString] gives: this text can reach a log.
  @override
  String toString() => 'AuditEventArgs($event)';
}
