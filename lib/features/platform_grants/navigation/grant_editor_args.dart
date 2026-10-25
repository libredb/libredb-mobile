import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_target.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';

/// What the grants page hands the grant editor as route `extra`: the connection, the grant to change when the editor
/// opens on one, and the grants already held on the connection, by subject, from the grants list it shows.
///
/// [onGrantMayHaveChanged] is called once a `PUT` saved the grant or ended without a clear refusal, so the grants
/// page reads its list again whichever way the editor closes.
@immutable
final class GrantEditorArgs {
  const GrantEditorArgs({required this.target, required this.holders, required this.onGrantMayHaveChanged, this.grant});

  final GrantTarget target;

  /// The grant to change; null to pick a user first.
  final PlatformGrant? grant;

  /// The grants of the connection by their subject, the directory id of the user who holds each.
  final Map<String, PlatformGrant> holders;

  final VoidCallback onGrantMayHaveChanged;

  /// The location of the editor of the connection [connectionId].
  static String locationOf(String connectionId) =>
      ApplicationRoutesConstants.platformGrantEditor.replaceFirst(':id', Uri.encodeComponent(connectionId));

  /// Not a subject nor a name: this text can reach a log.
  @override
  String toString() => 'GrantEditorArgs(target: $target, editing: ${grant != null}, holders: ${holders.length})';
}
