import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_list_bloc.dart';
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
/// The list is read only: connections are added, edited and deleted in the Platform web console, and enabling or
/// disabling one comes in a later milestone, so the page offers none of these. A tap on a row, an inactive one too,
/// opens the connection's grants.
class PlatformConnectionListPage extends StatelessWidget {
  const PlatformConnectionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformConnectionListBloc, PlatformConnectionListState>(
      builder: (context, state) => switch (state) {
        PlatformConnectionListInitial() || PlatformConnectionListLoading() => const _Skeleton(),
        PlatformConnectionListLoaded(connections: []) => _Refreshable(
          child: _centered(
            AppEmptyState(
              icon: Icons.storage_outlined,
              title: S.of(context).platform_connections_empty_title,
              description: S.of(context).platform_connections_empty_description,
            ),
          ),
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
      final bloc = context.read<PlatformConnectionListBloc>()..add(const PlatformConnectionListRefreshed());
      return bloc.stream.firstWhere(
        (state) => switch (state) {
          PlatformConnectionListLoaded(:final isRefreshing) => !isRefreshing,
          PlatformConnectionListFailure() => true,
          PlatformConnectionListInitial() || PlatformConnectionListLoading() => false,
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
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => _ConnectionRow(connection: visible[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Why the last refresh failed, above the list it kept, with a retry.
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

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.connection});

  final PlatformConnection connection;

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
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
