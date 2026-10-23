import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/object_browser/application/kind_counts_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/kind_sections.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_refresh.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// The kind screen of [container] of [connectionId]: one row per kind, with Studio's label and how many objects of it
/// the container holds, grouped under the kind's folder when it has one. An empty [container] is the connection
/// itself, on an engine with no container level.
class KindCountsPage extends StatelessWidget {
  const KindCountsPage({super.key, required this.connectionId, required this.container, this.headingAction});

  final String connectionId;
  final List<String> container;

  /// What the heading row offers at its end, such as the Browse root's search.
  final Widget? headingAction;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => KindCountsBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
        container: container,
        schemaChanges: context.read<SchemaChangeNotifier>().changes,
      )..add(const KindCountsRequested()),
      child: _KindCountsView(connectionId: connectionId, container: container, headingAction: headingAction),
    );
  }
}

class _KindCountsView extends StatelessWidget {
  const _KindCountsView({required this.connectionId, required this.container, this.headingAction});

  final String connectionId;
  final List<String> container;
  final Widget? headingAction;

  Future<void> _refresh(BuildContext context) => refreshBrowseUnlessOffline(context, () async {
    final bloc = context.read<KindCountsBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        KindCountsLoaded(:final isRefreshing) => !isRefreshing,
        KindCountsFailure() => true,
        KindCountsLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const KindCountsRefreshed());
    await done;
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KindCountsBloc, KindCountsState>(
      builder: (context, state) => switch (state) {
        KindCountsLoading() => const Center(child: CircularProgressIndicator()),
        KindCountsLoaded() => _buildKinds(context, state),
        KindCountsFailure(:final error, :final previous?) => _buildKinds(context, previous, error: error),
        KindCountsFailure(:final error) => RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              BrowseFailureView(
                connectionId: connectionId,
                error: error,
                onRetry: () => context.read<KindCountsBloc>().add(const KindCountsRequested()),
              ),
            ],
          ),
        ),
      },
    );
  }

  /// Whether a kind row opens its objects: every kind does, but one whose count and listing are one read once Studio
  /// refused its count, since its listing would meet the same refusal (Studio's agent sends none for it either).
  static bool _opens(KindRow row) => !(row.kind.countIsListing && row.count is KindCountUnavailable);

  Widget _buildKinds(BuildContext context, KindCountsLoaded kinds, {AppError? error}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        OfflineStaleMarker(loadedAt: kinds.loadedAt),
        if (error != null)
          BrowseFailureView(
            connectionId: connectionId,
            error: error,
            onRetry: () => context.read<KindCountsBloc>().add(const KindCountsRefreshed()),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                BrowseHeading(
                  title: kinds.container?.name ?? S.of(context).browse_objects,
                  overline: kinds.levelLabel,
                  actions: [?headingAction],
                ),
                if (kinds.browsesKeys)
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(S.of(context).keys_browse),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openBrowseKeys(context, connectionId, container),
                  ),
                if (kinds.sections.isEmpty)
                  Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(S.of(context).browse_kinds_empty)),
                for (final section in kinds.sections) ...[
                  if (section.group case final group?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                      child: Semantics(
                        header: true,
                        child: Text(
                          group.label,
                          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  for (final row in section.rows)
                    _KindTile(
                      row: row,
                      onTap: _opens(row)
                          ? () => openBrowseObjects(context, connectionId, container, row.kind.id)
                          : null,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One kind and its count, grouped in the locale's way: `1,207`, `12,000+` for a floor Studio measured from a read
/// that stopped short, or Studio's sentence for why the engine could not count it. [onTap] opens the kind's objects.
class _KindTile extends StatelessWidget {
  const _KindTile({required this.row, this.onTap});

  final KindRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (row.count) {
      KindCounted(:final count, :final isFloor) => ListTile(
        title: Text(row.kind.labelPlural),
        trailing: Text(_grouped(context, count, isFloor: isFloor), style: theme.textTheme.bodyMedium),
        onTap: onTap,
      ),
      KindCountUnavailable(:final reason) => ListTile(
        title: Text(row.kind.labelPlural),
        subtitle: Text(reason, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        onTap: onTap,
      ),
    };
  }

  static String _grouped(BuildContext context, int count, {required bool isFloor}) {
    final formatted = NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(count);
    return isFloor ? '$formatted+' : formatted;
  }
}
