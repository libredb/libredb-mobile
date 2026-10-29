import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/access_requests/application/access_request_form_bloc.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_button.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';

/// The form that asks for access to a connection: a connection, a level and a reason.
///
/// A connection the user cannot ask for is shown disabled with the reason, and so is a level. A refusal keeps the
/// draft and lands under its field, or, when it belongs to none, above Send with Retry. The page asks before it is left
/// with a reason written; a request that Platform took closes it to "My requests".
class AccessRequestFormPage extends StatelessWidget {
  const AccessRequestFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesScope(
      hasUnsavedChanges: () => switch (context.read<AccessRequestFormBloc>().state) {
        AccessRequestFormReady(:final reason) => reason.trim().isNotEmpty,
        AccessRequestFormLoading() || AccessRequestFormLoadFailure() || AccessRequestFormSubmitted() => false,
      },
      onBack: () => _leave(context),
      child: BlocListener<AccessRequestFormBloc, AccessRequestFormState>(
        listener: _onState,
        child: Scaffold(
          body: BlocBuilder<AccessRequestFormBloc, AccessRequestFormState>(
            builder: (context, state) => switch (state) {
              AccessRequestFormLoading() => const Center(
                child: CircularProgressIndicator(key: ValueKey('access-request-loading')),
              ),
              AccessRequestFormLoadFailure(:final errorCode) => AppErrorState(
                title: S.of(context).access_requests_form_load_failed,
                description: errorCode.resolve(context),
                retryLabel: S.of(context).retry,
                onRetry: () => context.read<AccessRequestFormBloc>().add(const AccessRequestFormLoadRequested()),
              ),
              AccessRequestFormReady(connections: []) => AppEmptyState(
                icon: Icons.storage_outlined,
                title: S.of(context).access_requests_form_no_connections,
              ),
              final AccessRequestFormReady ready => _Form(state: ready),
              // The listener closes the page; until then the form stays as it was.
              AccessRequestFormSubmitted() => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  void _onState(BuildContext context, AccessRequestFormState state) {
    if (state is AccessRequestFormSubmitted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.of(context).access_requests_sent_snackbar)));
      // Under "My requests", which loads the list again; the page holds no draft any more, so nothing asks.
      context.go(ApplicationRoutesConstants.accessRequests);
    }
  }

  static void _leave(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(ApplicationRoutesConstants.accessRequests);
    }
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state});

  final AccessRequestFormReady state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bloc = context.read<AccessRequestFormBloc>();
    final sending = state.submission is SubmissionSending;
    final submission = state.submission;
    final missing = switch (submission) {
      SubmissionIncomplete(:final missing) => missing,
      SubmissionIdle() || SubmissionSending() || SubmissionRefused() => const <AccessRequestField>{},
    };
    final (refusedField, refusedCode) = switch (submission) {
      SubmissionRefused(:final field, :final errorCode) => (field, errorCode),
      SubmissionIdle() || SubmissionSending() || SubmissionIncomplete() => (null, null),
    };
    final connection = state.connection;
    return ListView(
      key: const ValueKey('access-request-form'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(s.access_requests_form_connection, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final candidate in state.connections)
          _ConnectionTile(
            connection: candidate,
            selected: candidate.id == state.connectionId,
            enabled: !sending,
            onPick: () => bloc.add(AccessRequestFormConnectionPicked(candidate.id)),
          ),
        if (missing.contains(AccessRequestField.connection))
          _FieldError(s.access_requests_form_connection_required, field: 'connection'),
        const SizedBox(height: AppSpacing.xl),
        Text(s.access_requests_form_level, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          key: const ValueKey('access-request-level'),
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: accessLevelRead,
              label: Text(s.access_requests_level_read),
              icon: const Icon(Icons.visibility_outlined),
              enabled: connection == null || connection.canAskFor(accessLevelRead),
            ),
            ButtonSegment(
              value: accessLevelWrite,
              label: Text(s.access_requests_level_write),
              icon: const Icon(Icons.edit_outlined),
              enabled: connection == null || connection.canAskFor(accessLevelWrite),
            ),
          ],
          selected: {?state.level},
          onSelectionChanged: sending
              ? null
              : (picked) {
                  if (picked.isNotEmpty) bloc.add(AccessRequestFormLevelPicked(picked.single));
                },
        ),
        if (connection != null && !connection.hasWriteCredential)
          _Note(s.access_requests_form_level_write_unavailable, field: 'write-unavailable'),
        if (connection != null && connection.access != null && !connection.canAskFor(accessLevelRead))
          _Note(s.access_requests_form_level_read_held, field: 'read-held'),
        if (missing.contains(AccessRequestField.level))
          _FieldError(s.access_requests_form_level_required, field: 'level'),
        if (refusedField == AccessRequestField.level && refusedCode != null)
          _FieldError(refusedCode.resolve(context), field: 'level'),
        const SizedBox(height: AppSpacing.xl),
        _ReasonField(initial: state.reason, enabled: !sending),
        if (missing.contains(AccessRequestField.reason))
          _FieldError(s.access_requests_form_reason_invalid, field: 'reason'),
        if (refusedField == AccessRequestField.reason && refusedCode != null)
          _FieldError(refusedCode.resolve(context), field: 'reason'),
        if (refusedField == null && refusedCode != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _FormRefusal(errorCode: refusedCode, sending: sending),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          key: const ValueKey('access-request-send'),
          label: s.access_requests_form_send,
          fullWidth: true,
          isLoading: sending,
          onPressed: sending ? null : () => bloc.add(const AccessRequestFormSendRequested()),
        ),
      ],
    );
  }
}

