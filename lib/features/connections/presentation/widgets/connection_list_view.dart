import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_sections.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_star_button.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// The loaded connection list in sections by the operator's group, with the search and the environment filter, as
/// the connection list page and the connection switcher show it. The connections the user starred on this device come
/// first, in a Favorites section; without readable favorites the list shows no Favorites section and no star.
///
/// Reads [ConnectionListBloc], [CollapsedSectionsCubit] and [FavoriteConnectionsBloc] from the context.
class ConnectionListView extends StatelessWidget {
  const ConnectionListView({
    super.key,
    required this.state,
    required this.search,
    required this.onOpen,
    this.onLongPress,
    this.activeId,
    this.onRefresh,
    this.showRecent = false,
    this.enabled = true,
  });

  final ConnectionListLoaded state;

  /// The search text, which outlives a rebuild of this view.
  final TextEditingController search;

  /// Opens the tapped connection.
  final ValueChanged<StudioConnection> onOpen;

  final ValueChanged<StudioConnection>? onLongPress;

  /// The id of the active connection, which its row marks.
  final String? activeId;

  /// Asks Studio again on a pull to refresh; null offers no pull to refresh.
  final RefreshCallback? onRefresh;

  /// Whether a Recent strip of the last connections the user opened leads the list.
  final bool showRecent;

  /// False while governance is unavailable: the rows and the Recent strip show greyed and neither open nor star.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    // A search shows every match, so it opens the collapsed sections without changing what the device remembers.
    final searching = state.isSearching;
    final list = BlocBuilder<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      builder: (context, favoritesState) {
        final favorites = switch (favoritesState) {
          FavoriteConnectionsReady(:final favorites) => favorites,
          FavoriteConnectionsNone() || FavoriteConnectionsLoading() || FavoriteConnectionsUnavailable() => null,
        };
        final split = withFavorites(state.sections, favorites?.starred ?? const {});
        // The strip is a shortcut to the whole list, so a search or a filter hides it.
        final recent = !showRecent || favorites == null || searching || state.environment != null
            ? const <StudioConnection>[]
            : recentConnections(state.connections, favorites.recent);
        return BlocBuilder<CollapsedSectionsCubit, CollapsedSectionsState>(
          builder: (context, collapsed) {
            bool isOpen(String key) => searching || !collapsed.isCollapsed(key);
            Widget sectionHeader(String key, String title, int count) => ConnectionSectionHeader(
              key: ValueKey('connection-section-$key'),
              title: title,
              count: count,
              collapsed: !isOpen(key),
              onTap: searching ? null : () => context.read<CollapsedSectionsCubit>().toggle(key),
            );
            Widget connectionRow(StudioConnection connection) => ConnectionRow(
              key: ValueKey('connection-row-${connection.id}'),
              connection: connection,
              starred: favorites?.starred.contains(connection.id),
              isActive: connection.id == activeId,
              enabled: enabled,
              onTap: () => onOpen(connection),
              onLongPress: onLongPress == null ? null : () => onLongPress!(connection),
            );
            return ListView(
              key: const ValueKey('connection-sections'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                if (recent.isNotEmpty) _RecentStrip(connections: recent, onOpen: onOpen, enabled: enabled),
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
                  sectionHeader(section.key, section.group ?? l10n.connection_group_other, section.connections.length),
                  if (isOpen(section.key)) ...section.connections.map(connectionRow),
                ],
              ],
            );
          },
        );
      },
    );
    final refresh = onRefresh;
    // On a compact height, such as a phone held sideways, the search and the chips share a row so the list keeps the
    // height. A Flex that only turns keeps the field in its place in the tree, so a rotation keeps its focus.
    final compact = AppBreakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);
    return Column(
      children: [
        Flex(
          direction: compact ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
          children: [
            Flexible(
              flex: compact ? 1 : 0,
              fit: compact ? FlexFit.tight : FlexFit.loose,
              child: Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, 0, 0)
                    : const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: ConnectionSearchField(controller: search),
              ),
            ),
            Flexible(
              flex: compact ? 1 : 0,
              fit: compact ? FlexFit.tight : FlexFit.loose,
              child: EnvironmentChips(environments: state.environments, selected: state.environment, compact: compact),
            ),
          ],
        ),
        Expanded(
          child: refresh == null ? list : RefreshIndicator(onRefresh: refresh, child: list),
        ),
      ],
    );
  }
}

/// Names the Favorites section in the stored collapsed state; a group key always starts with `group:`.
const _favoritesKey = 'favorites';

class ConnectionSearchField extends StatelessWidget {
  const ConnectionSearchField({super.key, required this.controller});

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

class EnvironmentChips extends StatelessWidget {
  const EnvironmentChips({super.key, required this.environments, required this.selected, this.compact = false});

  final List<String> environments;
  final String? selected;

  /// Whether the chips share the search's row on a compact height, with less padding above and below them.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (environments.isEmpty) return const SizedBox(height: AppSpacing.sm);
    final l10n = S.of(context);
    return Semantics(
      container: true,
      label: l10n.connection_environment_filter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: compact ? AppSpacing.xs : AppSpacing.sm),
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

class ConnectionSectionHeader extends StatelessWidget {
  const ConnectionSectionHeader({
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

/// One connection: its environment strip, engine, name, database or host, badges, a dot when it is the active one,
/// and its star. On a compact height the badges follow the name on its line.
class ConnectionRow extends StatelessWidget {
  const ConnectionRow({
    super.key,
    required this.connection,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.starred,
    this.enabled = true,
  });

  final StudioConnection connection;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;

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
    final badges = [
      if (showsBadge) EnvironmentBadge(environment: environment!, color: connection.color),
      if (connection.readOnlyForUser) const ReadOnlyChip(),
    ];
    final name = Text(connection.name, style: theme.textTheme.bodyLarge);
    // On a compact height, such as a phone held sideways, the badges share the name's line, so more rows fit.
    final compact = AppBreakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);
    final row = Semantics(
      selected: isActive,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: strip ?? Colors.transparent, width: 4)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            starred == null ? AppSpacing.lg : 0,
            AppSpacing.sm,
          ),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              Icon(engineIcon(connection.type), semanticLabel: connection.type, color: theme.colorScheme.primary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    if (badges.isEmpty || !compact)
                      name
                    else
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [name, ...badges],
                      ),
                    if (secondary != null)
                      Text(
                        secondary,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    if (badges.isNotEmpty && !compact)
                      Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: badges),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.circle,
                  size: 10,
                  color: theme.colorScheme.primary,
                  semanticLabel: S.of(context).connection_active,
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
      ),
    );
    return enabled ? row : IgnorePointer(child: Opacity(opacity: 0.38, child: row));
  }
}

/// The last connections the user opened, the one opened last first, each a shortcut that opens it like its row.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.connections, required this.onOpen, required this.enabled});

  final List<StudioConnection> connections;
  final ValueChanged<StudioConnection> onOpen;

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
                  onPressed: enabled ? () => onOpen(connection) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
