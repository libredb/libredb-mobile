import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_active_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_list_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/widgets/connection_active_dialog.dart';
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
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';

/// Every connection of the install in Platform mode, active and inactive, newest first, with a local search.
///
/// A row's menu disables an active connection or enables an inactive one after a confirmation, and the row then shows
/// the status Platform answered. Connections are still added, edited and deleted only in the Platform web console, so
/// the page offers none of these. A tap on a row, an inactive one too, opens the connection's grants.
class PlatformConnectionListPage extends StatelessWidget {
  const PlatformConnectionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlatformConnectionActiveBloc, PlatformConnectionActiveState>(
      listener: _onActiveChange,
      child: _buildList(),
    );
  }

  Widget _buildList() {
    return BlocBuilder<PlatformConnectionListBloc, PlatformConnectionListState>(
      builder: (context, state) => switch (state) {
        PlatformConnectionListInitial() || PlatformConnectionListLoading() => const _Skeleton(),
        PlatformConnectionListLoaded(connections: [], :final refreshError) => Column(
          children: [
            if (refreshError != null) _RefreshBanner(errorCode: refreshError),
            Expanded(
              child: _Refreshable(
                child: _centered(
                  AppEmptyState(
                    icon: Icons.storage_outlined,
                    title: S.of(context).platform_connections_empty_title,
                    description: S.of(context).platform_connections_empty_description,
                  ),
                ),
              ),
            ),
          ],
        ),
        final PlatformConnectionListLoaded loaded => _LoadedList(state: loaded),
        PlatformConnectionListFailure(:final errorCode) => _Refreshable(
          child: _centered(
            AppErrorState(
              title: S.of(context).platform_connections_load_failed,
              description: errorCode.resolve(context),
              retryLabel: S.of(context).retry,
              onRetry: () => context.read<PlatformConnectionListBloc>().add(const PlatformConnectionListRefreshed()),
            ),
          ),
        ),
      },
    );
  }

  void _onActiveChange(BuildContext context, PlatformConnectionActiveState state) {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case PlatformConnectionActiveSucceeded(:final connection):
        context.read<PlatformConnectionListBloc>().add(PlatformConnectionReplaced(connection));
        // Named by the status Platform answered, which another admin may have set meanwhile.
        final text = connection.isActive
            ? s.platform_connections_active_enabled
            : s.platform_connections_active_disabled;
        messenger.showSnackBar(SnackBar(content: Text(text)));
      case PlatformConnectionActiveGone():
        context.read<PlatformConnectionListBloc>().add(const PlatformConnectionListRefreshed());
        messenger.showSnackBar(SnackBar(content: Text(s.platform_connections_active_gone)));
      case PlatformConnectionActiveFailed(errorCode: AppErrorCode.platformLicenseUserSeats):
        showConnectionUserSeatsDialog(context);
      case PlatformConnectionActiveFailed(:final errorCode):
        messenger.showSnackBar(SnackBar(content: Text(errorCode.resolve(context))));
      case PlatformConnectionActiveIdle() || PlatformConnectionActiveInProgress():
        break;
    }
  }

  /// [child] centred on a page that a pull refreshes.
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

/// [child] under a [RefreshIndicator] whose pull asks Platform again and waits for the answer.
class _Refreshable extends StatelessWidget {
  const _Refreshable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () {
      final bloc = context.read<PlatformConnectionListBloc>();
      // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
      final done = bloc.stream.firstWhere(
        (state) => switch (state) {
          PlatformConnectionListLoaded(:final isRefreshing) => !isRefreshing,
          PlatformConnectionListFailure() => true,
          PlatformConnectionListInitial() || PlatformConnectionListLoading() => false,
        },
        orElse: () => bloc.state,
      );
      bloc.add(const PlatformConnectionListRefreshed());
      return done;
    },
    child: child,
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('platform-connections-skeleton'),
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      for (var i = 0; i < 6; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSkeleton.listTile(),
        ),
    ],
  );
}