/// One connection the user can pick, disabled with the reason when no level of it can be asked for.
class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.connection,
    required this.selected,
    required this.enabled,
    required this.onPick,
  });

  final RequestableConnection connection;
  final bool selected;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final block = connection.blockedBy;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: ValueKey('access-request-connection-${connection.id}'),
          enabled: enabled && block == null,
          selected: selected,
          leading: const Icon(Icons.storage_outlined),
          title: Text(connection.name),
          subtitle: switch (block) {
            ConnectionBlock.pending => Text(s.access_requests_form_connection_pending),
            ConnectionBlock.alreadyGranted => Text(s.access_requests_form_connection_granted),
            null => null,
          },
          trailing: selected ? const Icon(Icons.check_circle) : null,
          onTap: onPick,
        ),
      ),
    );
  }
}

/// The reason field with its 500-character counter. The draft lives in the bloc; this only holds the cursor.
class _ReasonField extends StatefulWidget {
  const _ReasonField({required this.initial, required this.enabled});

  final String initial;
  final bool enabled;

  @override
  State<_ReasonField> createState() => _ReasonFieldState();
}

class _ReasonFieldState extends State<_ReasonField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return TextField(
      key: const ValueKey('access-request-reason'),
      controller: _controller,
      enabled: widget.enabled,
      maxLength: accessRequestReasonMaxLength,
      minLines: 3,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: s.access_requests_form_reason,
        hintText: s.access_requests_form_reason_hint,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        context.read<AccessRequestFormBloc>().add(AccessRequestFormReasonChanged(value));
        UnsavedChangesScope.formChanged(context);
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.field});

  final String text;
  final String field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        key: ValueKey('access-request-note-$field'),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text, {required this.field});

  final String text;
  final String field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('access-request-error-$field'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
      ),
    );
  }
}

/// A refusal that belongs to no field: its text, and what the user can do next. Platform saying that a request is open
/// or the access held leads to "My requests"; any other refusal offers Retry, which sends the draft again.
class _FormRefusal extends StatelessWidget {
  const _FormRefusal({required this.errorCode, required this.sending});

  final AppErrorCode errorCode;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final opensRequests =
        errorCode == AppErrorCode.platformAccessRequestPending ||
        errorCode == AppErrorCode.platformAccessAlreadyGranted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldError(errorCode.resolve(context), field: 'form'),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: opensRequests
              ? TextButton(
                  key: const ValueKey('access-request-open-requests'),
                  onPressed: () => context.go(ApplicationRoutesConstants.accessRequests),
                  child: Text(s.access_requests_title),
                )
              : TextButton(
                  key: const ValueKey('access-request-retry'),
                  onPressed: sending
                      ? null
                      : () => context.read<AccessRequestFormBloc>().add(const AccessRequestFormSendRequested()),
                  child: Text(s.retry),
                ),
        ),
      ],
    );
  }
}
