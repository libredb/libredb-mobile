import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/object_browser/application/object_search_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_tile.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// A search of [connectionId]'s objects by name, across every container, grouped by container path; a match opens by
/// the object list's tap rule.
class ObjectSearchPage extends StatelessWidget {
  const ObjectSearchPage({super.key, required this.connectionId});

  final String connectionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ObjectSearchBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
      )..add(const ObjectSearchStarted()),
      child: _ObjectSearchView(connectionId: connectionId),
    );
  }
}

class _ObjectSearchView extends StatefulWidget {
  const _ObjectSearchView({required this.connectionId});

  final String connectionId;

  @override
  State<_ObjectSearchView> createState() => _ObjectSearchViewState();
}

class _ObjectSearchViewState extends State<_ObjectSearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<ObjectSearchBloc>().add(const ObjectSearchTermChanged(''));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final heading = BrowseHeading(title: s.browse_search_title);
    return BlocBuilder<ObjectSearchBloc, ObjectSearchState>(
      builder: (context, state) => switch (state) {
        ObjectSearchPreparing() => const Center(child: CircularProgressIndicator()),
        ObjectSearchNotAvailable() => ListView(
          children: [
            heading,
            Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(s.browse_search_not_available)),
          ],
        ),
        ObjectSearchFailure(:final error, meta: null) => ListView(
          children: [
            heading,
            BrowseFailureView(
              runsStatement: false,
              connectionId: widget.connectionId,
              error: error,
              onRetry: () => context.read<ObjectSearchBloc>().add(const ObjectSearchStarted()),
            ),
          ],
        ),
        ObjectSearchIdle(:final meta) => _buildSearch(
          context,
          heading,
          state,
          meta,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(s.browse_search_min_length(ObjectSearchBloc.minimumLength)),
          ),
        ),
        ObjectSearchSearching(:final meta) => _buildSearch(
          context,
          heading,
          state,
          meta,
          const Center(child: CircularProgressIndicator()),
        ),
        ObjectSearchResults(:final meta, :final term, :final groups) => _buildSearch(
          context,
          heading,
          state,
          meta,
          groups.isEmpty
              ? Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(s.browse_search_no_results(term)))
              : _Results(connectionId: widget.connectionId, meta: meta, groups: groups),
        ),
        ObjectSearchTooBroad(:final meta) => _buildSearch(
          context,
          heading,
          state,
          meta,
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(AppErrorCode.studioSearchPairLimit.resolve(context)),
          ),
        ),
        ObjectSearchFailure(:final error, :final meta?, :final term) => _buildSearch(
          context,
          heading,
          state,
          meta,
          ListView(
            children: [
              BrowseFailureView(
                runsStatement: false,
                connectionId: widget.connectionId,
                error: error,
                onRetry: () => context.read<ObjectSearchBloc>().add(ObjectSearchSubmitted(term ?? _controller.text)),
              ),
            ],
          ),
        ),
      },
    );
  }

  /// The search field above [body], and the kind chips once Studio asked for kinds or while some are picked.
  Widget _buildSearch(BuildContext context, Widget heading, ObjectSearchState state, ProviderMeta meta, Widget body) {
    final s = S.of(context);
    final bloc = context.read<ObjectSearchBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => TextField(
              key: const ValueKey('object-search-field'),
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: (term) => bloc.add(ObjectSearchTermChanged(term)),
              onSubmitted: (term) => bloc.add(ObjectSearchSubmitted(term)),
              decoration: InputDecoration(
                isDense: true,
                // On an engine with a key browser Studio's hint names keys, which the search never lists: it finds
                // object names, such as key patterns, so the app's own wording is shown there.
                hintText: (meta.keyScan == null ? meta.labels.searchPlaceholder : null) ?? s.browse_search_hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), tooltip: s.browse_search_clear, onPressed: _clear),
              ),
            ),
          ),
        ),
        if (state is ObjectSearchTooBroad || state.kinds.isNotEmpty)
          _KindChips(
            kinds: state.searchKinds,
            picked: state.kinds,
            onChanged: (kinds) => bloc.add(ObjectSearchKindsChanged(kinds)),
          ),
        Expanded(child: body),
      ],
    );
  }
}

/// A chip per kind a search can be narrowed to, labelled as the object list labels the kind; a tap picks or drops it.
class _KindChips extends StatelessWidget {
  const _KindChips({required this.kinds, required this.picked, required this.onChanged});

  final List<ObjectKind> kinds;
  final List<String> picked;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final kind in kinds)
            FilterChip(
              label: Text(kind.labelPlural),
              selected: picked.contains(kind.id),
              onSelected: (selected) => onChanged([
                for (final id in picked)
                  if (id != kind.id) id,
                if (selected) kind.id,
              ]),
            ),
        ],
      ),
    );
  }
}

/// The matches under a heading per container path, in Studio's order; an engine with no container level has one group
/// and no heading.
class _Results extends StatelessWidget {
  const _Results({required this.connectionId, required this.meta, required this.groups});

  final String connectionId;
  final ProviderMeta meta;
  final List<ObjectSearchGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    final rows = <Widget>[
      for (final group in groups) ...[
        if (group.container.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: Semantics(
              header: true,
              child: Text(
                group.container.join(' / '),
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        for (final match in group.matches)
          _MatchTile(connectionId: connectionId, meta: meta, match: match, number: number),
      ],
    ];
    return ListView(children: rows);
  }
}

/// One match: the object list's tile with its kind's label first, or, for a kind the engine does not declare, its name
/// alone, which opens nothing.
class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.connectionId, required this.meta, required this.match, required this.number});

  final String connectionId;
  final ProviderMeta meta;
  final ObjectSearchMatch match;
  final NumberFormat number;

  @override
  Widget build(BuildContext context) {
    final kind = match.kind;
    if (kind == null) {
      return ListTile(title: Text(match.object.name, maxLines: 1, overflow: TextOverflow.ellipsis));
    }
    return ObjectTile(
      connectionId: connectionId,
      meta: meta,
      kind: kind,
      childKindLabels: _childKindLabels(kind),
      object: match.object,
      number: number,
      kindLabel: kind.label,
    );
  }

  /// The plural labels of [kind]'s child kinds the engine declares, as the object list shows them.
  List<String> _childKindLabels(ObjectKind kind) => [
    for (final child in kind.childKinds)
      for (final declared in meta.objectKinds)
        if (declared.id == child) declared.labelPlural,
  ];
}
