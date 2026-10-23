import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// What a tap on [object], of [kind] in [connectionId], opens, or null when it opens nothing.
///
/// The one rule of every object row, the object list's and search's: Details when the kind `hasColumns`, else Source
/// when it `hasSource`, else nothing. A group object such as an Oracle package is a leaf like any other, since Studio
/// lists no object's children.
VoidCallback? objectTapAction(
  BuildContext context, {
  required String connectionId,
  required ObjectKind kind,
  required DatabaseObject object,
}) =>
    objectDetailAction(context, connectionId: connectionId, kind: kind, object: object) ??
    objectSourceAction(context, connectionId: connectionId, kind: kind, object: object);

/// Opens the detail of [object] when [kind] `hasColumns`, for the tap and the long-press menu's 'Details'; null
/// otherwise.
VoidCallback? objectDetailAction(
  BuildContext context, {
  required String connectionId,
  required ObjectKind kind,
  required DatabaseObject object,
}) => kind.hasColumns ? () => openBrowseDetail(context, connectionId, object.path, kind.id) : null;

/// Opens the source of [object] when [kind] `hasSource`, for the long-press menu's 'View source'; null otherwise.
VoidCallback? objectSourceAction(
  BuildContext context, {
  required String connectionId,
  required ObjectKind kind,
  required DatabaseObject object,
}) => kind.hasSource ? () => openBrowseSource(context, connectionId, object.path, kind.id) : null;

/// What 'View rows' offers for an object, from [objectRowsAction].
sealed class ObjectRowsAction {
  const ObjectRowsAction();
}

/// 'View rows' opens the object's rows; [count] is Studio's count statement when the engine offers a count, else null.
final class ObjectRowsOpen extends ObjectRowsAction {
  const ObjectRowsOpen({required this.open, this.count});

  final VoidCallback open;
  final PreviewStatement? count;
}

/// 'View rows' shows disabled, saying preview is not available for this engine yet, and no count is offered.
final class ObjectRowsRefused extends ObjectRowsAction {
  const ObjectRowsRefused();
}

/// What 'View rows' and 'Count rows' offer for the object at [path] of [connectionId], of [kind], in the long-press
/// menu of the object list and the search and in the detail page's heading: null, nothing, for a kind that is not a
/// relation kind or that only the key browser lists, so a routine never gets a SELECT; [ObjectRowsRefused] for a
/// relation kind whose preview the generator refuses; else [ObjectRowsOpen], which opens `browseRows`.
///
/// A tap on the object never runs a statement: View rows is offered only from these two places.
ObjectRowsAction? objectRowsAction(
  BuildContext context, {
  required String connectionId,
  required ProviderMeta meta,
  required ObjectKind kind,
  required List<String> path,
}) {
  if (kind.role != 'relation' || kind.keyBrowserOnly) return null;
  const generator = PreviewStatementGenerator();
  return switch (generator.preview(meta, kind, path)) {
    PreviewUnavailable() => const ObjectRowsRefused(),
    PreviewStatement() => ObjectRowsOpen(
      open: () => openBrowseRows(context, connectionId, path, kind.id),
      count: switch (generator.count(meta, kind, path)) {
        final PreviewStatement count => count,
        PreviewUnavailable() => null,
      },
    ),
  };
}

/// What a tap on [key] in the key browser of [connectionId], walked in [container], opens, or null when it opens
/// nothing, as Studio's `onOpenKey` (`src/components/Studio.tsx:1158-1169`) decides: on an engine with a key-browser
/// kind (`keyBrowserKind`, the first kind `enumeratedBy: "key-browser"`), that kind's source for the path `[key]`,
/// which runs nothing; on an engine whose `queryDialect` is `redis`, the key's value page with the [type] its page
/// read; on any other engine nothing.
VoidCallback? keyOpenAction(
  BuildContext context, {
  required String connectionId,
  required ProviderMeta meta,
  required List<String> container,
  required String key,
  String? type,
}) {
  final keyKind = meta.objectKinds.where((kind) => kind.keyBrowserOnly).firstOrNull;
  if (keyKind != null) return () => openBrowseSource(context, connectionId, [key], keyKind.id);
  if (meta.queryDialect == 'redis') return () => openBrowseKeyValue(context, connectionId, container, key, type: type);
  return null;
}
