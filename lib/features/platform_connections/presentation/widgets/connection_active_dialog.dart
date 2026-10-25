import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';

/// Asks whether to disable the active [connection], or to enable the inactive one, saying what that does for its
/// users; true when the admin confirmed.
Future<bool?> showConnectionActiveDialog(BuildContext context, {required PlatformConnection connection}) {
  final s = S.of(context);
  final disable = connection.isActive;
  return showDialog<bool>(
    context: context,
    builder: (_) => ConfirmationDialog(
      title: disable ? s.platform_connections_active_disable : s.platform_connections_active_enable,
      message: disable
          ? s.platform_connections_active_disable_message(connection.name)
          : s.platform_connections_active_enable_message(connection.name),
      parentContext: context,
      confirmText: disable
          ? s.platform_connections_active_disable_confirm
          : s.platform_connections_active_enable_confirm,
      cancelText: s.cancel,
    ),
  );
}

/// Says that the license has too few user seats for the grants of the connection the admin tried to enable.
///
/// The text names the connection's grants, unlike the grant-worded `platform.license_user_seats` message.
Future<void> showConnectionUserSeatsDialog(BuildContext context) {
  final s = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.platform_connections_active_user_seats_title),
      content: Text(s.platform_connections_active_user_seats),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}
