import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_sections.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// The connections Studio offers the signed-in user, in sections by the operator's group, with a search and an
/// environment filter. It never offers to add a connection: Studio's operator configures them.
///
/// The connections the user starred on this device come first, in a Favorites section, after a Recent strip of the
/// last connections the user opened; without readable favorites the list shows neither and no star.
///
/// Offline it keeps the list it loaded, marked with the time it was loaded, a pull to refresh says the device is
/// offline instead of asking Studio, and the list is asked again once the device is back online.
class ConnectionListPage extends StatefulWidget {
  const ConnectionListPage({super.key});

  @override
  State<ConnectionListPage> createState() => _ConnectionListPageState();
}

class _ConnectionListPageState extends State<ConnectionListPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ConnectionListBloc>().add(const ConnectionListRequested());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Asks Studio again and completes once the answer, or its failure, is on screen, which ends the pull indicator;
  /// offline it says so with the banner's words instead.
  Future<void> _refresh() async {
    if (OfflineStatus.isOfflineOf(context)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.of(context).connectivity_offline)));
      return;
    }
    final bloc = context.read<ConnectionListBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ConnectionListLoaded(:final isRefreshing) => !isRefreshing,
        ConnectionListFailure() => true,
        ConnectionListInitial() || ConnectionListLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const ConnectionListRefreshed());
    await done;
  }

  @override
  Widget build(BuildContext context) {
    return OnReconnect(
      onReconnect: () => context.read<ConnectionListBloc>().add(const ConnectionListRefreshed()),
      child: _buildState(context),
    );
  }

  Widget _buildState(BuildContext context) {
    return BlocConsumer<ConnectionListBloc, ConnectionListState>(
      listenWhen: (previous, current) =>
          previous is ConnectionListLoaded &&
          previous.isRefreshing &&
          current is ConnectionListLoaded &&
          !current.isRefreshing &&
          current.refreshErrorCode != null,
      listener: (context, state) {
        final errorCode = (state as ConnectionListLoaded).refreshErrorCode!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCode.resolve(context))));
      },
      builder: (context, state) => switch (state) {
        ConnectionListInitial() || ConnectionListLoading() => const Center(child: CircularProgressIndicator()),
        ConnectionListLoaded() => _buildLoaded(context, state),
        ConnectionListFailure(:final errorCode) => RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: AppErrorState(
                  title: S.of(context).connection_list_load_failed,
                  description: errorCode.resolve(context),
                  retryLabel: S.of(context).refresh,
                  onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
                ),
              ),
            ),
          ),
        ),
      },
    );
  }

  Widget _buildLoaded(BuildContext context, ConnectionListLoaded state) {
    final l10n = S.of(context);
    final staleMarker = OfflineStaleMarker(loadedAt: state.loadedAt);
    if (state.connections.isEmpty) {
      return Column(
        children: [
          staleMarker,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const ValueKey('connection-sections'),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [AppEmptyState(icon: Icons.storage_outlined, title: l10n.connection_list_empty)],
              ),
            ),
          ),
        ],
      );
    }
    // A search shows every match, so it opens the collapsed sections without changing what the device remembers.
    final searching = state.isSearching;
    return Column(
      children: [
        staleMarker,
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: _SearchField(controller: _search),
        ),
        _EnvironmentChips(environments: state.environments, selected: state.environment),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: BlocBuilder<FavoriteConnectionsBloc, FavoriteConnectionsState>(
              builder: (context, favoritesState) {
                final favorites = switch (favoritesState) {
                  FavoriteConnectionsReady(:final favorites) => favorites,
                  FavoriteConnectionsNone() || FavoriteConnectionsLoading() || FavoriteConnectionsUnavailable() => null,
                };
                final split = withFavorites(state.sections, favorites?.starred ?? const {});
                // The strip is a shortcut to the whole list, so a search or a filter hides it.
                final recent = favorites == null || searching || state.environment != null
                    ? const <StudioConnection>[]
                    : recentConnections(state.connections, favorites.recent);
                return BlocBuilder<CollapsedSectionsCubit, CollapsedSectionsState>(
                  builder: (context, collapsed) {
                    bool isOpen(String key) => searching || !collapsed.isCollapsed(key);
                    Widget sectionHeader(String key, String title, int count) => _SectionHeader(
                      key: ValueKey('connection-section-$key'),
                      title: title,
                      count: count,
                      collapsed: !isOpen(key),
                      onTap: searching ? null : () => context.read<CollapsedSectionsCubit>().toggle(key),
                    );
                    Widget connectionRow(StudioConnection connection) => _ConnectionRow(
                      key: ValueKey('connection-row-${connection.id}'),
                      connection: connection,
                      starred: favorites?.starred.contains(connection.id),
                    );
                    return ListView(
                      key: const ValueKey('connection-sections'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      children: [
                        if (recent.isNotEmpty) _RecentStrip(connections: recent),
                        if (split.favorites.isEmpty && split.sections.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              l10n.connection_search_no_match,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        if (split.favorites.isNotEmpty) ...[
                          sectionHeader(_favoritesKey, l10n.connection_favorites, split.favorites.length),
                          if (isOpen(_favoritesKey)) ...split.favorites.map(connectionRow),
                        ],
                        for (final section in split.sections) ...[
                          sectionHeader(
                            section.key,
                            section.group ?? l10n.connection_group_other,
                            section.connections.length,
                          ),
                          if (isOpen(section.key)) ...section.connections.map(connectionRow),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Names the Favorites section in the stored collapsed state; a group key always starts with `group:`.
const _favoritesKey = 'favorites';

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.connection_search_hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.connection_search_clear,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    context.read<ConnectionListBloc>().add(const ConnectionListSearchChanged(''));
                  },
                ),
        ),
        onChanged: (text) => context.read<ConnectionListBloc>().add(ConnectionListSearchChanged(text)),
      ),
    );
  }
}

class _EnvironmentChips extends StatelessWidget {
  const _EnvironmentChips({required this.environments, required this.selected});

  final List<String> environments;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    if (environments.isEmpty) return const SizedBox(height: AppSpacing.sm);
    final l10n = S.of(context);
    return Semantics(
      container: true,
      label: l10n.connection_environment_filter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          spacing: AppSpacing.sm,
          children: [
            for (final environment in environments)
              FilterChip(
                label: Text(StudioEnvironment.label(environment) ?? l10n.connection_environment_other),
                selected: environment == selected,
                onSelected: (isSelected) => context.read<ConnectionListBloc>().add(
                  ConnectionListEnvironmentFilterChanged(isSelected ? environment : null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool collapsed;

  /// Null while a search is active: the section then stays open and the header does not toggle it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      expanded: !collapsed,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                Icon(collapsed ? Icons.chevron_right : Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text('$count', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({super.key, required this.connection, required this.starred});

  final StudioConnection connection;

  /// Whether the user starred the connection, or null when the list shows no favorites and so no star.
  final bool? starred;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final environment = connection.environment;
    final strip = EnvironmentAccent.resolve(
      environment: environment,
      color: connection.color,
      scheme: theme.colorScheme,
    ).strip;
    final secondary = connection.database ?? connection.host;
    final showsBadge = EnvironmentBadge.showsFor(environment);
    return InkWell(
      onTap: () => _open(context, connection),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: strip ?? Colors.transparent, width: 4)),
        ),
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, starred == null ? AppSpacing.lg : 0, AppSpacing.sm),
        child: Row(
          spacing: AppSpacing.md,
          children: [
            Icon(engineIcon(connection.type), semanticLabel: connection.type, color: theme.colorScheme.primary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(connection.name, style: theme.textTheme.bodyLarge),
                  if (secondary != null)
                    Text(
                      secondary,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (showsBadge || connection.readOnlyForUser)
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (showsBadge) EnvironmentBadge(environment: environment!, color: connection.color),
                        if (connection.readOnlyForUser) const ReadOnlyChip(),
                      ],
                    ),
                ],
              ),
            ),
            if (starred != null)
              _StarButton(key: ValueKey('connection-star-${connection.id}'), connection: connection, starred: starred!),
          ],
        ),
      ),
    );
  }
}

