import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/object_browser/application/object_detail_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/object_source_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/row_count_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/navigation/object_tap_rule.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_refresh.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_source_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/row_count.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// The detail of the object at [path] of [connectionId], of [kind]: its name as the heading, then the tabs Columns,
/// Indexes, Foreign keys, and Source when the kind has source.
///
/// The heading offers 'View rows' and 'Count rows' by `objectRowsAction`, online only, with the count on a line under
/// it, and 'Open in editor' beside them, offline too; the top bar is the shell's.
class ObjectDetailPage extends StatelessWidget {
  const ObjectDetailPage({super.key, required this.connectionId, required this.path, required this.kind});

  final String connectionId;
  final List<String> path;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              RowCountBloc(statements: context.read<IStatementRepository>(), connectionId: connectionId),
        ),
        BlocProvider(
          create: (context) => ObjectDetailBloc(
            repository: context.read<IObjectBrowserRepository>(),
            providerMeta: context.read<IProviderMetaRepository>(),
            connectionId: connectionId,
            path: path,
            kind: kind,
            schemaChanges: context.read<SchemaChangeNotifier>().changes,
          )..add(const ObjectDetailRequested()),
        ),
      ],
      child: BlocBuilder<ObjectDetailBloc, ObjectDetailState>(
        builder: (context, state) => switch (state) {
          ObjectDetailLoading() => _withHeading(context, const Center(child: CircularProgressIndicator())),
          ObjectDetailLoaded() => _DetailTabs(page: this, loaded: state),
          ObjectDetailFailure(:final error, :final previous?) => _DetailTabs(
            page: this,
            loaded: previous,
            error: error,
          ),
          ObjectDetailFailure(:final error) => _withHeading(
            context,
            ListView(
              children: [
                BrowseFailureView(
                  runsStatement: false,
                  connectionId: connectionId,
                  error: error,
                  onRetry: () => context.read<ObjectDetailBloc>().add(const ObjectDetailRequested()),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }

  String get _title => path.isEmpty ? kind : path.last;

  Widget _withHeading(BuildContext context, Widget body) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BrowseHeading(title: _title),
      Expanded(child: body),
    ],
  );
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.page, required this.loaded, this.error});

  final ObjectDetailPage page;
  final ObjectDetailLoaded loaded;

  /// The failure of a refresh, shown over what was loaded before it.
  final AppError? error;

  Future<void> _refresh(BuildContext context) => refreshBrowseUnlessOffline(context, () async {
    final bloc = context.read<ObjectDetailBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ObjectDetailLoaded(:final isRefreshing) => !isRefreshing,
        ObjectDetailFailure() => true,
        ObjectDetailLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const ObjectDetailRefreshed());
    await done;
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final detail = loaded.detail;
    final hasSource = loaded.kind?.hasSource ?? false;
    final error = this.error;
    final kind = loaded.kind;
    final rowsAction = kind == null
        ? null
        : objectRowsAction(context, connectionId: page.connectionId, meta: loaded.meta, kind: kind, path: page.path);
    Widget refreshable(List<Widget> children) => RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: children),
    );
    return DefaultTabController(
      length: hasSource ? 4 : 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OfflineStaleMarker(loadedAt: loaded.loadedAt),
          if (error != null)
            BrowseFailureView(
              runsStatement: false,
              connectionId: page.connectionId,
              error: error,
              onRetry: () => context.read<ObjectDetailBloc>().add(const ObjectDetailRefreshed()),
            ),
          BrowseHeading(
            title: page._title,
            overline: loaded.kind?.label ?? page.kind,
            wrappedActions: [if (rowsAction != null) _RowsActions(action: rowsAction)],
          ),
          if (rowsAction is ObjectRowsRefused) _Caption(s.browse_preview_unavailable),
          const RowCountLine(),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.browse_detail_columns),
              Tab(text: s.browse_detail_indexes),
              Tab(text: s.browse_detail_foreign_keys),
              if (hasSource) Tab(text: s.browse_source),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                refreshable(_columns(context, detail)),
                refreshable(_indexes(context, detail)),
                refreshable(_foreignKeys(context, detail)),
                if (hasSource)
                  _TabOnScreen(
                    index: 3,
                    child: _SourceTab(connectionId: page.connectionId, path: page.path, kind: page.kind),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _columns(BuildContext context, ObjectDetail detail) {
    final s = S.of(context);
    return [
      if (detail.columns.any((column) => column.sampled)) _Caption(s.browse_detail_sampled),
      if (detail.columns.isEmpty) _Note(s.browse_detail_no_columns),
      for (final column in detail.columns) _ColumnTile(column: column),
    ];
  }

  List<Widget> _indexes(BuildContext context, ObjectDetail detail) {
    final s = S.of(context);
    final indexes = detail.indexes;
    final constraints = detail.exclusionConstraints;
    final theme = Theme.of(context);
    return [
      if (detail.indexesUnavailable case final sentence?) _Note(sentence),
      if (indexes != null && indexes.isEmpty && constraints.isEmpty) _Note(s.browse_detail_no_indexes),
      for (final index in indexes ?? const <IndexSchema>[])
        ListTile(
          title: Text(index.name),
          subtitle: Text(index.columns.join(', ')),
          trailing: index.unique ? Text(s.browse_detail_unique, style: theme.textTheme.labelMedium) : null,
        ),
      if (constraints.isNotEmpty) ...[
        _SectionHeader(s.browse_detail_exclusion_constraints),
        for (final constraint in constraints)
          ListTile(
            title: Text(constraint.name),
            subtitle: Text(constraint.definition, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ),
      ],
    ];
  }

  List<Widget> _foreignKeys(BuildContext context, ObjectDetail detail) {
    final s = S.of(context);
    return [
      if (detail.foreignKeys.isEmpty) _Note(s.browse_detail_no_foreign_keys),
      if (loaded.foreignKeyLookupError case final error? when detail.foreignKeys.isNotEmpty)
        _Caption(switch (error.code) {
          final code? => s.browse_detail_links_unchecked(code),
          // The type goes only to the log: in an obfuscated build it is a renamed one.
          null => s.browse_detail_links_unchecked_reason(AppErrorCode.generic.resolve(context)),
        }),
      for (final key in detail.foreignKeys)
        if (loaded.foreignKeyTargets[key.referencedTable] case final target?)
          ListTile(
            title: Text(key.columnName),
            subtitle: Text(s.browse_detail_references(key.referencedTable, key.referencedColumn)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openBrowseDetail(context, page.connectionId, target.path, target.kind),
          )
        else
          ListTile(
            title: Text(key.columnName),
            subtitle: Text(s.browse_detail_references(key.referencedTable, key.referencedColumn)),
          ),
    ];
  }
}

/// 'View rows', 'Open in editor' and, when the engine offers a count, 'Count rows', View rows and Count rows disabled
/// offline with the reason; 'View rows' is disabled too for an engine whose preview the app does not write, which the
/// page says under the heading, and 'Open in editor' is then absent.
class _RowsActions extends StatelessWidget {
  const _RowsActions({required this.action});

  final ObjectRowsAction action;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final action = this.action;
    return OnlineOnlyAction(
      builder: (context, online) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: switch (action) {
              ObjectRowsOpen(:final open) when online => open,
              ObjectRowsOpen() || ObjectRowsRefused() => null,
            },
            child: Text(s.browse_view_rows),
          ),
          // It sends nothing to Studio, so it stays enabled offline; the editor's Run is online only.
          if (action case ObjectRowsOpen(:final openInEditor))
            TextButton(onPressed: openInEditor, child: Text(s.browse_open_in_editor)),
          if (action case ObjectRowsOpen(:final count?)) CountRowsButton(statement: count, enabled: online),
        ],
      ),
    );
  }
}

