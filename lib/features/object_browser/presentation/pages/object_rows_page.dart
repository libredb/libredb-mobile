import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/object_rows_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/row_count_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_database_words.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_refresh.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/row_count.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';

/// The first rows of the object at [path] of [connectionId], of [kind]: its name as the heading, with 'Count rows' when
/// the engine offers a count, and Studio's preview, masked, in the result view.
///
/// The preview runs on open, and again only on the user's pull or retry; a failure is never run again by itself. A
/// `studio.query_error` shows the database's own words under the banner, on screen only.
class ObjectRowsPage extends StatelessWidget {
  const ObjectRowsPage({super.key, required this.connectionId, required this.path, required this.kind});

  final String connectionId;
  final List<String> path;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final role = StudioRoleScope.of(context);
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ObjectRowsBloc(
            statements: context.read<IStatementRepository>(),
            providerMeta: context.read<IProviderMetaRepository>(),
            connectionId: connectionId,
            path: path,
            kind: kind,
          )..add(ObjectRowsRequested(role: role)),
        ),
        BlocProvider(
          create: (context) =>
              RowCountBloc(statements: context.read<IStatementRepository>(), connectionId: connectionId),
        ),
      ],
      child: _ObjectRowsView(page: this),
    );
  }
}

class _ObjectRowsView extends StatelessWidget {
  const _ObjectRowsView({required this.page});

  final ObjectRowsPage page;

  /// Runs the preview again, for the role Studio names now.
  void _run(BuildContext context) =>
      context.read<ObjectRowsBloc>().add(ObjectRowsRequested(role: StudioRoleScope.of(context)));

  Future<void> _refresh(BuildContext context) => refreshBrowseUnlessOffline(context, () async {
    final bloc = context.read<ObjectRowsBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ObjectRowsLoaded(:final isRefreshing) => !isRefreshing,
        ObjectRowsFailure() || ObjectRowsUnavailable() => true,
        ObjectRowsLoading() => false,
      },
      orElse: () => bloc.state,
    );
    _run(context);
    await done;
  });

  @override
  Widget build(BuildContext context) => BlocBuilder<ObjectRowsBloc, ObjectRowsState>(
    builder: (context, state) {
      final (meta, kind) = switch (state) {
        ObjectRowsLoading() => (null, null),
        ObjectRowsUnavailable(:final meta, :final kind) => (meta, kind),
        ObjectRowsLoaded(:final meta, :final kind) => (meta, kind),
        ObjectRowsFailure(:final meta, :final kind) => (meta, kind),
      };
      final loaded = switch (state) {
        final ObjectRowsLoaded loaded => loaded,
        ObjectRowsFailure(:final previous) => previous,
        ObjectRowsLoading() || ObjectRowsUnavailable() => null,
      };
      final error = switch (state) {
        ObjectRowsFailure(:final error) => error,
        _ => null,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loaded != null) OfflineStaleMarker(loadedAt: loaded.loadedAt),
          if (error != null) ...[
            BrowseFailureView(connectionId: page.connectionId, error: error, onRetry: () => _run(context)),
            if (browseDatabaseWordsOf(error) case final words?) BrowseDatabaseWords(words),
          ],
          BrowseHeading(
            title: page.path.isEmpty ? page.kind : page.path.last,
            overline: kind?.label ?? page.kind,
            wrappedActions: [
              if (_countOf(meta, kind) case final count?)
                OnlineOnlyAction(
                  builder: (context, online) => CountRowsButton(statement: count, enabled: online),
                ),
            ],
          ),
          const RowCountLine(),
          Expanded(child: _body(context, state, loaded)),
        ],
      );
    },
  );

  Widget _body(BuildContext context, ObjectRowsState state, ObjectRowsLoaded? loaded) {
    if (loaded != null) {
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        // A short result still pulls to refresh.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(physics: const AlwaysScrollableScrollPhysics()),
          child: BlocProvider(
            // Each run is a result of its own, masked with the policy of its own run.
            key: ValueKey(loaded.run),
            create: (_) {
              final rows = context.read<ObjectRowsBloc>();
              return ResultViewBloc(
                masked: loaded.masked,
                policy: loaded.policy,
                loadPage: (page) => rows.loadPage(loaded.preview, page),
                supportsResultPagination: loaded.meta.supportsResultPagination,
                // The generator never writes an ORDER BY, so a later page may not follow the first's order.
                hasOuterOrderBy: false,
              );
            },
            child: const ResultView(),
          ),
        ),
      );
    }
    return switch (state) {
      ObjectRowsUnavailable() => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(S.of(context).browse_preview_unavailable),
      ),
      ObjectRowsFailure() => RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(physics: const AlwaysScrollableScrollPhysics()),
      ),
      ObjectRowsLoading() || ObjectRowsLoaded() => const Center(child: CircularProgressIndicator()),
    };
  }

  PreviewStatement? _countOf(ProviderMeta? meta, ObjectKind? kind) {
    if (meta == null || kind == null) return null;
    return switch (const PreviewStatementGenerator().count(meta, kind, page.path)) {
      final PreviewStatement count => count,
      PreviewUnavailable() => null,
    };
  }
}
