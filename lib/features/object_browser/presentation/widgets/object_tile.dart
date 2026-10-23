import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/navigation/object_tap_rule.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/utils/byte_size.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// One object: its name, a badge when the engine reports a status (`INVALID` and `DISABLED` in the user's words, any
/// other as Studio sends it), and what else Studio says of it as secondary text: [kindLabel] when set, the object it
/// hangs under when its kind declares `attachedTo`, the kinds a group object holds, its row count and size. A tap opens
/// by the object tap rule, and a long press offers View rows (by `objectRowsAction`, online only), Open in editor
/// (wherever View rows opens, offline too), Details, View source and Copy name. The object list and the search share it, each passing its connection's [meta].
class ObjectTile extends StatelessWidget {
  const ObjectTile({
    super.key,
    required this.connectionId,
    required this.meta,
    required this.kind,
    required this.childKindLabels,
    required this.object,
    required this.number,
    this.kindLabel,
  });

  final String connectionId;

  /// The connection's provider-meta, which decides what View rows offers.
  final ProviderMeta meta;
  final ObjectKind kind;
  final List<String> childKindLabels;
  final DatabaseObject object;
  final NumberFormat number;

  /// The kind's label as the first secondary text, for a list that mixes kinds, such as the search's.
  final String? kindLabel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final path = object.path;
    final rowCount = object.rowCount;
    final sizeBytes = object.sizeBytes;
    final secondary = [
      ?kindLabel,
      if (kind.attachedTo != null && path.length >= 2) s.browse_object_attached_to(path[path.length - 2]),
      if (childKindLabels.isNotEmpty) childKindLabels.join(', '),
      if (rowCount != null) s.browse_object_rows(rowCount, number.format(rowCount)),
      if (sizeBytes != null && sizeBytes >= 0) formatByteSize(sizeBytes),
    ];
    final badge = switch (object.status) {
      'INVALID' => _StatusBadge(label: s.browse_object_status_invalid, color: theme.colorScheme.error),
      'DISABLED' => _StatusBadge(label: s.browse_object_status_disabled, color: theme.colorScheme.onSurfaceVariant),
      null => null,
      // Another engine's word, such as DB2's INOPERATIVE, shows as Studio sends it.
      final status => _StatusBadge(label: status, color: theme.colorScheme.onSurfaceVariant),
    };
    return ListTile(
      title: Text(object.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: secondary.isEmpty
          ? null
          : Text(
              secondary.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
      trailing: badge,
      onTap: objectTapAction(context, connectionId: connectionId, kind: kind, object: object),
      onLongPress: () => _showMenu(context),
    );
  }

  Future<void> _showMenu(BuildContext context) {
    final details = objectDetailAction(context, connectionId: connectionId, kind: kind, object: object);
    final viewSource = objectSourceAction(context, connectionId: connectionId, kind: kind, object: object);
    final viewRows = objectRowsAction(context, connectionId: connectionId, meta: meta, kind: kind, path: object.path);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        // Five entries outgrow a short sheet, such as a phone held sideways.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (viewRows != null)
                OnlineOnlyAction(
                  builder: (sheetContext, online) {
                    final s = S.of(sheetContext);
                    return switch (viewRows) {
                      ObjectRowsOpen(:final open) => ListTile(
                        leading: const Icon(Icons.table_rows_outlined),
                        title: Text(s.browse_view_rows),
                        enabled: online,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          open();
                        },
                      ),
                      ObjectRowsRefused() => ListTile(
                        leading: const Icon(Icons.table_rows_outlined),
                        title: Text(s.browse_view_rows),
                        subtitle: Text(s.browse_preview_unavailable),
                        enabled: false,
                      ),
                    };
                  },
                ),
              // It sends nothing to Studio, so it is offered offline too; the editor's Run is online only.
              if (viewRows case ObjectRowsOpen(:final openInEditor))
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(S.of(sheetContext).browse_open_in_editor),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openInEditor();
                  },
                ),
              if (details != null)
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: Text(S.of(sheetContext).browse_details),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    details();
                  },
                ),
              if (viewSource != null)
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(S.of(sheetContext).browse_object_view_source),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    viewSource();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(S.of(sheetContext).browse_object_copy_name),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final copied = S.of(sheetContext).browse_object_name_copied;
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: object.name));
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(copied)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the engine reports of an object, in words, so it never rests on color alone.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ),
    );
  }
}
