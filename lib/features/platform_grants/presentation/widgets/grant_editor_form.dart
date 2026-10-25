import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_editor_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/directory_user_badges.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_button.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The grant form: who, the level and the expiry, and where Platform's refusal lands.
///
/// [onChangeUser] goes back to the picker; null when the editor opened on a grant.
class GrantEditorForm extends StatelessWidget {
  const GrantEditorForm({super.key, this.onChangeUser});

  final VoidCallback? onChangeUser;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<GrantEditorBloc, GrantEditorState>(
      builder: (context, state) {
        final bloc = context.read<GrantEditorBloc>();
        final submitting = state.status != GrantEditorStatus.editing;
        return ListView(
          key: const ValueKey('platform-grant-editor-form'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (state.bannerCode case final code?) ...[
              _Banner(banner: state.banner!, code: code, retrying: submitting),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              state.isEdit
                  ? s.platform_grants_editor_title_edit(state.target.connectionName)
                  : s.platform_grants_editor_title_new(state.target.connectionName),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _SubjectLine(state: state, onChangeUser: submitting ? null : onChangeUser),
            const SizedBox(height: AppSpacing.xl),
            Text(s.platform_grants_editor_level, style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              key: const ValueKey('platform-grant-level'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'read',
                  label: Text(s.platform_grants_level_read),
                  icon: const Icon(Icons.visibility_outlined),
                ),
                ButtonSegment(
                  value: 'write',
                  label: Text(s.platform_grants_level_write),
                  icon: const Icon(Icons.edit_outlined),
                  enabled: state.writeAvailable,
                ),
              ],
              selected: {?state.level},
              onSelectionChanged: submitting
                  ? null
                  : (picked) {
                      if (picked.isNotEmpty) bloc.add(GrantEditorLevelChanged(picked.single));
                    },
            ),
            if (!state.writeAvailable) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.platform_grants_editor_write_unavailable,
                key: const ValueKey('platform-grant-write-unavailable'),
                style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            if (_levelIssueText(context, state.levelIssue) case final text?) _FieldError(text, field: 'level'),
            const SizedBox(height: AppSpacing.xl),
            Text(s.platform_grants_editor_expiry, style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _ExpiryField(state: state, enabled: !submitting),
            if (_expiryIssueText(context, state.expiryIssue) case final text?) _FieldError(text, field: 'expiry'),
            if (state.formError case final code?) ...[
              const SizedBox(height: AppSpacing.lg),
              _FieldError(code.resolve(context), field: 'form'),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: const ValueKey('platform-grant-save'),
              label: s.platform_grants_editor_save,
              fullWidth: true,
              isLoading: submitting,
              onPressed: submitting ? null : () => bloc.add(const GrantEditorSubmitted()),
            ),
          ],
        );
      },
    );
  }

  static String? _levelIssueText(BuildContext context, GrantLevelIssue? issue) => switch (issue) {
    null => null,
    GrantLevelIssue.missing => S.of(context).platform_grants_editor_level_missing,
    GrantLevelIssue.writeUnavailable => S.of(context).platform_grants_editor_write_unavailable,
    GrantLevelIssue.refused => AppErrorCode.platformGrantLevelRefused.resolve(context),
  };

  static String? _expiryIssueText(BuildContext context, GrantExpiryIssue? issue) => switch (issue) {
    null => null,
    GrantExpiryIssue.notInFuture => S.of(context).platform_grants_editor_expiry_not_in_future,
    GrantExpiryIssue.refused => AppErrorCode.platformGrantExpiryRefused.resolve(context),
  };
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text, {required this.field});

  final String text;
  final String field;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          key: ValueKey('platform-grant-error-$field'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
        ),
      ),
    );
  }
}

/// Who the grant names, with the role and seat notes, the subject refusal, and the way back to the picker.
class _SubjectLine extends StatelessWidget {
  const _SubjectLine({required this.state, required this.onChangeUser});

  final GrantEditorState state;
  final VoidCallback? onChangeUser;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final subject = state.subject;
    return AppCard(
      key: const ValueKey('platform-grant-subject'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject.username, style: textTheme.titleSmall),
          if (subject.fullName case final name?) Text(name, style: secondary),
          if (subject.email case final email?) Text(email, style: secondary),
          if (subject.fromDirectory) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StudioRoleBadge(role: subject.studioRole),
                if (subject.needsSeat) SeatNote(active: state.target.active),
              ],
            ),
            if (subject.studioRole == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.platform_grants_editor_no_role_note,
                key: const ValueKey('platform-grant-no-role-note'),
                style: secondary,
              ),
            ],
          ],
          if (state.subjectRefused)
            _FieldError(AppErrorCode.platformGrantSubjectRefused.resolve(context), field: 'subject'),
          if (onChangeUser case final change?)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: change, child: Text(s.platform_grants_editor_change_user)),
            ),
        ],
      ),
    );
  }
}

/// "Never expires", or a local date and time picked with the date and time pickers, seconds dropped.
class _ExpiryField extends StatelessWidget {
  const _ExpiryField({required this.state, required this.enabled});

  final GrantEditorState state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final expiresAt = state.expiresAt;
    final secondary = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          expiresAt == null
              ? s.platform_grants_editor_expiry_never
              : s.platform_grants_editor_expiry_on(formatGrantDate(context, expiresAt)),
          key: const ValueKey('platform-grant-expiry-value'),
        ),
        Text(s.platform_grants_editor_expiry_local_time, style: secondary),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('platform-grant-expiry-pick'),
              onPressed: enabled ? () => _pick(context) : null,
              icon: const Icon(Icons.event_outlined),
              label: Text(s.platform_grants_editor_expiry_pick),
            ),
            if (expiresAt != null)
              TextButton(
                key: const ValueKey('platform-grant-expiry-never'),
                onPressed: enabled
                    ? () => context.read<GrantEditorBloc>().add(const GrantEditorExpiryChanged(null))
                    : null,
                child: Text(s.platform_grants_editor_expiry_never),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final bloc = context.read<GrantEditorBloc>();
    final now = DateTime.now();
    final current = state.expiresAt?.toLocal();
    final initial = current != null && current.isAfter(now) ? current : now.add(const Duration(days: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    bloc.add(GrantEditorExpiryChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute)));
  }
}

/// The refusal shown above the form: the license, Keycloak not answering with Retry, or the connection gone with the
/// way back to the connection list.
class _Banner extends StatelessWidget {
  const _Banner({required this.banner, required this.code, required this.retrying});

  final GrantEditorBanner banner;
  final AppErrorCode code;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (title, action) = switch (banner) {
      GrantEditorBanner.license => (s.platform_grants_editor_license_title, null),
      GrantEditorBanner.retry => (
        s.platform_grants_editor_retry_title,
        TextButton(
          key: const ValueKey('platform-grant-retry'),
          onPressed: retrying ? null : () => context.read<GrantEditorBloc>().add(const GrantEditorRetryRequested()),
          child: Text(s.retry),
        ),
      ),
      GrantEditorBanner.connectionGone => (
        s.platform_grants_connection_gone_title,
        TextButton(
          key: const ValueKey('platform-grant-back-to-connections'),
          onPressed: () => context.go(ApplicationRoutesConstants.platformConnections),
          child: Text(s.platform_grants_back_to_connections),
        ),
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: ValueKey('platform-grant-banner-${banner.name}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall?.copyWith(color: colorScheme.onErrorContainer)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    code == AppErrorCode.platformNotFound
                        ? s.platform_grants_connection_gone_description
                        : code.resolve(context),
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                  ),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