/// One column: a key for a primary key, its name, the type a person is shown, marked when sampled, a nullable marker,
/// and its default as secondary text.
class _ColumnTile extends StatelessWidget {
  const _ColumnTile({required this.column});

  final ColumnSchema column;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final defaultValue = column.defaultValue;
    return ListTile(
      leading: column.isPrimary
          ? Icon(Icons.key, semanticLabel: s.browse_detail_primary_key, color: theme.colorScheme.primary)
          : const SizedBox(width: 24),
      title: Text(column.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(column.sampled ? s.browse_detail_sampled_type(column.shownType) : column.shownType),
          if (defaultValue != null) Text(s.browse_detail_default(defaultValue), style: secondary),
        ],
      ),
      trailing: column.nullable ? Text(s.browse_detail_nullable, style: theme.textTheme.labelMedium) : null,
    );
  }
}

/// [child], the page of the tab at [index] of the [DefaultTabController] above, with its tickers off while none of it
/// is in view. The tab view keeps the Source tab alive off screen, and its source viewer holds a screen capture lease
/// only while its tickers are on, so the tab shown in its place can be captured.
class _TabOnScreen extends StatelessWidget {
  const _TabOnScreen({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = DefaultTabController.of(context).animation!;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => TickerMode(enabled: (animation.value - index).abs() < 1, child: child!),
      child: child,
    );
  }
}

/// The Source tab: the object's definition in the source viewer, read when the tab first opens and kept while the
/// page stays open, so moving between tabs reads no source again.
class _SourceTab extends StatefulWidget {
  const _SourceTab({required this.connectionId, required this.path, required this.kind});

  final String connectionId;
  final List<String> path;
  final String kind;

  @override
  State<_SourceTab> createState() => _SourceTabState();
}

class _SourceTabState extends State<_SourceTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider(
      create: (context) => ObjectSourceBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: widget.connectionId,
        path: widget.path,
        kind: widget.kind,
      )..add(const ObjectSourceRequested()),
      child: BlocBuilder<ObjectSourceBloc, ObjectSourceState>(
        builder: (context, state) => switch (state) {
          ObjectSourceLoading() => const Center(child: CircularProgressIndicator()),
          ObjectSourceLoaded(:final source) => ObjectSourceView(source: source),
          ObjectSourceFailure(:final error) => ListView(
            children: [
              BrowseFailureView(
                runsStatement: false,
                connectionId: widget.connectionId,
                error: error,
                onRetry: () => context.read<ObjectSourceBloc>().add(const ObjectSourceRequested()),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(text));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}
