import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';

/// Asks whether to remove [grant]'s access to [connection], naming the user, the level and the connection; true when
/// the admin confirmed.
Future<bool?> showRevokeGrantDialog(
  BuildContext context, {
  required PlatformConnection connection,
  required PlatformGrant grant,
}) {
  final s = S.of(context);
  final level = switch (grant.level) {
    'read' => s.platform_grants_level_read_in_sentence,
    'write' => s.platform_grants_level_write_in_sentence,
    _ => grant.level,
  };
  return showDialog<bool>(
    context: context,
    builder: (_) => ConfirmationDialog(
      title: s.platform_grants_remove_access,
      message: s.platform_grants_remove_message(grant.subjectUsername, level, connection.name),
      parentContext: context,
      confirmText: s.platform_grants_remove_confirm,
      cancelText: s.cancel,
    ),
  );
}
