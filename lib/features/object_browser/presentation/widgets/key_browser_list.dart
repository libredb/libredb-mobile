import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/object_browser/application/key_browser_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/key_tree.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/navigation/object_tap_rule.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The pattern field of the key browser: a glob that starts at `*`, or a literal prefix that starts empty. Submitting
/// it starts the walk again from its first page.
class KeyPatternField extends StatefulWidget {
  const KeyPatternField({super.key, required this.walk});

  final KeyBrowserLoaded walk;

  @override
  State<KeyPatternField> createState() => _KeyPatternFieldState();
}

class _KeyPatternFieldState extends State<KeyPatternField> {
  late final TextEditingController _controller = TextEditingController(text: widget.walk.pattern);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glob = widget.walk.spec.pattern == 'glob';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: TextField(
        key: const ValueKey('key-pattern'),
        controller: _controller,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: glob ? S.of(context).keys_pattern_glob : S.of(context).keys_pattern_prefix,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
        onSubmitted: (text) => context.read<KeyBrowserBloc>().add(KeyBrowserPatternSubmitted(text)),
      ),
    );
  }
}

/// How far the walk got, in the scope the engine's total counts, what Studio said about it, and the page controls.
class KeyWalkSummary extends StatelessWidget {
  const KeyWalkSummary({super.key, required this.walk});

  final KeyBrowserLoaded walk;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final warning = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);
    final bloc = context.read<KeyBrowserBloc>();
    final idle = walk.load == KeyPageLoad.idle;
    final skipped = walk.skipped;
    final readOutcome = walk.readOutcome;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(_progress(context, s), key: const ValueKey('key-progress'), style: theme.textTheme.bodyMedium),
          if (walk.clustered == true) Text(s.keys_clustered, style: note),
          if (skipped != null)
            Text(s.keys_skipped(skipped.count, _number(context).format(skipped.count), skipped.reason), style: warning),
          if (readOutcome != null) ...[
            Text(
              readOutcome.isIncomplete
                  ? s.keys_read_incomplete(readOutcome.endReason)
                  : s.keys_read_unknown(readOutcome.endReason),
              style: note,
            ),
            for (final loss in readOutcome.provenLoss) Text(loss, style: warning),
          ],
          // Drawn from the held count alone, so a trimmed last page keeps it too, as Studio's panel does.
          if (walk.atCap) Text(s.keys_cap, style: warning),
          if (walk.load == KeyPageLoad.all) ...[
            LinearProgressIndicator(value: (walk.held / KeyBrowserBloc.heldKeyLimit).clamp(0, 1).toDouble()),
            OutlinedButton.icon(
              onPressed: walk.stopping ? null : () => bloc.add(const KeyBrowserStopped()),
              icon: const Icon(Icons.stop),
              label: Text(walk.stopping ? s.keys_stopping : s.keys_stop),
            ),
          ] else if (walk.hasMore && !walk.atCap)
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: idle ? () => bloc.add(const KeyBrowserMoreRequested()) : null,
                  child: Text(s.keys_load_more),
                ),
                OutlinedButton(
                  onPressed: idle ? () => bloc.add(const KeyBrowserAllRequested()) : null,
                  child: Text(s.keys_load_all),
                ),
                if (!idle) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
        ],
      ),
    );
  }

  /// 'Scanned n keys; more remain' until the cursor returns to `0`, with the total in the scope `totalScope` names:
  /// the database's key count, the walk's exact count, or none. Under a pattern the pages hand over only the keys that
  /// match it, so the line says how many were found rather than scanned. Counts are grouped in the locale's way.
  String _progress(BuildContext context, S s) {
    final number = _number(context);
    // Capped for display only, as Studio's panel does: the screen never holds more than the limit.
    final count = walk.scanned < KeyBrowserBloc.heldKeyLimit ? walk.scanned : KeyBrowserBloc.heldKeyLimit;
    final formatted = number.format(count);
    final more = walk.hasMore;
    final total = walk.total;
    final found = walk.pattern.isNotEmpty && !(walk.spec.pattern == 'glob' && walk.pattern == '*');
    if (walk.usesLevels) return more ? s.keys_listed_more(count, formatted) : s.keys_listed(count, formatted);
    if (total != null && walk.spec.totalScope == 'database') {
      if (found) {
        return more
            ? s.keys_found_of_database_more(count, formatted, number.format(total))
            : s.keys_found_of_database(count, formatted, number.format(total));
      }
      return more ? s.keys_scanned_of_database_more(count, total) : s.keys_scanned_of_database(count, total);
    }
    if (total != null && walk.spec.totalScope == 'walk') {
      if (found) return more ? s.keys_found_of_walk_more(count, total) : s.keys_found_of_walk(count, total);
      return more ? s.keys_scanned_of_walk_more(count, total) : s.keys_scanned_of_walk(count, total);
    }
    if (found) return more ? s.keys_found_more(count, formatted) : s.keys_found(count, formatted);
    return more ? s.keys_scanned_more(count, formatted) : s.keys_scanned(count, formatted);
  }
}

