import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// What a tap on [object], of [kind] in [connectionId], opens, or null when it opens nothing.
///
/// The one rule of every object row, the object list's and search's: Details when the kind `hasColumns`, else Source
/// when it `hasSource`, else nothing. A group object such as an Oracle package is a leaf like any other, since Studio
/// lists no object's children.
/// Details and Source are screens of their own issues; each joins this rule, and the long-press menu, together with
/// its screen, so until then the rule opens nothing and no row carries a tap that leads nowhere.
VoidCallback? objectTapAction(
  BuildContext context, {
  required String connectionId,
  required ObjectKind kind,
  required DatabaseObject object,
}) => null;
