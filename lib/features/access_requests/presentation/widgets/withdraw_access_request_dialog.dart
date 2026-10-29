import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/presentation/widgets/access_request_formatting.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';

/// Asks whether to withdraw [request], naming the level and the connection; true when the user confirmed.
Future<bool?> showWithdrawAccessRequestDialog(BuildContext context, {required MyAccessRequest request}) {
  final s = S.of(context);
  return showDialog<bool>(
    context: context,
    builder: (_) => ConfirmationDialog(
      title: s.access_requests_withdraw_title,
      message: s.access_requests_withdraw_message(requestLevelInSentence(s, request.level), request.connectionName),
      parentContext: context,
      confirmText: s.access_requests_withdraw,
      cancelText: s.cancel,
    ),
  );
}