/// Stars the connection on this device, or removes its star.
class _StarButton extends StatelessWidget {
  const _StarButton({super.key, required this.connection, required this.starred});

  final StudioConnection connection;
  final bool starred;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return IconButton(
      tooltip: starred ? l10n.connection_unstar : l10n.connection_star,
      isSelected: starred,
      icon: const Icon(Icons.star_border),
      selectedIcon: const Icon(Icons.star),
      onPressed: () => context.read<FavoriteConnectionsBloc>().add(FavoriteConnectionStarToggled(connection.id)),
    );
  }
}

/// The last connections the user opened, the one opened last first, each a shortcut that opens it like its row.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.connections});

  final List<StudioConnection> connections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('connection-recent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Text(
            S.of(context).connection_recent,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              for (final connection in connections)
                ActionChip(
                  key: ValueKey('connection-recent-${connection.id}'),
                  avatar: Icon(engineIcon(connection.type), semanticLabel: connection.type),
                  label: Text(connection.name),
                  onPressed: () => _open(context, connection),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the connection: it becomes the first of the recent ones, and, until the active connection (#26) lands, the
/// sheet shows what the app knows about it.
void _open(BuildContext context, StudioConnection connection) {
  context.read<FavoriteConnectionsBloc>().add(FavoriteConnectionOpened(connection.id));
  _showDetails(context, connection);
}

void _showDetails(BuildContext context, StudioConnection connection) {
  final l10n = S.of(context);
  final environment = connection.environment;
  final target = _target(connection);
  final favorites = context.read<FavoriteConnectionsBloc>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // The sheet's route sits above the page, so it gets the page's favorites itself.
    builder: (context) => BlocProvider.value(
      value: favorites,
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            ListTile(
              leading: Icon(engineIcon(connection.type), semanticLabel: connection.type),
              title: Text(connection.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: connection.readOnlyForUser
                  ? const Align(alignment: AlignmentDirectional.centerStart, child: ReadOnlyChip())
                  : null,
              trailing: BlocBuilder<FavoriteConnectionsBloc, FavoriteConnectionsState>(
                builder: (context, state) => switch (state) {
                  FavoriteConnectionsReady(:final favorites) => _StarButton(
                    key: const ValueKey('connection-detail-star'),
                    connection: connection,
                    starred: favorites.starred.contains(connection.id),
                  ),
                  FavoriteConnectionsNone() ||
                  FavoriteConnectionsLoading() ||
                  FavoriteConnectionsUnavailable() => const SizedBox.shrink(),
                },
              ),
            ),
            _Detail(label: l10n.connection_type, value: connection.type),
            if (environment != null)
              _Detail(
                label: l10n.connection_environment,
                value: StudioEnvironment.label(environment) ?? l10n.connection_environment_other,
              ),
            if (connection.group != null) _Detail(label: l10n.connection_group, value: connection.group!),
            if (target.isNotEmpty) _Detail(label: l10n.connection_target, value: target),
          ],
        ),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(dense: true, title: Text(label), subtitle: Text(value));
}

/// `host:port/database`, or whichever of them Studio sent.
String _target(StudioConnection c) {
  final address = [if (c.host != null) c.host!, if (c.port != null) '${c.port}'].join(':');
  return [if (address.isNotEmpty) address, if (c.database != null) c.database!].join('/');
}
