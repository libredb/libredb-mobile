import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';

/// How many characters of a Keycloak `sub` name a user that Studio recorded no username for.
const _shortSubjectLength = 8;

/// The user of [event]: its username, else the start of its Keycloak `sub`.
String auditUserLabel(AuditEvent event) => event.username ?? auditShortSubject(event.subject);

/// The start of a Keycloak `sub`, enough to tell users apart on a phone.
String auditShortSubject(String subject) =>
    subject.length <= _shortSubjectLength ? subject : subject.substring(0, _shortSubjectLength);

/// The connection of [event]: its name, or the app's marker when it names no Platform connection, in place of
/// Platform's English label.
String auditConnectionLabel(S s, AuditEvent event) =>
    event.connectionKnown == false ? s.platform_audit_unknown_connection : event.connectionName;

/// The label of a status, or the status as Platform sent it when it is unknown.
String auditStatusLabel(S s, String status) => switch (status) {
  'success' => s.platform_audit_status_success,
  'error' => s.platform_audit_status_error,
  'cancelled' => s.platform_audit_status_cancelled,
  'refused' => s.platform_audit_status_refused,
  _ => status,
};

/// The colour of a status badge, neutral for an unknown status.
Color auditStatusColor(BuildContext context, String status) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status) {
    'success' => context.semanticColors.success,
    'error' => colorScheme.error,
    'refused' => context.semanticColors.warning,
    _ => colorScheme.onSurfaceVariant,
  };
}

/// The label of a statement capture, or the capture as Platform sent it when it is unknown.
String auditCaptureLabel(S s, String capture) => switch (capture) {
  'full' => s.platform_audit_capture_full,
  'redacted' => s.platform_audit_capture_redacted,
  'none' => s.platform_audit_capture_none,
  _ => capture,
};

/// [value] as a local date in the language of the app.
String auditDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(value.toLocal());

/// [value] as a local date and time in the language of the app.
String auditDateTime(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hms().format(value.toLocal());

/// [value] relative to now within a day, else as a local date and time; a time up to a minute ahead, as clocks
/// differ, is now.
String auditRelativeTime(BuildContext context, DateTime value) {
  final s = S.of(context);
  final age = clock.now().difference(value);
  if (age < const Duration(minutes: -1) || age >= const Duration(days: 1)) {
    return DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(value.toLocal());
  }
  if (age < const Duration(minutes: 1)) return s.platform_audit_time_just_now;
  if (age < const Duration(hours: 1)) return s.platform_audit_time_minutes_ago(age.inMinutes);
  return s.platform_audit_time_hours_ago(age.inHours);
}

/// The first line of [statement], for a row.
String auditFirstLine(String statement) {
  final trimmed = statement.trimLeft();
  final end = trimmed.indexOf('\n');
  return (end < 0 ? trimmed : trimmed.substring(0, end)).trimRight();
}
