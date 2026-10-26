import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/audit_event_args.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/widgets/audit_labels.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// One governed query event of the audit log, every field Platform sent, a missing one shown as not recorded.
///
/// The event is the one the list holds, since Platform has no route that reads one event. The statement and the
/// database's error message can carry a database's data, so that area is kept out of screenshots while on screen.
/// "Only this user" and "Only this connection" narrow the list's filter and return to it.
class AuditEventPage extends StatelessWidget {
  const AuditEventPage({super.key, required this.args});

  final AuditEventArgs args;

  AuditEvent get _event => args.event;

  void _narrow(BuildContext context, {String? subject, String? connectionId}) {
    args.onFilterSelected(
      (current) => current.copyWith(
        subject: subject == null ? null : () => subject,
        connectionId: connectionId == null ? null : () => connectionId,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final event = _event;
    final finishedAt = event.finishedAt;
    final rowCount = event.rowCount;
    // Not a lazy list: the guarded statement area below the fold must be mounted, and hold its lease, while the page is
    // shown, or the recent apps view would capture the page.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('platform-audit-only-user'),
                onPressed: () => _narrow(context, subject: event.subject),
                icon: const Icon(Icons.person_search_outlined),
                label: Text(s.platform_audit_only_this_user),
              ),
              OutlinedButton.icon(
                key: const ValueKey('platform-audit-only-connection'),
                onPressed: () => _narrow(context, connectionId: event.connectionId),
                icon: const Icon(Icons.storage_outlined),
                label: Text(s.platform_audit_only_this_connection),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field('eventId', s.platform_audit_field_event_id, event.eventId),
                _Field('status', s.platform_audit_field_status, auditStatusLabel(s, event.status)),
                _Field('started', s.platform_audit_field_started, auditDateTime(context, event.startedAt)),
                _Field(
                  'finished',
                  s.platform_audit_field_finished,
                  finishedAt == null ? null : auditDateTime(context, finishedAt),
                ),
                _Field('duration', s.platform_audit_field_duration, s.platform_audit_duration(event.durationMs)),
                _Field('rows', s.platform_audit_field_rows, rowCount?.toString()),
                _Field('user', s.platform_audit_field_user, event.username),
                _Field('subject', s.platform_audit_field_subject, event.subject),
                _Field('sessionRole', s.platform_audit_field_session_role, event.sessionRole),
                _Field('connection', s.platform_audit_field_connection, auditConnectionLabel(s, event)),
                _Field('connectionId', s.platform_audit_field_connection_id, event.connectionId),
                _Field('engine', s.platform_audit_field_engine, event.engine),
                _Field('accessLevel', s.platform_audit_field_access_level, event.accessLevel),
                _Field('source', s.platform_audit_field_source, event.source),
                _Field('statementType', s.platform_audit_field_statement_type, event.statementType),
                _Field('explain', s.platform_audit_field_explain, event.explain),
                _Field('capture', s.platform_audit_field_capture, auditCaptureLabel(s, event.statementCapture)),
                _Field('transaction', s.platform_audit_field_transaction, event.transactionOutcome),
                _Field('errorCode', s.platform_audit_field_error_code, event.errorCode),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The statement and the database's error text can carry a database's data.
          ScreenCaptureGuard(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatementField(event: event),
                  _Field('errorMessage', s.platform_audit_field_error_message, event.errorMessage, selectable: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One field of the event: its label and its value, or "Not recorded" for a null value.
class _Field extends StatelessWidget {
  const _Field(this.name, this.label, this.value, {this.selectable = false});

  final String name;
  final String label;
  final String? value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final value = this.value;
    return Padding(
      key: ValueKey('platform-audit-field-$name'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          if (value == null)
            Text(
              S.of(context).platform_audit_not_recorded,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            )
          else if (selectable)
            SelectableText(value, style: textTheme.bodyMedium)
          else
            Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// The statement in a monospace block that can be selected, with what Platform's capture did to it.
class _StatementField extends StatelessWidget {
  const _StatementField({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final note = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic);
    final statement = event.statement;
    final captured = statement != null && event.statementCapture != 'none';
    return Padding(
      key: const ValueKey('platform-audit-field-statement'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.platform_audit_field_statement,
            style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (captured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: SelectableText(statement, style: textTheme.bodySmall?.copyWith(fontFamily: AppTypography.mono)),
            )
          else
            Text(s.platform_audit_statement_none, style: note),
          if (captured && event.statementCapture == 'redacted') ...[
            const SizedBox(height: AppSpacing.xs),
            Text(s.platform_audit_statement_redacted, style: note),
          ],
          if (captured && event.statementTruncated) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(s.platform_audit_statement_truncated, style: note),
          ],
        ],
      ),
    );
  }
}
