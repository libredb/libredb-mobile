import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
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