class _LoadedList extends StatelessWidget {
  const _LoadedList({required this.state});

  final PlatformConnectionListLoaded state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final visible = state.visible;
    final refreshError = state.refreshError;
    return Column(
      children: [
        LocalFilterField(
          hintText: s.platform_connections_filter_hint,
          onChanged: (query) =>
              context.read<PlatformConnectionListBloc>().add(PlatformConnectionListSearchChanged(query)),
        ),
        if (refreshError != null) _RefreshBanner(errorCode: refreshError),
        Expanded(
          child: _Refreshable(
            child: visible.isEmpty
                ? PlatformConnectionListPage._centered(
                    AppEmptyState(
                      icon: Icons.search_off,
                      title: s.platform_connections_search_empty_title,
                      description: s.platform_connections_search_empty_description,
                    ),
                  )
                : BlocSelector<PlatformConnectionActiveBloc, PlatformConnectionActiveState, String?>(
                    selector: (state) => switch (state) {
                      PlatformConnectionActiveInProgress(:final id) => id,
                      _ => null,
                    },
                    builder: (context, busyId) => ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) => _ConnectionRow(connection: visible[index], busyId: busyId),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Why the last refresh failed, above the list it kept (an empty install's too), with a retry.
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
          key: const ValueKey('platform-connections-refresh-error'),
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
                      S.of(context).platform_connections_refresh_failed,
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
                onPressed: () =>
                    context.read<PlatformConnectionListBloc>().add(const PlatformConnectionListRefreshed()),
                child: Text(S.of(context).retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ConnectionAction { toggleActive }

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.connection, required this.busyId});

  final PlatformConnection connection;

  /// The connection whose enabling or disabling is out, which disables every row's menu; null when none is.
  final String? busyId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (statusLabel, statusColor) = connection.isActive
        ? (s.active, context.semanticColors.success)
        : connection.isInactive
        ? (s.inactive, colorScheme.error)
        : (s.platform_connections_status_unknown, colorScheme.onSurfaceVariant);
    return AppCard(
      key: ValueKey('platform-connection-${connection.id}'),
      onTap: () => context.push(
        ApplicationRoutesConstants.platformConnectionGrants.replaceFirst(':id', Uri.encodeComponent(connection.id)),
        extra: connection,
      ),
      child: Row(
        children: [
          Icon(engineIcon(connection.engine), semanticLabel: connection.engine, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(connection.name, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(connection.engine, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppStatusBadge(label: statusLabel, color: statusColor),
                    if (!connection.hasWriteCredential)
                      Semantics(
                        label: s.platform_connections_read_grants_only_semantics,
                        excludeSemantics: true,
                        child: AppStatusBadge(
                          label: s.platform_connections_read_grants_only,
                          color: colorScheme.tertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (busyId == connection.id)
            const SizedBox.square(
              dimension: 48,
              child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          // A status the app does not know gets no menu: it cannot say what a change would do.
          else if (connection.isActive || connection.isInactive)
            PopupMenuButton<_ConnectionAction>(
              key: ValueKey('platform-connection-actions-${connection.id}'),
              enabled: busyId == null,
              tooltip: s.platform_connections_active_actions,
              onSelected: (action) => switch (action) {
                _ConnectionAction.toggleActive => _confirmToggle(context),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _ConnectionAction.toggleActive,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: connection.isActive
                        ? Icon(Icons.block, color: colorScheme.error)
                        : const Icon(Icons.check_circle_outline),
                    title: Text(
                      connection.isActive
                          ? s.platform_connections_active_disable
                          : s.platform_connections_active_enable,
                    ),
                  ),
                ),
              ],
            ),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Future<void> _confirmToggle(BuildContext context) async {
    final confirmed = await showConnectionActiveDialog(context, connection: connection);
    if (confirmed != true || !context.mounted) return;
    context.read<PlatformConnectionActiveBloc>().add(
      PlatformConnectionActiveRequested(connection.id, active: connection.isInactive),
    );
  }
}
