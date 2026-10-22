import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_sections.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_details_sheet.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_star_button.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:libredb_mobile/shared/widgets/governance_status.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// The connections Studio offers the signed-in user, in sections by the operator's group, with a search and an
/// environment filter. It never offers to add a connection: Studio's operator configures them.
///
/// The connections the user starred on this device come first, in a Favorites section, after a Recent strip of the
/// last connections the user opened; without readable favorites the list shows neither and no star.
///
/// Offline it keeps the list it loaded, marked with the time it was loaded, a pull to refresh says the device is
/// offline instead of asking Studio, and the list is asked again once the device is back online.
///
/// While it is on screen with the app in the foreground and the device online, the list follows grant changes by
/// itself ([ConnectionListBloc]), and the policy is asked again with it. A governance outage keeps the rows loaded
/// before greyed under the outage notice, or covers the page with it on a cold start, and never reads as an empty list.
class ConnectionListPage extends StatefulWidget {
  const ConnectionListPage({super.key});

  @override
  State<ConnectionListPage> createState() => _ConnectionListPageState();
}

class _ConnectionListPageState extends State<ConnectionListPage> {
  final _search = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  /// Whether the app is in the foreground; an inactive app, such as one under the notification shade, still is.
  bool _foreground = true;

  /// Whether this page's tickers run: they stop while a page covers it, such as Studio's unreachable page.
  bool _visible = true;
  bool _online = true;

  /// The last foreground state sent to the bloc.
  bool? _sentActive;

  /// Whether the page shows a governance outage it has reported.
  bool _inOutage = false;

  /// Whether a list Studio answered has reported governance as answering since the page opened. The first one does
  /// even without an outage of its own, because a page closed during an outage, by a tab switch for example, leaves
  /// the outage in the app's status.
  bool _answerReported = false;

  /// Whether a list arrived since the page opened; the shell asks for the policy on its own before the first one.
  bool _listShown = false;

  @override
  void initState() {
    super.initState();
    context.read<ConnectionListBloc>().add(const ConnectionListRequested());
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final wasForeground = _foreground;
        _foreground = _isForeground(state);
        // Back from the background, the grants may have changed meanwhile.
        _sendActive(askNow: !wasForeground && _foreground);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _online = !OfflineStatus.isOfflineOf(context);
    _sendActive();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _search.dispose();
    super.dispose();
  }

