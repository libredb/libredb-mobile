import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
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

/// The connections Studio offers the signed-in user, in sections by the operator's group, with a search and an
/// environment filter. It never offers to add a connection: Studio's operator configures them.
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

  /// Asks Studio again and completes once the answer, or its failure, is on screen, which ends the pull indicator.
  Future<void> _refresh() async {
    final bloc = context.read<ConnectionListBloc>();
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ConnectionListLoaded(:final isRefreshing) => !isRefreshing,
        ConnectionListFailure() => true,
        ConnectionListInitial() || ConnectionListLoading() => false,
      },
    );
    bloc.add(const ConnectionListRefreshed());
    await done;
  }

  @override
  Widget build(BuildContext context) {
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
        ConnectionListFailure(:final errorCode) => AppErrorState(
          title: S.of(context).connection_list_load_failed,
          description: errorCode.resolve(context),
          retryLabel: S.of(context).refresh,
          onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
        ),
      },
    );
  }

  Widget _buildLoaded(BuildContext context, ConnectionListLoaded state) {
    final l10n = S.of(context);
    if (state.connections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('connection-sections'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [AppEmptyState(icon: Icons.storage_outlined, title: l10n.connection_list_empty)],
        ),
      );
    }
    final sections = state.sections;
    // A search shows every match, so it opens the collapsed sections without changing what the device remembers.
    final searching = state.isSearching;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: _SearchField(controller: _search),
        ),
        _EnvironmentChips(environments: state.environments, selected: state.environment),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: BlocBuilder<CollapsedSectionsCubit, CollapsedSectionsState>(
              builder: (context, collapsed) => ListView(
                key: const ValueKey('connection-sections'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  if (sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        l10n.connection_search_no_match,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  for (final section in sections) ...[
                    _SectionHeader(
                      key: ValueKey('connection-section-${section.key}'),
                      title: section.group ?? l10n.connection_group_other,
                      count: section.connections.length,
                      collapsed: !searching && collapsed.isCollapsed(section.key),
                      onTap: searching ? null : () => context.read<CollapsedSectionsCubit>().toggle(section.key),
                    ),
                    if (searching || !collapsed.isCollapsed(section.key))
                      for (final connection in section.connections)
                        _ConnectionRow(key: ValueKey('connection-row-${connection.id}'), connection: connection),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
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
  const _ConnectionRow({super.key, required this.connection});

  final StudioConnection connection;

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
      onTap: () => _showDetails(context, connection),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: strip ?? Colors.transparent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
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
                  if (showsBadge || connection.readOnly)
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (showsBadge) EnvironmentBadge(environment: environment!, color: connection.color),
                        if (connection.readOnly) const ReadOnlyChip(),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Until the active connection (#26) lands, a tap shows what the app knows about the connection.
void _showDetails(BuildContext context, StudioConnection connection) {
  final l10n = S.of(context);
  final environment = connection.environment;
  final target = _target(connection);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          ListTile(
            leading: Icon(engineIcon(connection.type), semanticLabel: connection.type),
            title: Text(connection.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: connection.readOnly
                ? const Align(alignment: AlignmentDirectional.centerStart, child: ReadOnlyChip())
                : null,
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