/// The rows of the walk under [header]: without levels, the held keys grouped into folders by the engine's separator,
/// which open in place; with levels, the folders Studio named, each of which opens its own level as a new page.
class KeyBrowserList extends StatefulWidget {
  const KeyBrowserList({
    super.key,
    required this.connectionId,
    required this.container,
    required this.prefix,
    required this.walk,
    required this.header,
  });

  final String connectionId;
  final List<String> container;
  final String? prefix;
  final KeyBrowserLoaded walk;
  final List<Widget> header;

  @override
  State<KeyBrowserList> createState() => _KeyBrowserListState();
}

class _KeyBrowserListState extends State<KeyBrowserList> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final walk = widget.walk;
    final rows = walk.usesLevels ? _levelRows(walk) : _treeRows(walk);
    final empty = rows.isEmpty && !walk.hasMore && walk.load == KeyPageLoad.idle;
    final header = [
      ...widget.header,
      if (empty) Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(S.of(context).keys_empty)),
    ];
    return ListView.builder(
      itemCount: header.length + rows.length,
      itemBuilder: (context, index) => index < header.length ? header[index] : rows[index - header.length](context),
    );
  }

  List<WidgetBuilder> _treeRows(KeyBrowserLoaded walk) => [
    for (final row in keyTreeRows(walk.keys, walk.types, walk.spec.separator, expanded: _expanded))
      switch (row) {
        KeyTreeFolder() => (context) => _FolderTile(
          label: row.label,
          depth: row.depth,
          count: row.count,
          expanded: row.expanded,
          onTap: () => setState(() => row.expanded ? _expanded.remove(row.prefix) : _expanded.add(row.prefix)),
        ),
        KeyTreeKey() => (context) => _KeyTile(
          label: row.label,
          depth: row.depth,
          type: row.type,
          onTap: _openOf(context, row.key, row.type),
        ),
      },
  ];

  List<WidgetBuilder> _levelRows(KeyBrowserLoaded walk) {
    final prefix = widget.prefix ?? '';
    String below(String name) =>
        name.startsWith(prefix) && name.length > prefix.length ? name.substring(prefix.length) : name;
    return [
      for (final folder in walk.folders)
        (context) => _FolderTile(
          label: below(folder),
          depth: 0,
          onTap: () => openBrowseKeys(context, widget.connectionId, widget.container, prefix: folder),
        ),
      for (final key in walk.keys)
        (context) =>
            _KeyTile(label: below(key), depth: 0, type: walk.types[key], onTap: _openOf(context, key, walk.types[key])),
    ];
  }

  /// What a tap on [key], the whole key rather than the label its row shows, opens.
  VoidCallback? _openOf(BuildContext context, String key, String? type) => keyOpenAction(
    context,
    connectionId: widget.connectionId,
    meta: widget.walk.meta,
    container: widget.container,
    key: key,
    type: type,
  );
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.label, required this.depth, required this.onTap, this.count, this.expanded});

  final String label;
  final int depth;
  final int? count;

  /// Whether a folder that opens in place is open; null for a level folder, which opens a new page.
  final bool? expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expanded = this.expanded;
    final count = this.count;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsetsDirectional.only(start: AppSpacing.lg + depth * AppSpacing.lg, end: AppSpacing.lg),
      leading: Icon(switch (expanded) {
        true => Icons.expand_more,
        false => Icons.chevron_right,
        null => Icons.folder_outlined,
      }),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: count == null ? const Icon(Icons.chevron_right) : Text(_number(context).format(count)),
      onTap: onTap,
    );
  }
}

class _KeyTile extends StatelessWidget {
  const _KeyTile({required this.label, required this.depth, required this.onTap, this.type});

  final String label;
  final int depth;
  final String? type;

  /// Opens the key, or null on an engine whose keys open nothing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = this.type;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsetsDirectional.only(start: AppSpacing.lg + depth * AppSpacing.lg, end: AppSpacing.lg),
      leading: const Icon(Icons.key_outlined),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: type == null ? null : KeyTypeChip(type: type),
      onTap: onTap,
    );
  }
}

/// A key's value type, as a page read it.
class KeyTypeChip extends StatelessWidget {
  const KeyTypeChip({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Text(type, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
      ),
    );
  }
}

/// Groups a count in the locale's way, as the object list does.
NumberFormat _number(BuildContext context) => NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