  static bool _isForeground(AppLifecycleState? state) => switch (state) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
  };

  void _sendActive({bool askNow = false}) {
    final active = _foreground && _visible && _online;
    if (active == _sentActive) return;
    _sentActive = active;
    context.read<ConnectionListBloc>().add(ConnectionListAutoRefreshChanged(active: active, askNow: askNow));
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
        ConnectionListUnavailable(:final isRetrying) => !isRetrying,
        ConnectionListFailure() => true,
        ConnectionListInitial() || ConnectionListLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const ConnectionListRefreshed());
    await done;
  }

  /// Reports where a governance outage starts and ends, for the wording the notice shows.
  void _followOutage(BuildContext context, ConnectionListState state) {
    final status = GovernanceStatus.of(context);
    switch (state) {
      case ConnectionListUnavailable():
        if (_inOutage) return;
        _inOutage = true;
        status.reportOutage();
      case ConnectionListLoaded(:final refreshError):
        // A failed refresh never reached governance, so it says nothing about it.
        if (refreshError != null || (!_inOutage && _answerReported)) return;
        _inOutage = false;
        _answerReported = true;
        status.reportRecovered();
      case ConnectionListFailure(:final errorCode):
        // An offline failure never reached Studio, so it says nothing about governance.
        if (!_inOutage || errorCode == AppErrorCode.networkOffline) return;
        _inOutage = false;
        status.reportRecovered();
      case ConnectionListInitial() || ConnectionListLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnReconnect(
      onReconnect: () => context.read<ConnectionListBloc>().add(const ConnectionListRefreshed()),
      child: MultiBlocListener(
        listeners: [
          BlocListener<ConnectionListBloc, ConnectionListState>(listener: _followOutage),
          BlocListener<ConnectionListBloc, ConnectionListState>(
            listenWhen: (previous, current) =>
                current is ConnectionListLoaded &&
                (previous is! ConnectionListLoaded || previous.loadedAt != current.loadedAt),
            listener: (context, state) {
              final policy = context.read<ConnectionPolicyCubit>();
              final first = !_listShown;
              _listShown = true;
              if (first && policy.state is ConnectionPolicyLoaded) return;
              if (first && policy.state is ConnectionPolicyLoading) return;
              policy.refresh();
            },
          ),
        ],
        child: Column(
          children: [
            const _StatementCaptureNote(),
            Expanded(child: _buildState(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildState(BuildContext context) {
    return BlocBuilder<ConnectionListBloc, ConnectionListState>(
      builder: (context, state) => switch (state) {
        ConnectionListInitial() || ConnectionListLoading() => const Center(child: CircularProgressIndicator()),
        ConnectionListLoaded() => _buildLoaded(context, state),
        ConnectionListUnavailable(:final previous?) => _buildLoaded(context, previous, unavailable: true),
        ConnectionListUnavailable() => _buildFullScreen(
          context,
          child: Column(
            key: const ValueKey('connection-list-unavailable'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).connection_list_unavailable,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              GovernanceStatus.of(context).noticeBuilder(context),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(S.of(context).retry),
              ),
            ],
          ),
        ),
        ConnectionListFailure(:final errorCode) => _buildFullScreen(
          context,
          child: AppErrorState(
            title: S.of(context).connection_list_load_failed,
            description: errorCode.resolve(context),
            retryLabel: S.of(context).refresh,
            onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
          ),
        ),
      },
    );
  }

  /// [child] centred on a page that a pull refreshes.
  Widget _buildFullScreen(BuildContext context, {required Widget child}) => RefreshIndicator(
    onRefresh: _refresh,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: child),
          ),
        ),
      ),
    ),
  );

  /// The list in [state]; [unavailable] greys it under the governance outage notice and disables its rows.
  Widget _buildLoaded(BuildContext context, ConnectionListLoaded state, {bool unavailable = false}) {
    final l10n = S.of(context);
    final refreshError = state.refreshError;
    final header = [
      OfflineStaleMarker(loadedAt: state.loadedAt),
      if (unavailable)
        Padding(
          key: const ValueKey('connection-list-outage'),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: _OutageBanner(child: GovernanceStatus.of(context).noticeBuilder(context)),
        )
      else if (refreshError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: StudioErrorBanner(
            error: refreshError,
            onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRefreshed()),
          ),
        ),
    ];
    if (state.connections.isEmpty) {
      return Column(
        children: [
          ...header,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const ValueKey('connection-sections'),
                physics: const AlwaysScrollableScrollPhysics(),
                // An outage says nothing about what was granted, so it shows no empty state: the notice says why.
                children: [if (!unavailable) const _EmptyList()],
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
        ...header,
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
                      enabled: !unavailable,
                    );
                    return ListView(
                      key: const ValueKey('connection-sections'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      children: [
                        if (recent.isNotEmpty) _RecentStrip(connections: recent, enabled: !unavailable),
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

/// "Statements you run are recorded in full in this server's query log." under the app bar while governance records
/// statements in full, as Studio's web client says it; nothing otherwise.
class _StatementCaptureNote extends StatelessWidget {
  const _StatementCaptureNote();

  @override
  Widget build(BuildContext context) {
    final recordsInFull = context.select<ConnectionPolicyCubit, bool>(
      (cubit) => switch (cubit.state) {
        ConnectionPolicyLoaded(:final policy) => policy.statementCapture == ConnectionPolicy.statementCaptureFull,
        ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
      },
    );
    if (!recordsInFull) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('connection-statement-capture-note'),
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.policy_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              S.of(context).connection_statement_capture_full,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty list: under governance the user has no grants, which an administrator gives, as Studio's web client says;
/// otherwise Studio offers no connection. Until the policy is known it says the latter, which holds either way.
class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final governed = context.select<ConnectionPolicyCubit, bool>(
      (cubit) => switch (cubit.state) {
        ConnectionPolicyLoaded(:final policy) => policy.governance,
        ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
      },
    );
    final l10n = S.of(context);
    return AppEmptyState(
      icon: Icons.storage_outlined,
      title: governed ? l10n.connection_list_empty_governed : l10n.connection_list_empty,
    );
  }
}

/// The governance outage notice above the greyed rows it keeps.
class _OutageBanner extends StatelessWidget {
  const _OutageBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
    ),
  );
}

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
  const _ConnectionRow({super.key, required this.connection, required this.starred, this.enabled = true});

  final StudioConnection connection;

  /// Whether the user starred the connection, or null when the list shows no favorites and so no star.
  final bool? starred;

  /// False while governance is unavailable: the row shows greyed and neither opens nor stars.
  final bool enabled;

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
    // Until the active connection (#26) lands, a tap shows the details too.
    final row = InkWell(
      onTap: enabled ? () => _open(context, connection) : null,
      onLongPress: enabled ? () => showConnectionDetailsSheet(context, connection) : null,
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
              ConnectionStarButton(
                key: ValueKey('connection-star-${connection.id}'),
                connection: connection,
                starred: starred!,
              ),
          ],
        ),
      ),
    );
    return enabled ? row : IgnorePointer(child: Opacity(opacity: 0.38, child: row));
  }
}

/// The last connections the user opened, the one opened last first, each a shortcut that opens it like its row.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.connections, required this.enabled});

  final List<StudioConnection> connections;

  /// False while governance is unavailable: the shortcuts show greyed and do not open.
  final bool enabled;

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
                  onPressed: enabled ? () => _open(context, connection) : null,
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
  showConnectionDetailsSheet(context, connection);
}
