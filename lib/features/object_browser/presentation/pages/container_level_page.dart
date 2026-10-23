import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/object_browser/application/container_browser_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/session_default_entry.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/kind_counts_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_refresh.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// One level of [connectionId]'s containers: the top level, or the one under [parent].
///
/// A container opens the level under it, or its kind screen at the last level; an engine with no container level shows
/// its kind screen here instead. On the first entry of a connection the level opens its session-default container by
/// itself.
class ContainerLevelPage extends StatelessWidget {
  const ContainerLevelPage({super.key, required this.connectionId, this.parent = const []});

  final String connectionId;
  final List<String> parent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContainerBrowserBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
        parent: parent,
        schemaChanges: context.read<SchemaChangeNotifier>().changes,
        entry: context.read<SessionDefaultEntry>(),
      )..add(const ContainerBrowserRequested()),
      child: _ContainerLevelView(connectionId: connectionId, parent: parent),
    );
  }
}

class _ContainerLevelView extends StatelessWidget {
  const _ContainerLevelView({required this.connectionId, required this.parent});

  final String connectionId;
  final List<String> parent;

  void _open(BuildContext context, ContainerBrowserLoaded level, ObjectContainer container) {
    if (level.opensKinds(container)) {
      openBrowseKinds(context, connectionId, container.path);
    } else {
      openBrowseContainers(context, connectionId, container.path);
    }
  }

  Future<void> _refresh(BuildContext context) => refreshBrowseUnlessOffline(context, () async {
    final bloc = context.read<ContainerBrowserBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ContainerBrowserLoaded(:final isRefreshing) => !isRefreshing,
        ContainerBrowserFailure() || ContainerBrowserNoLevels() => true,
        ContainerBrowserLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const ContainerBrowserRefreshed());
    await done;
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ContainerBrowserBloc, ContainerBrowserState>(
      listenWhen: (previous, current) => current is ContainerBrowserLoaded && current.openOnEntry != null,
      listener: (context, state) {
        final level = state as ContainerBrowserLoaded;
        _open(context, level, level.openOnEntry!);
      },
      builder: (context, state) => switch (state) {
        ContainerBrowserLoading() => const Center(child: CircularProgressIndicator()),
        ContainerBrowserNoLevels() => KindCountsPage(connectionId: connectionId, container: const []),
        ContainerBrowserLoaded() => _buildLevel(context, state),
        ContainerBrowserFailure(:final error, :final previous?) => _buildLevel(context, previous, error: error),
        ContainerBrowserFailure(:final error) => RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              BrowseFailureView(
                connectionId: connectionId,
                error: error,
                onRetry: () => context.read<ContainerBrowserBloc>().add(const ContainerBrowserRequested()),
              ),
            ],
          ),
        ),
      },
    );
  }

  Widget _buildLevel(BuildContext context, ContainerBrowserLoaded level, {AppError? error}) {
    final overline = parent.isEmpty ? null : parent.last;
    final visible = level.visibleContainers;
    return Column(
      children: [
        OfflineStaleMarker(loadedAt: level.loadedAt),
        if (error != null)
          BrowseFailureView(
            connectionId: connectionId,
            error: error,
            onRetry: () => context.read<ContainerBrowserBloc>().add(const ContainerBrowserRefreshed()),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                BrowseHeading(title: level.level.labelPlural, overline: overline),
                if (level.containers.isEmpty)
                  Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(S.of(context).browse_level_empty))
                else ...[
                  LocalFilterField(
                    key: const ValueKey('container-level-filter'),
                    onChanged: (query) =>
                        context.read<ContainerBrowserBloc>().add(ContainerBrowserFilterChanged(query)),
                  ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(S.of(context).local_filter_no_match),
                    ),
                ],
                for (final container in visible)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(container.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, level, container),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
