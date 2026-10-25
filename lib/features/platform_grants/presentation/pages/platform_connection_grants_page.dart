import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_list_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/revoke_grant_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_target.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/features/platform_grants/navigation/grant_editor_args.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/revoke_grant_dialog.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/components/app_status_badge.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

/// Who holds a grant on one connection in Platform mode, in Platform's order (by username), expired grants flagged,
/// and the removal of one person's access.
///
/// The connection comes from the list that opened the page; Platform has no route that reads one connection.
class PlatformConnectionGrantsPage extends StatelessWidget {
  const PlatformConnectionGrantsPage({super.key, required this.connection});

  final PlatformConnection connection;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RevokeGrantBloc, RevokeGrantState>(
      listener: _onRevoke,
      child: Column(
        children: [
          _ConnectionHeader(connection: connection),
          _AddGrantButton(connection: connection),
          Expanded(
            child: BlocBuilder<GrantListBloc, GrantListState>(
              builder: (context, state) => switch (state) {
                GrantListInitial() || GrantListLoading() => const _Skeleton(),
                GrantListLoaded(grants: [], :final refreshError) => Column(
                  children: [
                    if (refreshError != null) _RefreshBanner(errorCode: refreshError),
                    Expanded(
                      child: _Refreshable(
                        child: _centered(
                          AppEmptyState(
                            icon: Icons.group_off_outlined,
                            title: S.of(context).platform_grants_empty_title,
                            description: S.of(context).platform_grants_empty_description,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                final GrantListLoaded loaded => _LoadedList(connection: connection, state: loaded),
                GrantListFailure(errorCode: AppErrorCode.platformNotFound) => _centered(
                  AppErrorState(
                    icon: Icons.link_off,
                    title: S.of(context).platform_grants_connection_gone_title,
                    description: S.of(context).platform_grants_connection_gone_description,
                    retryLabel: S.of(context).platform_grants_back_to_connections,
                    onRetry: () => context.go(ApplicationRoutesConstants.platformConnections),
                  ),
                ),
                GrantListFailure(:final errorCode) => _Refreshable(
                  child: _centered(
                    AppErrorState(
                      title: S.of(context).platform_grants_load_failed,
                      description: errorCode.resolve(context),
                      retryLabel: S.of(context).retry,
                      onRetry: () => context.read<GrantListBloc>().add(GrantListLoadRequested(connection.id)),
                    ),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onRevoke(BuildContext context, RevokeGrantState state) {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case RevokeGrantSucceeded():
        context.read<GrantListBloc>().add(const GrantListRefreshRequested());
        messenger.showSnackBar(SnackBar(content: Text(s.platform_grants_removed)));
      case RevokeGrantAlreadyRemoved():
        context.read<GrantListBloc>().add(const GrantListRefreshRequested());
        messenger.showSnackBar(SnackBar(content: Text(s.platform_grants_already_removed)));
      case RevokeGrantFailed(:final errorCode):
        messenger.showSnackBar(SnackBar(content: Text(errorCode.resolve(context))));
      case RevokeGrantIdle() || RevokeGrantInProgress():
        break;
    }
  }

  /// [child] centred on a page that can scroll, so a pull reaches a [RefreshIndicator] around it.
  static Widget _centered(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: child),
        ),
      ),
    ),
  );
}

/// The name, engine and status of the connection whose grants the page lists.
class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.connection});

  final PlatformConnection connection;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // An unknown status is shown as Platform sent it.
    final (statusLabel, statusColor) = connection.isActive
        ? (s.active, context.semanticColors.success)
        : connection.isInactive
        ? (s.inactive, colorScheme.error)
        : (connection.status, colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Icon(engineIcon(connection.engine), color: colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(connection.name, style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(connection.engine, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          AppStatusBadge(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

/// "Add access", enabled only while the grants are loaded, so the picker knows who already holds one.
class _AddGrantButton extends StatelessWidget {
  const _AddGrantButton({required this.connection});

  final PlatformConnection connection;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: BlocSelector<GrantListBloc, GrantListState, List<PlatformGrant>?>(
        selector: (state) => state is GrantListLoaded ? state.grants : null,
        builder: (context, grants) => FilledButton.tonalIcon(
          key: const ValueKey('platform-grants-add'),
          onPressed: grants == null ? null : () => openGrantEditor(context, connection: connection, grants: grants),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(S.of(context).platform_grants_add),
        ),
      ),
    ),
  );
}

/// Opens the grant editor of [connection], on [grant] when given, else on the directory picker, with the current
/// [grants] as the holders; the grant list is read again whenever a save may have changed a grant.
Future<void> openGrantEditor(
  BuildContext context, {
  required PlatformConnection connection,
  required List<PlatformGrant> grants,
  PlatformGrant? grant,
}) async {
  final grantList = context.read<GrantListBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final saved = S.of(context).platform_grants_editor_saved;
  final result = await context.push<bool>(
    GrantEditorArgs.locationOf(connection.id),
    extra: GrantEditorArgs(
      target: GrantTarget.fromStatus(
        connectionId: connection.id,
        connectionName: connection.name,
        hasWriteCredential: connection.hasWriteCredential,
        status: connection.status,
      ),
      grant: grant,
      holders: {for (final held in grants) held.subject: held},
      onGrantMayHaveChanged: () {
        if (!grantList.isClosed) grantList.add(const GrantListRefreshRequested());
      },
    ),
  );
  if (result == true) messenger.showSnackBar(SnackBar(content: Text(saved)));
}

/// [child] under a [RefreshIndicator] whose pull asks Platform again and waits for the answer.
class _Refreshable extends StatelessWidget {
  const _Refreshable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () {
      final bloc = context.read<GrantListBloc>()..add(const GrantListRefreshRequested());
      return bloc.stream.firstWhere(
        (state) => switch (state) {
          GrantListLoaded(:final isRefreshing) => !isRefreshing,
          GrantListFailure() => true,
          GrantListInitial() || GrantListLoading() => false,
        },
      );
    },
    child: child,
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSkeleton.listTile(),
        ),
    ],
  );
}

class _LoadedList extends StatelessWidget {
  const _LoadedList({required this.connection, required this.state});

  final PlatformConnection connection;
  final GrantListLoaded state;

  @override
  Widget build(BuildContext context) {
    final refreshError = state.refreshError;
    final now = clock.now();
    return Column(
      children: [
        if (refreshError != null) _RefreshBanner(errorCode: refreshError),
        Expanded(
          child: _Refreshable(
            child: BlocSelector<RevokeGrantBloc, RevokeGrantState, bool>(
              selector: (state) => state is RevokeGrantInProgress,
              builder: (context, revoking) => ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: state.grants.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => _GrantRow(
                  connection: connection,
                  grant: state.grants[index],
                  grants: state.grants,
                  now: now,
                  actionsEnabled: !revoking,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Why the last refresh failed, above the grants it kept, with a retry.
class _RefreshBanner extends StatelessWidget {
  const _RefreshBanner({required this.errorCode});

  final AppErrorCode errorCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).platform_grants_refresh_failed,
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      errorCode.resolve(context),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.read<GrantListBloc>().add(const GrantListRefreshRequested()),
                child: Text(S.of(context).retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The entries of a grant's actions menu.
enum _GrantAction { edit, remove }

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.connection,
    required this.grant,
    required this.grants,
    required this.now,
    required this.actionsEnabled,
  });

  final PlatformConnection connection;
  final PlatformGrant grant;

  /// Every grant listed, the holders the editor is told about.
  final List<PlatformGrant> grants;
  final DateTime now;

  /// False while a revoke runs, since a second one would be dropped unseen.
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final expiresAt = grant.expiresAt;
    final expired = grant.isExpiredAt(now);
    final granter = grant.grantedBy.name ?? grant.grantedBy.email;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grant.subjectUsername, style: textTheme.titleSmall),
                if (grant.subjectEmail case final email?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(email, style: secondary),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppStatusBadge(label: levelLabel(s, grant.level), color: colorScheme.primary),
                    if (expiresAt == null)
                      Text(s.platform_grants_no_expiry, style: secondary)
                    else if (expired)
                      Row(
                        key: ValueKey('platform-grant-expired-${grant.subjectUsername}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, size: 16, color: colorScheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            s.platform_grants_expired(formatGrantDate(context, expiresAt)),
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                          ),
                        ],
                      )
                    else
                      Text(s.platform_grants_expires(formatGrantDate(context, expiresAt)), style: secondary),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.platform_grants_granted_by(granter, formatGrantDate(context, grant.grantedAt)),
                  style: secondary,
                ),
              ],
            ),
          ),
          PopupMenuButton<_GrantAction>(
            key: ValueKey('platform-grant-actions-${grant.subjectUsername}'),
            enabled: actionsEnabled,
            tooltip: s.platform_grants_actions,
            onSelected: (action) => switch (action) {
              _GrantAction.edit => openGrantEditor(context, connection: connection, grants: grants, grant: grant),
              _GrantAction.remove => _confirmRemove(context),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _GrantAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(s.platform_grants_edit),
                ),
              ),
              PopupMenuItem(
                value: _GrantAction.remove,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_remove_outlined, color: colorScheme.error),
                  title: Text(s.platform_grants_remove_access),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showRevokeGrantDialog(context, connection: connection, grant: grant);
    if (confirmed != true || !context.mounted) return;
    context.read<RevokeGrantBloc>().add(RevokeGrantConfirmed(connectionId: connection.id, grantId: grant.id));
  }
}

/// The chip label of a grant level: "Read", "Write", or the raw value of an unknown level.
String levelLabel(S s, String level) => switch (level) {
  'read' => s.platform_grants_level_read,
  'write' => s.platform_grants_level_write,
  _ => level,
};

/// [value] in the local time, in the language of the app.
String formatGrantDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(value.toLocal());
