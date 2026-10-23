import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/object_browser/application/object_list_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_refresh.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_tile.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// The objects of [kind] in [container] of [connectionId], with a filter that narrows them on the device.
class ObjectListPage extends StatelessWidget {
  const ObjectListPage({super.key, required this.connectionId, required this.container, required this.kind});

  final String connectionId;
  final List<String> container;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ObjectListBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
        container: container,
        kind: kind,
        schemaChanges: context.read<SchemaChangeNotifier>().changes,
      )..add(const ObjectListRequested()),
      child: _ObjectListView(connectionId: connectionId, container: container),
    );
  }
}

class _ObjectListView extends StatelessWidget {
  const _ObjectListView({required this.connectionId, required this.container});

  final String connectionId;
  final List<String> container;

  Future<void> _refresh(BuildContext context) => refreshBrowseUnlessOffline(context, () async {
    final bloc = context.read<ObjectListBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ObjectListLoaded(:final isRefreshing) => !isRefreshing,
        ObjectListFailure() => true,
        ObjectListLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const ObjectListRefreshed());
    await done;
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ObjectListBloc, ObjectListState>(
      builder: (context, state) => switch (state) {
        ObjectListLoading() => const Center(child: CircularProgressIndicator()),
        ObjectListLoaded() => _buildList(context, state),
        ObjectListFailure(:final error, :final previous?) => _buildList(context, previous, error: error),
        ObjectListFailure(:final error) => RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              BrowseFailureView(
                runsStatement: false,
                connectionId: connectionId,
                error: error,
                onRetry: () => context.read<ObjectListBloc>().add(const ObjectListRequested()),
              ),
            ],
          ),
        ),
      },
    );
  }

  Widget _buildList(BuildContext context, ObjectListLoaded list, {AppError? error}) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    final total = list.objects.length;
    final visible = list.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OfflineStaleMarker(loadedAt: list.loadedAt),
        if (error != null)
          BrowseFailureView(
            runsStatement: false,
            connectionId: connectionId,
            error: error,
            onRetry: () => context.read<ObjectListBloc>().add(const ObjectListRefreshed()),
          ),
        BrowseHeading(title: list.kind.labelPlural, overline: container.isEmpty ? null : container.last),
        if (total > 0) ...[
          LocalFilterField(
            key: const ValueKey('object-list-filter'),
            onChanged: (query) => context.read<ObjectListBloc>().add(ObjectListFilterChanged(query)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                list.isFiltering
                    ? s.browse_objects_match(visible.length, total)
                    : s.browse_objects_count(total, number.format(total)),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
        Expanded(
          key: const ValueKey('object-list-rows'),
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: total == 0 || visible.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(total == 0 ? s.browse_objects_empty : s.local_filter_no_match),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => ObjectTile(
                      connectionId: connectionId,
                      meta: list.meta,
                      kind: list.kind,
                      childKindLabels: list.childKindLabels,
                      object: visible[index],
                      number: number,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
